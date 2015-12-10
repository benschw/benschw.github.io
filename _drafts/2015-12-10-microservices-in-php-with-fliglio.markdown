---
layout: post
status: publish
published: true
title: Microservices in PHP with Fliglio
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---


In addition to being the domain I landed this blog on, Fliglio is the name of the PHP Framework
we've been using and build at work for the past several years. Recently we went through the
effort of cleaning it up and making an opensource version available [on github](https://github.com/fliglio).
Now, I will attempt to show you how to use with a _Getting Started_ guide for RESTful microservices.

<!--more-->


Before we go any further, grab a copy of the demo application [here](https://github.com/fliglio/rest-gs).

	git clone https://github.com/fliglio/rest-gs.git


This demo requires [memcache](http://us2.php.net/manual/en/memcache.installation.php) to serve
as a light weight database (don't count on your data from this app being durable!), so either 
make sure thats installed (along with [apache](https://httpd.apache.org/) or [nginx](https://www.nginx.com/) 
and the appropriate version of php).

If that sounds like a pain in the ass, the demo repo [comes with tools](https://github.com/fliglio/rest-gs/tree/master/docker) to get running fast with [Docker](https://www.docker.com/).


## Run The App

Let's just use Docker.

	cd rest-gs
	make docker-build
	make docker-start


Docker has a bunch of flags and things to remember, so I scripted it into a 
[Makefile](https://github.com/fliglio/rest-gs/blob/master/Makefile). Nothing too exciting is
happening though: after running `make docker-start` you'd have a container hosting the `rest-gs/web` on port 80
with nginx and php5-fpm (along with memcache).

So now you should be able to see it work:


	$ curl -s -X POST localhost/todo -d '{"description": "take out the trash", "status": "new"}' | jq .
	{
	  "id": "5669d68a8430b",
	  "status": "new",
	  "description": "take out the trash"
	}
	
	$ curl -s localhost/todo/5669d68a8430b | jq .
	{
	  "id": "5669d68a8430b",
	  "status": "new",
	  "description": "take out the trash"
	}


Cool! Let's look at the code now.


## Code Overview

- The project uses [Composer](https://getcomposer.org/) to manage its dependencies.
- The `/web` directory contains a lightweight `index.php` to bootstrap the application
- `/src` contains the meat of the application.


At a high level, the application comes together by having a main application class ([\Demo\DemoApplication](https://github.com/fliglio/rest-gs/blob/master/src/Demo/DemoApplication.php))
that is configured by one or more configuration classes ([\Demo\DemoConfiguration](https://github.com/fliglio/rest-gs/blob/master/src/Demo/DemoConfiguration.php)).


The application class is the application's entry point and is responsible for managing configuration classes as well as actually dispatching a request.

The configuration class is responsible for things like specifying how to preprocess and route a request, and instantiating application dependencies.

## Todo, A Microservice
I'm sure I could explain everything about the framework, but I'm also sure you wouldn't care.
So let's just jump in and look at the service we're building

### Defining a resource

This should be pretty familiar if you're used to REST apis. We're defining methods
on this class to handle providing basic CRUD functionality for todos with http verbs.

By hinting the parameters to these methods with classes like `PathParam`, `GetParam`, and `Entity`, we can specify
what parameters we need to perform an action.

	class TodoResource {
		private $db;
		public function __construct(TodoDbm $db) {
			$this->db = $db;
		}
		
		// GET /todo
		public function getAll(GetParam $status = null) {
			$todos = $this->db->findAll(is_null($status) ? null : $status->get());
			return Todo::marshalCollection($todos);
		}
		
		// GET /todo/:id
		public function get(PathParam $id) {
			$todo = $this->db->find($id->get());
			if (is_null($todo)) {
				throw new NotFoundException();
			}
			return $todo->marshal();
		}
		// POST /todo
		public function add(Entity $entity, ResponseWriter $resp) {
			$todo = $entity->bind(Todo::getClass());
			$this->db->save($todo);
			$resp->setStatus(Http::STATUS_CREATED);
			return $todo->marshal();
		}
		// PUT /todo/:id
		public function update(PathParam $id, Entity $entity) {
			$todo = $entity->bind(Todo::getClass());
			$todo->setId($id->get());
			$this->db->save($todo);
			return $todo->marshal();
		}
		// DELETE /todo/:id
		public function delete(PathParam $id) {
			$todo = $this->db->find($id->get());
			if (is_null($todo)) {
				throw new NotFoundException();
			}
			$this->db->delete($todo);
		}
	}

Those comments aren't magical however; we still need to map this functionality to urls. We manage this in the 
configuration class

	class DemoConfiguration extends DefaultConfiguration {
		public function getRoutes() {
			// Database Mapper
			$mem = new \Memcache();
			$mem->connect('localhost', 11211);
			$cache = new MemcacheCache();
			$cache->setMemcache($mem);
			$db = new TodoDbm($cache);

			// Resources
			$resource = new TodoResource($db);
			
			return [
				RouteBuilder::get()
					->uri('/todo')
					->resource($resource, 'getAll')
					->method(Http::METHOD_GET)
					->build(),
				RouteBuilder::get()
					->uri('/todo/:id')
					->resource($resource, 'get')
					->method(Http::METHOD_GET)
					->build(),
				RouteBuilder::get()
					->uri('/todo')
					->resource($resource, 'add')
					->method(Http::METHOD_POST)
					->build(),
				RouteBuilder::get()
					->uri('/todo/:id')
					->resource($resource, 'update')
					->method(Http::METHOD_PUT)
					->build(),
				RouteBuilder::get()
					->uri('/todo/:id')
					->resource($resource, 'delete')
					->method(Http::METHOD_DELETE)
					->build(),
						
			];
		}
	}	



### Next Steps

Not a terribly in depth introduction to [Fliglio](https://github.com/fliglio), but I've gotta start somewhere, right?


