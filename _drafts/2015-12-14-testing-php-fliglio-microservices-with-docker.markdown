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

## Try it out

_(If you're on OS X, make sure your have [docker-machine installed and running](https://docs.docker.com/mac/started/).
On linux, you just need [Docker installed](https://docs.docker.com/linux/started/).)_

	git clone https://github.com/fliglio/rest-gs.git
	cd rest-gs
	composer up
	make test


That was easy, right? What did we just do?

`make test` runs two sets of tests, "unit" and "component." The unit tests should
be familiar, they're just a suite of tests located in [`src/test/unit/`](https://github.com/fliglio/rest-gs/tree/master/src/test/unit)
that we point [phpunit](https://phpunit.de/) at.

The component tests are a little different however. 

## Component Tests


Testing a service's REST API is especially useful with microservices.
Low level tests are less useful than they are with a monolith for protecting against regression bugs
(because there isn't a sprawl of code depending on any of these libraries.)

Instead of other components in our system relying on library interfaces however, 
we have other services relying on our REST API. As long as we ensure our REST API doesn't
change unintentially, we are pretty close to regression proof! 

_(That's an oversimplification, but the point remains that the REST API is the
most important thing to test.)_


The heart of the `component-test` make task (which gets used when you run `make test`)
is a Docker container built from the [fliglio/local-dev](https://hub.docker.com/r/fliglio/test/) image
(The same container we used in [Microservices in PHP with Fliglio](/2015/12/2015-12-10-microservices-in-php-with-fliglio/)
to run our service for local exploratory testing.)


### Write some tests

Now that we can automate running an environment with Docker and our [Makefile](https://github.com/fliglio/rest-gs/blob/master/Makefile),
All we have to do is write some tests against it.

Luckily, we already wrote a [PHP client for our service](https://github.com/fliglio/rest-gs/blob/master/src/main/Demo/Client/TodoClient.php),
so we can use that in our tests to validate our service's API.

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

_(you'll of course also want to test error cases and all your methods...)_

### Mocking external resources
Up to here, we've really been talking about integration testing our application, but
sometimes you either don't have control of certain resource dependencies or you have a spidering web of transitive
service dependencies that aren't practical to run for local test.

To solve this, the copy of our service we are testing against uses
[src/test/httpdocs/index.php](https://github.com/fliglio/rest-gs/blob/master/src/test/httpdocs/index.php)
as an alternate entry point.

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

This entry point is the same as the normal `index.php` except we are configuring
the `DemoApplication` with `TestDemoConfiguration`. Since we wire up most of our
application in this class, we can mock individual components here to simplify
our environment and eliminate components that don't need to be tested by us.

{% highlight php %}
<?php
class TestDemoConfiguration extends DemoConfiguration {
	protected function getWeatherClient() {
		$fac = new WeatherClientStubFactory();
		return $fac->create();
	}
}

class WeatherClientStubFactory extends \PHPUnit_Framework_TestCase {
	public function create() {
		$stub = $this->getMockBuilder('\Demo\Weather\Client\WeatherClient')
			->disableOriginalConstructor()
			->getMock();

		$stub->method('getWeather')
			->will($this->returnCallback(function($city, $state) {
				if ($city == "Austin") {
					return new Weather(80, "Clear");
				} else {
					return new Weather(80, "Rainy");
				}
			}));
	
		return $stub;
	}
}

{% endhighlight %}

By mocking the `WeatherClient` class, we can both remove our dependence on an external resource
and ensure that the cities we use in our tests return consistent responses.

{% highlight php %}
<?php
class WeatherFilteringTest extends \PHPUnit_Framework_TestCase {
	private $client;

	public function setup() {
		$driver = new Client();
		$this->client = new TodoClient($driver, 
			sprintf("http://%s:%s", getenv('LOCALDEV_PORT_80_TCP_ADDR'), 80));
	}
	public function teardown() {
		$todos = $this->client->getAll();
		foreach ($todos as $todo) {
			$this->client->delete($todo->getId());
		}
	}

	public function testGetWeatherAppropriate() {
		// given
		$todo1 = $this->client->add(new Todo(null, "Watch TV", "new", false));
		$todo2 = $this->client->add(new Todo(null, "Walk in the park", "new", true));
		
		// when
		$outdoorTodos = $this->client->getWeatherAppropriate('Austin', 'Texas');
		$indoorTodos = $this->client->getWeatherAppropriate('Seattle', 'Washington');

		// then
		$this->assertEquals([$todo1], $indoorTodos, "it's rainy, so get indoor todos");
		$this->assertEquals([$todo2], $outdoorTodos, "it's clear, so get outdoor todos");
	}
}
{% endhighlight %}

This technique can also be used to mock clients to your own services. A typical application
built with microservices will be comprised of several services and you shouldn't have to
be running them all in order to test the REST API of the one you're working on.

### Wrapping Up

Hopefully I've given you a good idea of how to effectively test Fliglio microservices and
protect them against regression.

