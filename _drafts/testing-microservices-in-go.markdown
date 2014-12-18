---
layout: post
status: publish
published: true
title: Microservices in Go: Testing
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

This post is about testing microservices and why they should be tested differently than many types of software. Microservices are by their very nature simple and encapsulated behind their API. This means two things:

- As long as we don't break the http interface, there is no way to introduce regressions.
- Updates to the implementation of an endpoint usually going to be close to a rewrite

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

## And that's why your always write a client
Even if you don't plan on leveraging your service in another go app, it pays to write a client library. 

If you do plan on composing many go services together (having one service call another to model complex operations) then even better! In either case, I like to put the client library and the structs that serve as our API model into their own packages. That way your service can depend on the `api` package, but not know or care about the `client` package. Likewise, the client can depend only on the `api` and be imported by another app without exposing the implementation of the service.

Regardless, the reason we're even talking about clients is to support testing our service.


## 422: I'm a Teapot
only test status codes you're using, test all of them

## You Mocked me once, never do it again!
Martin Fowler's [The Difference Between Mocks and Stubs](http://martinfowler.com/articles/mocksArentStubs.html#TheDifferenceBetweenMocksAndStubs)

