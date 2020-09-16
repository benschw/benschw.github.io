---
layout: post
status: publish
published: true
title: From Monolith to Microservices
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

## Augmenting a Monolith

There are a number of ways to approach augmenting a monolithic
application with microservices. One is to build new functionality with
microservices and leave the monolith largely intact. Another is to carve
off functionality and replace it with microservice implementations. A
third is to undertake a complete rewrite. There are advantages and
disadvantages to each of these approaches.

With the exception of the rewrite, maintaining bounded contexts will
likely be the biggest challenge. When working with a monolithic
application, especially one that has spent a few years evolving, bounded
contexts are often not clear. Strategies like n-tier architecture often
lead to the details of a single business function spanning several
components. This can make interfacing new components that entirely
encapsulate a bounded context less intuitive. In most cases the overall
design will be best served if a single bounded context can be maintained
and encapsulated in the microservice, and the complexity of using the
microservice be spread out among all components in the monolith which
need it.

### Iterative Approaches for Adopting Microservices

Iteratively introducing microservices into your ecosystem is a great way
to get started. It is useful to get feedback from one or two
microservices before you start rolling out and maintaining dozens of
them. Starting slow gives you a chance to learn the new techniques
associated with building and running microservices without getting in
over your head. Also, running microservices necessitates a lot of
automation. Having actual microservices that you are committed to
supporting will help to introduce and refine your automation techniques
before you are supporting so many services that issues or deficiencies
are crippling.

One way to iteratively introduce microservices is to start implementing
new functionality with microservices to augment a monolithic
application. This approach is a great way to start getting a feel for
building and running microservices. You have the benefits of starting a
green field application since you are building something new, but it is
low risk because you aren’t committing to a whole new application or
throwing away the old solution.

Gradually replacing a monolithic application with microservices by
carving out functionality is another way. This method also has the
benefit of being low risk, but also gives you the opportunity to start
shrinking your monolith. The first step is to decide what to carve out.
One way to do this is to pull out all the code necessary to perform a
business function even if it means refactoring more than one component
of the monolith. This will help to ensure our new microservices align
well to the values of a microservice architecture. Another method is to
identify natural boundaries within the monolith and use them to separate
out functionality. This might produce a less ideal microservice design,
but will be much easier and can be a useful stepping stone to a more
idiomatic design.

One of the hardest things to carve out of a monolith is the database.
Even if there are tables that obviously belong to the microservice being
extracted, there will likely be relationships between those tables and
others. Finding and refactoring these relationships in the monolith to
free up the tables we want to extract can be daunting and may not be
worth it. The best solution might be to break the encapsulation of your
new microservice and allow it to leverage the monolith’s database
directly. In this scenario, if you start using the API of the
microservice instead of using the tables directly to access this data,
as more functionality is carved off of the monolith it may become
feasible to fully encapsulate the data.

### Taking On a Rewrite

Scrapping the monolith and starting from scratch might seem like an
attractive option, but usually it isn’t the best one. This method is
time consuming and risky, especially if your are just getting started
with microservices. Starting over unencumbered by technical debt or past
architectural decisions has its advantages, but it must be weighed
against the time and risk such a rewrite would involve. Undertaking a
rewrite takes time, often a lot of time, and when it is complete you
know you succeeded if the application behaves exactly the same as it did
before you started. Stagnation like this can easily spell the death of a
product. That said, while incremental approaches don’t impact the
business as much, they usually take longer to totally replace the old
system.

