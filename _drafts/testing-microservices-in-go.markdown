---
layout: post
status: publish
published: true
title: Why NOT to Test Your Microservices; In Go
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

Full disclosure: this isn't actually an argument against testing. The title was to draw in people uncomfortable with testing looking for justification to skip it and to capitalize on the morbid curiosity everyone else is probably feeling.

This is an explanation for why microservices should be tested differently: by relaxing efforts on unit testing and focusing on component testing.

<!--more-->

First off, I need to define component testing. There are [definitions](http://istqbexamcertification.com/what-is-component-testing/) out there but they aren't very consistent. For this article, a _component test_ is higher level then a unit test but lower level than an integration test. It should be easy (quick) to run, but high enough level that changing to the implementation under test shouldn't require updating your test.

Testing the API of a microservice is a perfect component test. Microservices are simple and almost by definition encapsulated behind their API. In this post, I'll walk through testing a weather microservice that keeps track of a list of locations and leverages a separate service to get weather details for those locations. Since consumers of this service will only care about the service API, we care much more that this API doesn't break or inadvertently change then that the underlying implementation details change (and if they break, the API will break too). If the implementation got much more complicated than a set of CRUD operations and a client to a third party, we would need to spend some time testing them, but when you can digest the entire implementation by scanning the code for a couple of minutes, you can pretty much skip it.

I'm not sure if any of that made sense, but maybe a walk-through will illustrate what I'm getting at. Below I will step through component testing my example weather microservice.

## Weather or not

## And that's why your always write a client

## 422: I'm a Teapot

## You Mocked me once, never do it again!