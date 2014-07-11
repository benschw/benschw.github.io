---
layout: post
title: REST Microservices in Go with Gin
---
[Microservices](http://martinfowler.com/articles/microservices.html) are cool. Simply described, they're a way to take encapsulation to the next level. This design pattern allows for components of your system to be developed in isolation (even in different languages), keep internal business logic truely internal (no more well intentioned hacks that break encapsulation), and allow for each component to be deployed in isolation. These three characteristics go a long way towards making development and deployment easier.

Here's a walk through of how I designed a simple _Todo_ migroservice in Go (with some help from [Gin](http://gin-gonic.github.io/gin/), [Gorm](https://github.com/jinzhu/gorm), and [codegangsta/cli](https://github.com/codegangsta/cli)).

<!--more-->

_n.b. I'll be walking through the process of building the microservice, but you can get the finished project [on github](https://github.com/benschw/go-todo)_

## Getting Started

First step is the wire up a foundation. For starters, we'll need:

- server cli: This is what we'll run to start up our server
- service controller: This is where we'll manage our service; wiring up routes and injecting dependencies etc.
- _todo_ api model: A data model shared by the server and the client (and the database) to communicate with
- _todo_ resource: A grouping of handlers to manage api requests made regarding todos 
- _todo_ http client: An http client library that can be imported by any applications wishing to use our microservice
- an integration test: By leveraging the client, we can very easily write symmetrical integration tests which fully exercises our service's REST api. 


### Server CLI
This is the entry point to our app. Right now it's pretty simple because configuration etc is hard coded in the _Service Controller_. Eventually it will be in charge or parsing a config and running different aspects of our application (e.g. performing database migrations)

	func main() {

		// not much here; it'll grow as we externalize config and add options
		svc := service.TodoService{}
		svc.Run()
	}

### Service Controller
This is the front controller for our service. We can construct our dependencies to inject into various resources, and wire up the routes to different resource functions.

	type TodoService struct {
	}

	func (s *TodoService) Run() {
		connectionString := cfg.DbUser + ":" + cfg.DbPassword + "@tcp(" + cfg.DbHost + ":3306)/" + cfg.DbName + "?charset=utf8&parseTime=True"

		// we'll pass in configuration later
		connectionString := "user:pass@tcp(localhost:3306)/Todo?charset=utf8&parseTime=True"


		db, _ := gorm.Open("mysql", connectionString)

		// initialize the resource and inject our db connection
		todoResource := &TodoResource{db: db}

		r := gin.Default()

		// to start out, we'll build the ability to add, get, and delete a todo
		r.POST("/todo", todoResource.CreateTodo)
		r.GET("/todo/:id", todoResource.GetTodo)
		r.DELETE("/todo/:id", todoResource.DeleteTodo)

		// we'll pass in configuration later
		r.Run(":8080")
	}

### Todo API Model
This structure can be leveraged by both the service to decode requests and integrate with the database, and by the client to build and process requests of the service. Later we will put it in its own package so a client implementation can import "api" and "client" and the server only needs "api" and "service"

	type Todo struct {
		Id          int32  `json:"id"`
		Created     int32  `json:"created"`
		Status      string `json:"status"`
		Title       string `json:"title"`
		Description string `json:"description"`
	}

### Todo Resource
This is a very rudimentary first pass at the resource. There is little error handling and there are obvious omissions (like the ability to update a _todo_)

	type TodoResource struct {
		db gorm.DB
	}

	func (tr *TodoResource) CreateTodo(c *gin.Context) {
		var todo api.Todo

		c.Bind(&todo)
		todo.Status = api.TodoStatus
		todo.Created = int32(time.Now().Unix())

		tr.db.Save(&todo)
		c.JSON(201, todo)
	}

	func (tr *TodoResource) GetTodo(c *gin.Context) {
		idStr := c.Params.ByName("id")
		idInt, _ := strconv.Atoi(idStr)
		id := int32(idInt)

		var todo api.Todo

		tr.db.First(&todo, id)

		if todo.Id == 0 {
			c.JSON(404, gin.H{"error": "not found"})
		} else {
			c.JSON(200, todo)
		}
	}

	func (tr *TodoResource) DeleteTodo(c *gin.Context) {
		idStr := c.Params.ByName("id")
		idInt, _ := strconv.Atoi(idStr)
		id := int32(idInt)

		var todo api.Todo

		tr.db.First(&todo, id)

		if todo.Id == 0 {
			c.JSON(404, gin.H{"error": "not found"})
		} else {
			tr.db.Delete(&todo)
			c.Data(204, "application/json", make([]byte, 0))
		}
	}

### Todo HTTP Client
This enables our other go apps to leverage our service without knowing the details of what the REST API looks like. A client application need only import the client and api, and they can treat the service like a local library.

Even if we don't have any go applications lined up to use our service, building the client implementation in conjunction with the service is very helpful for testing the API; more on that later.

	type TodoClient struct {
		Host string
	}

	func (tc *TodoClient) CreateTodo(title string, description string) (api.Todo, error) {
		var respTodo api.Todo
		todo := api.Todo{Title: title, Description: description}

		url := tc.Host + "/todo"
		r, err := makeRequest("POST", url, todo)
		if err != nil {
			return respTodo, err
		}
		err = processResponseEntity(r, &respTodo, 201)
		return respTodo, err
	}

	func (tc *TodoClient) GetTodo(id int32) (api.Todo, error) {
		var respTodo api.Todo

		url := tc.Host + "/todo/" + strconv.FormatInt(int64(id), 10)
		r, err := makeRequest("GET", url, nil)
		if err != nil {
			return respTodo, err
		}
		err = processResponseEntity(r, &respTodo, 200)
		return respTodo, err
	}

	func (tc *TodoClient) DeleteTodo(id int32) error {
		url := tc.Host + "/todo/" + strconv.FormatInt(int64(id), 10)
		r, err := makeRequest("DELETE", url, nil)
		if err != nil {
			return err
		}
		return processResponse(r, 204)
	}

_The referenced helper functions can be found [here](https://github.com/benschw/go-todo/blob/master/client/helper.go)_

### Tests
Of course we need more testing, but here's a start to illustrate how to use the client to test our service. n.b. We will need to have a copy of the server running for them to work.

	func TestCreateTodo(t *testing.T) {

		// given
		client := client.TodoClient{Host: "http://localhost:8080"}

		// when
		todo, err := client.CreateTodo("foo", "bar")

		//then
		if err != nil {
			t.Error(err)
		}

		if todo.Title != "foo" && todo.Description != "bar" {
			t.Error("returned todo not right")
		}

		// cleanup
		_ = client.DeleteTodo(todo.Id)
	}

	func TestGetTodo(t *testing.T) {

		// given
		client := client.TodoClient{Host: "http://localhost:8080"}
		todo, _ := client.CreateTodo("foo", "bar")
		id := todo.Id

		// when
		todo, err := client.GetTodo(id)

		// then
		if err != nil {
			t.Error(err)
		}

		if todo.Title != "foo" && todo.Description != "bar" {
			t.Error("returned todo not right")
		}

		// cleanup
		_ = client.DeleteTodo(todo.Id)
	}

	func TestDeleteTodo(t *testing.T) {

		// given
		client := client.TodoClient{Host: "http://localhost:8080"}
		todo, _ := client.CreateTodo("foo", "bar")
		id := todo.Id

		// when
		err := client.DeleteTodo(id)

		// then
		if err != nil {
			t.Error(err)
		}

		_, err = client.GetTodo(id)
		if err == nil {
			t.Error(err)
		}
	}


## Next Steps

Hopefully this shows how easy it is to get starting building your own microservice infrastructure in go. In addition to building out missing functionality, we also need to externalize our configuration and provide a way to manage the database. We also need to organize the components of our app (api, client, and service) into separate packages so that a client application need not import the service code but the api can be shared.

I've published a [complete example](https://github.com/benschw/go-todo) on github that takes care of these things:

### Usage

	$ ./cmd/server/server 
	NAME:
	   todo - work with the `todo` microservice

	USAGE:
	   todo [global options] command [command options] [arguments...]

	VERSION:
	   0.0.1

	COMMANDS:
	   server     Run the http server
	   migratedb  Perform database migrations
	   help, h    Shows a list of commands or help for one command
	   
	GLOBAL OPTIONS:
	   --config, -c 'config.yaml'   config file to use
	   --version, -v                print the version
	   --help, -h                   show help
	   
#### Bootstraping the database
Create an empty database, fill in the supplied config: `config.yaml` and then run the following to initialize the _todo_ table.

	./cmd/server/server --config config.yaml migratedb

Since this command is separate from running your service, you can use a different config (with different database credentials.)

#### Starting The Server
	
	./cmd/server/server --config config.yaml server

#### Trying it out

With the server running, you can also try out the example _todo_ cli app included with the project:

	$ todo add foo bar
	{Id:17 Created:1405039312 Status:todo Title:foo Description:bar}

	$ todo add hello world
	{Id:18 Created:1405039324 Status:todo Title:hello Description:world}

	$ todo ls
	{Id:18 Created:1405039324 Status:todo Title:hello Description:world}
	{Id:17 Created:1405039312 Status:todo Title:foo Description:bar}

	$ todo done 18
	{Id:18 Created:1405039324 Status:done Title:hello Description:world}

	$ todo ls
	{Id:18 Created:1405039324 Status:done Title:hello Description:world}
	{Id:17 Created:1405039312 Status:todo Title:foo Description:bar}

(not the prettiest output, is it...)

### Some Things To Look At...

#### Makefile
One update in [the github repo](https://github.com/benschw/go-todo), is the addition of a [Makefile](https://github.com/benschw/go-todo/blob/master/Makefile).  It takes care of running the server for the tests as well as building both the server binary and an example "todo" cli app that leverages the client (these can be found the the [cmd](https://github.com/benschw/go-todo/tree/master/cmd) directory).

#### CLI API
To support the cli interface with flags and subcommands, I included [codegangsta/cli](https://github.com/codegangsta/cli).  In addition, I've leveraged Canonical's [goyaml](https://gopkg.in/yaml.v1) to externalize the configuration into a yaml config.

These components aren't by any means necessary for a solid microservice platform, but are a nice start. ([Consul](http://www.consul.io/) integration might be a nice alternative ;))

#### GORM

[GORM](https://github.com/jinzhu/gorm) is by no means the ubiquitous choice for database abstraction, but for this simple example it suited my needs. One nice thing about microservices is that one size need not fit all, and we could use something completely different if we had a different problem to solve.