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


