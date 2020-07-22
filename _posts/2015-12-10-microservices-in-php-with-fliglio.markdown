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
we built and have been using at work for several years now. Recently we went through the
effort of cleaning it up to make available [on github](https://github.com/fliglio).

In this post I will attempt to show you how to use Fliglio with a _Getting Started_ guide for RESTful microservices.

<!--more-->

## Running The App
Before we go any further, grab a copy of the demo application [here](https://github.com/fliglio/rest-gs).

	git clone https://github.com/fliglio/rest-gs.git


This demo requires [MySQL](https://www.mysql.com/) to back the todo entries (along with 
[apache](https://httpd.apache.org/) or [nginx](https://www.nginx.com/) and the appropriate version of php).

If that sounds like a pain in the ass, you can also use [Docker](https://www.docker.com/). The demo repo comes with a 
[Makefile](https://github.com/fliglio/rest-gs/blob/master/Makefile) to easily run Fliglio services in a Docker container.


...Let's just use Docker.

_(If you're on OS X, make sure your have [docker-machine installed and running](https://docs.docker.com/mac/started/).
On linux, you just need [Docker installed](https://docs.docker.com/linux/started/).)_

	composer up
	make run

This will pull down the [Docker](https://www.docker.com/) image [fliglio/local-dev](https://hub.docker.com/r/fliglio/local-dev/) 
and run the app in a container. It's spitting out logs to stdout and will keep running until you hit `CTRL+c`.

With that going, open a new terminal and run:

	make migrate

This will apply the [phinx](https://phinx.org/) database migrations for the app (see [db/migrations](https://github.com/fliglio/rest-gs/tree/master/db/migrations)).


#### Now you can explore the service:
Add a todo

	$ curl -s -X POST localhost/todo -d '{"description": "take out the trash", "status": "new"}' | jq .

{% highlight json %}
{
  "id": "1",
  "status": "new",
  "description": "take out the trash"
}
{% endhighlight%}
query for that todo we just created

	$ curl -s localhost/todo/1 | jq .
{% highlight json %}
{
  "id": "1",
  "status": "new",
  "description": "take out the trash"
}
{% endhighlight%}


Cool! Let's look at the code now.


## Code Overview

- The project uses [Composer](https://getcomposer.org/) to manage its dependencies.
- The `/httpdocs` directory contains a lightweight `index.php` to bootstrap the application
- `/src` contains the meat of the application.


At a high level, the application comes together by having a main application class ([\Demo\DemoApplication](https://github.com/fliglio/rest-gs/blob/master/src/Demo/DemoApplication.php))
that is configured by one or more configuration classes ([\Demo\DemoConfiguration](https://github.com/fliglio/rest-gs/blob/master/src/Demo/DemoConfiguration.php))
which manages your resources ([\Demo\Resources\TodoResource](https://github.com/fliglio/rest-gs/blob/master/src/main/Demo/Resource/TodoResource.php).)

- The application class is the application's entry point and is responsible for managing configuration classes as well as actually dispatching a request.
- The configuration class is responsible for things like specifying how to route a request and for instantiating application dependencies.
- Typically, a microservice will also have one or more resources classes to organize behavior for individual urls.

## Todo, A Microservice
I'm sure I could explain everything about the framework, but I'm also sure you wouldn't care.
So let's just jump in and look at the service.

### Defining a resource

This should be pretty familiar if you're used to REST apis. We're defining methods
on this class to handle providing basic CRUD functionality for todos with http verbs.

By hinting the parameters to these methods with classes like `PathParam`, `GetParam`, and `Entity`, we can specify
what parameters we need to perform an action (and allow the framework to inject them rather than parsing
the Request directly.)

{% highlight php %}
<?php
class TodoResource {
	private $db;
	private $weather;
	public function __construct(TodoDbm $db, WeatherClient $weather) {
		$this->db = $db;
		$this->weather = $weather;
	}
	
	// GET /todo
	public function getAll(GetParam $status = null) {
		$todos = $this->db->findAll(is_null($status) ? null : $status->get());
		return Todo::marshalCollection($todos);
	}
	// GET /todo/weather
	public function getWeatherAppropriate(GetParam $city, GetParam $state, GetParam $status = null) {
		$status = is_null($status) ? null : $status->get();
		$weather = $this->weather->getWeather($city->get(), $state->get());
		error_log(print_r($weather->marshal(), true));
		$outdoorWeather = $weather->getDescription() == "Clear";
		$todos = $this->db->findAll($status, $outdoorWeather);
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

{% endhighlight %}

_(Don't worry too much about the method `getWeatherAppropriate`, this is a contrived
example to aid in showing [how to test](/2015/12/2015-12-14-testing-php-fliglio-microservices-with-docker/) all of this.)_

Those comments aren't magical however; we still need to map this functionality to urls. We manage this in the 
configuration class

{% highlight PHP %}
<?php
class DemoConfiguration extends DefaultConfiguration {

	// Database Mapper
	protected function getDbm() {
		$dsn = "mysql:host=localhost;dbname=todo";
		$db = new \PDO($dsn, 'admin', 'changeme', [\PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8']);
		$db->setAttribute(\PDO::ATTR_ERRMODE, \PDO::ERRMODE_EXCEPTION);
		return new TodoDbm($db);
	}

	// Todo Resource
	protected function getTodoResource() {
		return new TodoResource($this->getDbm());
	}

	public function getRoutes() {
		$resource = $this->getTodoResource();
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
{% endhighlight %}

And there you have it! A framework for developing REST services.

### Next Steps

That wasn't a terribly in depth introduction to [Fliglio](https://github.com/fliglio), but I've gotta start somewhere, right?

Before you go off and build your own app though, take a look at [Testing PHP Fliglio Microervices with Docker](/2015/12/2015-12-14-testing-php-fliglio-microservices-with-docker/).
