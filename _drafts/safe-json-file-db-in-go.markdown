---
layout: post
status: publish
published: true
title: Using a JSON File as a Database Safely in Go
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

There are definitely problems a json file as a database, but sometimes the simplicity
of no extra dependencies makes it an attractive option. The two biggest problems are performance 
and managing concurrent reads and writes.

We can't do much about performance, but with go, managing concurrent reads and writes is a breeze! 

Below is a walk through of a method for managing file access so that a json file can safely be used as a database.

<!--more-->

The general pattern is: set up a channel and push read/write jobs onto it. Meanwhile, run a goroutine which will
process those jobs ensuring exclusive access to the json file. (Remember, Go's philosophy towards concurrency is: 
[Don't communicate by sharing memory; share memory by communicatingg](http://golang.org/doc/codewalk/sharemem/). This is why we're going to pipe requests to the component responsible for accessing the json db file rather then screwing around with lock files or synchronization.)

Follow along below where I put it all together, or jump [here](https://github.com/benschw/jsondb-go) 
for the finished product: a full REST service for managing your todos, backed by a json file database.

### db.json
Here's what my database looks like. It's just a map of id => Todos. (I'm using a `uuid` for the Id.)

	{
	    "1a6e9148-ebe5-4bf0-9675-b76f9fab7b72": {
	        "id": "1a6e9148-ebe5-4bf0-9675-b76f9fab7b72",
	        "value": "Hello World"
	    },
	    "3e39df85-9851-4ce9-af0c-0dd831e3b970": {
	        "id": "3e39df85-9851-4ce9-af0c-0dd831e3b970",
	        "value": "Hello World2"
	    }
	}
### Todo
And here's the api model we'll be marshalling / unmarshalling it with:

	type Todo struct {
		Id    string `json:"id"`
		Value string `json:"value" binding:"required"`
	}

### main.go
In the entry point, we set up our job channel, start our job processor so we're ready when the jobs
start rolling in and then initialize a `TodoClient` which insulates us from the details of the job channel.


	db := "./db.json"
	
	// create channel to communicate over
	jobs := make(chan Job)

	// start watching jobs channel for work
	go ProcessJobs(jobs, db)

	// create client for submitting jobs / providing interface to db
	client := &TodoClient{Jobs: jobs}


### Job Processor
Here's the the hub of our database. `ProcessJobs` is run as a goroutine so it just hangs out running in an infinite for loop waiting for work in the form of a `Job`.  A job's `Run` method is where the work happens: it takes in the database data (all of it! remember, this is never going to be performant, so lets just make things easy on our selves and only operate on our database in its entirety) and returns the updated database data. The Job Processor then writes the modified database model back to disc before moving on to the next job.

	type Job interface {
		ExitChan() chan error
		Run(todos map[string]Todo) (map[string]Todo, error)
	}

	func ProcessJobs(jobs chan Job, db string) {
		for {
			j := <-jobs

			todos := make(map[string]Todo, 0)
			content, err := ioutil.ReadFile(db)
			if err == nil {
				if err = json.Unmarshal(content, &todos); err == nil {
					todosMod, err := j.Run(todos)

					if err == nil && todosMod != nil {
						b, err := json.Marshal(todosMod)
						if err == nil {
							err = ioutil.WriteFile(db, b, 0644)
						}
					}
				}
			}

			j.ExitChan() <- err
		}
	}

### Read Todo Job
Here's one of our jobs for interacting with the database. This job simply implements the interface and adds in a "todos" channel so we can also return data. Since the job processor is in charge of accessing the db file, all the `Run` function does is pass the todos map to the `todo` response channel.

	// Job to read all todos from the database
	type ReadTodosJob struct {
		todos    chan map[string]Todo
		exitChan chan error
	}

	func NewReadTodosJob() *ReadTodosJob {
		return &ReadTodosJob{
			todos:    make(chan map[string]Todo, 1),
			exitChan: make(chan error, 1),
		}
	}
	func (j ReadTodosJob) ExitChan() chan error {
		return j.exitChan
	}
	func (j ReadTodosJob) Run(todos map[string]Todo) (map[string]Todo, error) {
		j.todos <- todos

		return nil, nil
	}

### Todo Client
This is the piece the rest of your application will interact with. It encapsulates the mess associated with pushing jobs and waiting for a response and signal to come through on the error channel.

	// client for submitting jobs and providing a repository-like interface
	type TodoClient struct {
		Jobs chan Job
	}

	func (c *TodoClient) GetTodos() ([]Todo, error) {
		arr := make([]Todo, 0)

		todos, err := c.getTodoHash()
		if err != nil {
			return arr, err
		}

		for _, value := range todos {
			arr = append(arr, value)
		}
		return arr, nil
	}

## Exposing it to the web
At this point, you might be thinking: "The only reason we have to worry about concurrent writes is because you put the dat read/write operations in a goroutine. A single routine would provide safe reads and writes too."

But as soon as we turn this into a web service, all bets are off. Below I layer in a http server (using the [Gin](http://gin-gonic.github.io/gin/) framework) to utilize our `TodoClient` and illustrate the example.

### main.go
Same as before, but now there's a `/todo` endpoint for getting all todos

_The [full example](https://github.com/benschw/jsondb-go) is more built out with a POST, GET by id, PUT, and DELETE_

	db := "./db.json"

	// create channel to communicate over
	jobs := make(chan Job)

	// start watching jobs channel for work
	go ProcessJobs(jobs, db)

	// create dependencies
	client := &TodoClient{Jobs: jobs}
	handlers := &TodoHandlers{Client: client}

	// configure routes
	r := gin.Default()

	r.GET("/todo", handlers.GetTodos)

	// start web server
	r.Run(":8080")

### Handlers
And last but not least, we leverage the `TodoClient` to get some data... safely!

	type TodoHandlers struct {
		Client *TodoClient
	}

	// Get all todos as an array
	func (h *TodoHandlers) GetTodos(c *gin.Context) {
		todos, err := h.Client.GetTodos()
		if err != nil {
			log.Print(err)
			c.JSON(500, "problem decoding body")
			return
		}

		c.JSON(200, todos)
	}


Thanks for following along!