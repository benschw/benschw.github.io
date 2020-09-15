---
layout: post
status: publish
published: true
title: NSQ and Golang Messaging Primer
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
date: 2020-09-15 08:32:26.000000000 -05:00
categories:
- Post
tags: []
---

In this post, we'll look at how you can use [NSQ](https://nsq.io/) in your [golang](https://golang.org/)
applications to start leveraging messaging. Messaging offers the easiest way to build an async architecture,
for which there are a number of benefits ranging from scalability to the reduction of cascading errors.
In this post however, we will be focusing on how messaging can be used to decouple components in your software
by looking at a couple of common patterns for doing so (work queues & pub/sub).

<!--more-->


[NSQ](https://nsq.io/) is a realtime, distributed, horizontally scalable messaging platform.
Also, its written in Go and is distributed as two simple binaries (plus an optional admin web app
and a collection of utility tools) so it is easy to install and keep up to date (no dependencies.)
There are a slew of both official & community supported [client libraries](https://nsq.io/clients/client_libraries.html),
and we will be using the officially supported [go](https://github.com/nsqio/go-nsq) one.


This post is divided up into four sections:

* First we'll get NSQ running in a local cluster using [Docker Compose](https://docs.docker.com/compose/).
* Next we'll build a couple of simple Go apps to publish to and consume from NSQ
* Third we will look at how to scale the consumption of our messages using the Worker pattern
* Finally we will update our example to implement the Pub/Sub pattern

_Follow along here, or clone the [demo repo](https://github.com/benschw/nsq-demo) if you prefer_

## Running NSQ

## Sending & Receiving Messages

## Worker Pattern

## Pub/Sub Pattern
