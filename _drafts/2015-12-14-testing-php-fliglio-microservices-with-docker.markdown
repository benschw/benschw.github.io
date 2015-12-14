---
layout: post
status: publish
published: true
title: Testing PHP Fliglio Microservices with Docker
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

In my last post, [Microservices in PHP with Fliglio](/2015/12/2015-12-10-microservices-in-php-with-fliglio/),
I walked you through writing a _Todo_ service in [Fliglio](https://github.com/fliglio). Now, I'll show you how to test it.

<!--more-->

If you want to follow along at home, grab a copy of the demo application [here](https://github.com/fliglio/rest-gs).

Last time, we used `make run` to stand the app up in a docker container we could 
use for exploratory testing. This time we'll go one step further and use [Docker](https://docs.docker.com/)
to facilitate automated testing.

### Try it out

_(If you're on OS X, make sure your have [docker-machine installed and running](https://docs.docker.com/mac/started/).
On linux, you just need [Docker installed](https://docs.docker.com/linux/started/).)_

	make test


That was easy, right? What did we just do?

`make test` runs two sets of test, "unit" and "component." The unit tests should
be familiar, they're just a suite of tests located in [`src/test/unit/`](https://github.com/fliglio/rest-gs/tree/master/src/test/unit)
that we point [phpunit](https://phpunit.de/) at.

The component tests are a little different however. They are integration tests
with all dependencies we can't run in a docker container mocked out. In this simple example,
we actually don't have to mock anything.

### Component Tests


Testing the service's REST API is especially useful with microservices.
Lower level tests to prevent regressions are less useful than they are with a monolith
(because there isn't a sprawl of code depending on any of these libraries.)

Instead of other components in our system relying on library interfaces however, 
we have other services relying on our REST API. As long as we ensure our REST API doesn't
change unintentially, we are pretty close to regression proof! 

_(That's an oversimplification, but the point remains that the REST API is the
most important thing to test.)_


The heart of the `component-test` make task (which gets used when you run `make test`)
is a Docker container build from the [fliglio/test](https://hub.docker.com/r/fliglio/test/) image.
This container is the same as the [local dev](https://hub.docker.com/r/fliglio/local-dev/)
container we used in [Microservices in PHP with Fliglio](/2015/12/2015-12-10-microservices-in-php-with-fliglio/),
except it uses [src/test/httpdocs/index.php](https://github.com/fliglio/rest-gs/blob/master/src/test/httpdocs/index.php)
as the application entry point.

{% highlight php %}
<?php
try {
	$svc = new DemoApplication(new TestDemoConfiguration());
	$svc->run();
} catch (\Exception $e) {
	error_log($e);
	http_response_code(500);
}

{% endhighlight %}

This entry point is the same as your normal `index.php` except we are configuring
the Demo Application with `TestDemoConfiguration`. Since we wire up most of our
application in this class, this allows us to mock individual components for our tests.


#### Write some tests

Now that we can automate running an environment to test with Docker and our [Makefile](https://github.com/fliglio/rest-gs/blob/master/Makefile),
All we have to do is write some tests.

Luckily, we already wrote a [PHP client for our service](https://github.com/fliglio/rest-gs/blob/master/src/main/Demo/Client/TodoClient.php),
so we can just use that in our tests to validate that our service's API behaves like it should:

{% highlight php %}
<?php
class CrudTest extends \PHPUnit_Framework_TestCase {
	private $client;
	public function setup() {
		$driver = new Client([
			'base_uri' => 'http://localhost:'.getenv('SVC_PORT'),
		]);
		$this->client = new TodoClient($driver);
	}
	public function teardown() {
		$todos = $this->client->getAll();
		foreach ($todos as $todo) {
			$this->client->delete($todo->getId());
		}
	}
	public function testAdd() {
		// given
		$todo = new Todo(null, "hello", "new");
		
		// when
		$out = $this->client->add($todo);
		// then
		$todo->setId($out->getId());
		$this->assertEquals($out, $todo, "created todo should return value");
		
		$out2 = $this->client->get($out->getId());
		$this->assertEquals($out, $out2, "created todo should return value");
	}
	public function testGet() {
		// given
		$todo = $this->client->add(new Todo(null, "Hello World", "new"));
		
		// when
		$found = $this->client->get($todo->getId());
		// then
		$this->assertEquals($found, $todo, "GET should return todo by id");
	}

	// ...
}
{% endhighlight %}



### Wrapping Up

Hopefully I've given you a good idea of how to effectively test your Fliglio microservices and
protect it against regression.

