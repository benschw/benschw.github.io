---
layout: post
status: publish
published: true
title: Microservices in Go - Testing
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

This post is about testing microservices and why they should be tested differently than many types of software. Microservices are by their very nature simple and encapsulated behind their API. This means two things:


- As long as we don't break the http interface, there is no way to introduce regressions.
- Updates to the implementation of an endpoint are usually going to be close to a rewrite

Unit testing your service's implementation details isn't very important; you can achieve more effective coverage by focusing on component testing the http API.

Below I will step through testing a [example weather microservice](https://github.com/benschw/weather-go).

<!--more-->

First off, I need to define component testing. There are [definitions](http://istqbexamcertification.com/what-is-component-testing/) out there but they aren't very consistent. For this article, a component test is higher level then a unit test but lower level than an integration test. It should be easy (quick) to run, but high enough level that changes in the implementation under test shouldn't require updating your test (as long as the changes don't break your microservice's api: the http api).

In this post, I'll walk through testing a [weather microservice](https://github.com/benschw/weather-go) that keeps track of a list of locations and leverages a separate service to get weather details for those locations. Since consumers of this service will only care about the service's http API, we need to make sure that it doesn't break or inadvertently change. Since the amount of code needed to satisfy the service's http api isn't complicated and is very small, we're going to skip unit testing it. Testing to prevent regressions here just isn't worth it.

I'm not sure if any of that made sense and I know it's a hard sell, but maybe a walk-through will illustrate what I'm getting at.

## Weather or not
[Weather-go](https://github.com/benschw/weather-go) is a Json REST API written in _go_ for the express purpose of illustrating patterns for testing microservices in go. It exposes a single `location` resource with CRUD operations:

- `POST /location`
- `GET /location/{id}`
- `GET /location`
- `PUT /location/{id}`
- `DELETE /location/{id}`

In addition, it contains a client library for [openweathermap.org](http://openweathermap.org/) which is used to include weather details in our `location resource` (temperature and description.)

### Get it running
Weather-go uses mysql to store the locations you add, so before you can run the server or the tests, make sure you have a pair of databases (local dev & test) set up. Update the yaml configs appropriately.
	

	# create the database configured in `config.yaml`
	$ mysql -u root -p -e "CREATE DATABASE Location;"

	# create the database configured in `test.yaml`
	$ mysql -u root -p -e "CREATE DATABASE LocationTest;"

	$ go get github.com/benschw/weather-go
	$ cd $GOPATH/src/github.com/benschw/weather-go
	$ go build
	$ go test ./...

	# add the `location` table
	$ ./weather-go -config ./config.yaml migrate-db

	# start the http server
	$ ./weather-go -config ./config.yaml serve


Now that we have that out of the way, time to talk about testing!

## And that's why you always write a client
Even if you don't plan on leveraging your service in another go app, it pays to write a client library. 

If you do plan on composing many go services together (having one service call another to model complex operations) then even better! In either case, I like to put the client library and the structs that serve as our API model into their own packages. That way your service can depend on the `api` package, but not know or care about the `client` package. Likewise, the client can depend only on the `api` and be imported by another app without exposing the implementation of the service.

Regardless, the reason we're even talking about clients is to support testing our service. Since we've decided to focus on testing our http API, what better way than to actually make http requests and write assertions about the responses.

For `weather-go`, I start up an http server on a random port and use the client I've written to perform tests:

### Suite Setup
I'm using [gocheck](gopkg.in/check.v1) which allows for things like `setup` and `teardown` functions in addition to higher level `Assert` calls.

	type TestSuite struct {
		s    *LocationService
	}

	var _ = Suite(&TestSuite{})

	func (s *TestSuite) SetUpSuite(c *C) {
		...
		s.s = &LocationService{...}

		go s.s.Run()
	}

	func (s *TestSuite) SetUpTest(c *C) {
		s.s.MigrateDb()
	}

	func (s *TestSuite) TearDownTest(c *C) {
		s.s.Db.DropTable(api.Location{})
	}

I've stripped out the noise, but you can see the gist of it above (or the whole thing [here](https://github.com/benschw/weather-go/blob/master/location/location_service_test.go).)

- `SetUpSuite` starts the server in a separate goroutine for us to beat up against.
- `SetUpTest` adds the location table to our test database.
- `TearDownTest` drops all the data we left in the test database so we can start over with a clean slate.

### Testing with our client library
With a running server, we can now make some real http requests and start testing that they behave the way we expect. For example, testing the `POST`

Here is a test for the happy path, we try to add a location, and it gets added

	// Location should be added
	func (s *TestSuite) TestAdd(c *C) {
		// given
		locClient := client.LocationClient{Host: s.host}

		// when
		created, err := locClient.AddLocation("Austin", "Texas")

		// then
		c.Assert(err, Equals, nil)
		found, _ := locClient.FindLocation(created.Id)

		c.Assert(created, DeepEquals, found)
	}

Here we test that we get a `400` (bad request) if the location we are trying to add doesn't validate

	// Client should return ErrStatusBadRequest when entity doesn't validate
	func (s *TestSuite) TestAddBadRequest(c *C) {
		// given
		locClient := client.LocationClient{Host: s.host}

		// when
		_, err := locClient.AddLocation("", "Texas")

		// then
		c.Assert(err, Equals, rest.ErrStatusBadRequest)
	}

And finally we test that we get a `409` (conflict) if we try to `POST` an entity with an Id that already exists. Note that our client doesn't support doing this, so we had to make the request at a lower level.

	// Client should return ErrStatusConflict when id exists
	// (not supported by client so pulled impl into test)
	func (s *TestSuite) TestAddConflict(c *C) {
		// given
		locClient := client.LocationClient{Host: s.host}
		created, _ := locClient.AddLocation("Austin", "Texas")

		// when
		url := fmt.Sprintf("%s/location", s.host)
		r, _ := rest.MakeRequest("POST", url, created)
		err := rest.ProcessResponseEntity(r, nil, http.StatusCreated)

		// then
		c.Assert(err, Equals, rest.ErrStatusConflict)
	}

So there it is: component testing our application's http interface. If the underlying implementation changes, these tests will tell us if they've changed in a way that will impact code using our service, but we won't get bogged down in updating lower level tests that at best don't provide additional value, or at worst are brittle and cause false negatives.

(Also, take a look at the [openweather package](https://github.com/benschw/weather-go/tree/master/openweather) which I organized and tested in the same way as the location package; with a `client` and `api` sub package. The only difference is there is no service implementation, but this way it's exposed to my app in a format I'm used to working with.)

## 418: I'm a Teapot
My next point to make regarding component tests for microservices, is you should only test things that you have use cases for. You don't need to validate every possible http error, only the ones you're using. Which probably means you don't need to test for "418: I'm a Teapot" or any number of other esoteric status codes.

I've found that there are seven status codes that I regularly use, and barely if ever use the others. 

- http.StatusOK
- http.StatusCreated
- http.StatusConflict
- http.StatusBadRequest
- http.StatusInternalServerError
- http.StatusNotFound
- http.StatusNoContent

You don't need to constrain your service to using as few codes as possible, but make sure you're aware of which are being used and test them all. This list is your cheat sheet for what to test. Adding additional, more granular codes might make for a richer interface, but it also makes for a more brittle one.

## You Mocked me once, never do it again!
Martin Fowler's [The Difference Between Mocks and Stubs](http://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs)

