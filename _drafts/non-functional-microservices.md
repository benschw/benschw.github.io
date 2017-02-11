---
layout: post
status: publish
published: true
title: Non-Functional Microservices
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

Most people that know the term "non-functional requirements" take exception
to its use... but at least they know what I'm talking about.

## Infrastructure and Automation

Consistent infrastructure and a high degree of automation are
prerequisites for a successful microservice architecture. By dividing an
application into microservices, aspects of the application become
delegated to the infrastructure. Instead of running a component "in process"
to guarantee that it is always available,
we must rely on the underlying operating system and networking (not to mention
unique lifecycles and release cycles of each component) to manage availability.
With microservices it is more important than ever that
everything runs predictably and resiliently.


### Treating Infrastructure as Code

With microservices, infrastructure is a part of the application, so we
should treat it like such. To start, the server a microservice is
running on is a part of its bounded context so we should reinforce its
boundaries by only installing one microservice to a server. Next, we
need to stop logging in to production servers. We also need a way to
keep our systems consistent and in a known state with tools like
configuration management or patterns like immutable servers. By treating
infrastructure as code, we can manage a microservice architecture at
scale, evolve our our servers by updating packages or whole
implementations, and by scaling out individual microservices by adding
new instances.

In order to maintain the encapsulation of microservices and facilitate
managing them, each instance of a microservice should be installed on
its own logical node. Each node can be a virtual machine, a container,
or even a physical piece of hardware (though using physical hardware is
going to be impractical for most use cases). Infrastructure is a part of
the application and each microservice’s server is a part of its bounded
context. Different microservices may have different requirements and
having their own node means that there is no danger of conflicting
dependencies and that the infrastructure is free to evolve with the
service’s needs.

A big part of treating infrastructure as code is automation. With a
large distributed application, automation is necessary for managing
infrastructure. Only by automating the provisioning of boxes, deployment
of the microservices, and monitoring of our systems and applications can
we be sure our application will behave the way we expect. Automation can
help guarantee that each node is in an expected state and that we can
recreate a node if we need to. It also allows us to provision
environments to test our application in so nothing is a surprise when
code is deployed to production. Ultimately, by automating our
infrastructure we can concentrate on developing our applications and
feel confident that our infrastructure will run them and be able to
evolve with them.

Since microservices demand so many nodes, managing production servers by
hand is not scalable. Configuration management tools such as Puppet or
Chef are designed to deterministically apply a set of configuration
scripts to a server. These scripts will specify what software to install
and how to configure the box, and they can be applied to many boxes
guaranteeing identical copies. Configuration can also be checked into
source control and governed the same as any other code. It can be
applied and tested in pre-production environments before being rolled
out to production.

Another way to ensure that all nodes are in a known and consistent state
is treat them as read only, or immutable. The general strategy is to
build a reference system, test it, and the copy it to production where
it can be run as a virtual machine or a container. If a change is
needed, instead of editing the running system, create a new server, test
that, and then replace the old version with it. Tools like Packer
provide mechanisms to apply your customizations to base images and
produce a new image that can be shipped to your production environment.
Immutable servers guarantee total consistency, but they require an even
higher level of automation to frequently spin up nodes, tear down nodes,
and rewire load balancers.

Container systems like Docker are one way to manage immutable
infrastructure. In some ways, Docker is like a lightweight virtual
machine, but in fact it is just a way to provide isolation for an
application by leveraging features of the Linux kernel. Docker
containers provide an isolated environment for each microservice without
the overhead of a full operating system in a virtual machine. Instead of
running a full copy of an operating system for each microservice, Docker
containers run on top of a host os and use the kernel from the host to
provide resources for a single process. Docker also provides a way to
manage a filesystem for each container so dependencies and configuration
can be be provided to the process running inside it.

Containers are extremely lightweight and allow resources to be shared
among all containers on a given host system. These qualities make them a
perfect fit for microservices. Virtual machines require reserving
resources for each node making them very inefficient for running many
small applications. Microservices like having their own node for the
isolation, not because they need dedicated resources.

### Health and Monitoring

In large distributed systems failures and anomalous behaviors are going
to happen and we need to make sure that we can catch and address them
quickly and consistently. It is difficult to ensure that all of an
application’s microservices are operating as expected if the task of
doing so isn’t automated. In addition to many different services, your
environment might be running multiple copies in a highly available
manner that could prevent isolated failures from even being noticed by
the users of an application.

To ensure a healthy system, it is beneficial to include mechanisms for
keeping track of how an application is operating. By having each
microservice expose information such as whether or not it is functioning
as expected, metrics for how it is performing, and even something as
simple as what version of the service is running, we can automate
keeping track of how the application as a whole is behaving and make
sure that individual services don’t fall through the cracks.


### Continuous Integration and Delivery

When software is so large that more than one team of developers are
maintaining it, it can be a herculean effort to create and test a stable
build that can be deployed to production. Microservices are small enough
that this process can be kept much lighter and since the services are
each individually deployable, deployments don’t have to be held up
waiting for the work in progress of other teams. The use of continuous
integration and continuous delivery helps to take advantage of this by
providing trust for a microservice’s builds so that it can be deployed
often.

Continuous integration (CI) is the practice of building automated
testing for your application and running it often. Continuous delivery
(CD) is the practice of writing software in small increments that can be
deployed often and provide a quick feedback loop. One of the most
powerful effects of a microservice architecture is that individual
microservices can be deployed whenever it makes sense, however how often
it makes sense largely depends on how confident we are in our software
and how easy it is to deploy it.

CI tools like Jenkins and TeamCity will automate testing, building, and
even deploying an application. Automating these steps makes it easier to
focus on building software, but only if the tests being run instil
confidence. Writing good tests is difficult, but it becomes a little
easier with microservices because a microservice’s coarsely grained API
is very intuitive to test. If a microservice’s API is tested, it is
harder to accidentally introduce regression bugs or break contracts with
other microservices.

However you achieve it, good automated tests are invaluable for
maintaining microservices. Without the confidence they instill, many of
the benefits of microservices are lost. It is easy to safely refactor or
even rewrite a microservice because of the bounded context and coarsely
grained API that wraps it, but we need to feel confident that the API
didn’t change. Microservices can be released to production as soon as
new features are completed because each microservice can be deployed on
its own schedule, but we need to feel confident that the new feature
won’t introduce any bugs.

Continuous delivery is another part of providing fast feedback and
building confidence for software development. By building functionality
in small increments a microservice can be kept stable and deployable.
Being always deployable allows for microservices to be integrated and
tested in the context of the whole application throughout the
development process, not just at the end of it. This provides quick
feedback and ensures problems are found and solved early when they are
still small. CD is about not just preventing bugs, but about fixing them
quickly.

Having software that is always deployable means not undertaking large
chunks of work which mean the microservice won’t build or work properly
for an extended period of time. Instead, break large endeavors into
incremental pieces that can be integrated as they are completed.
Integrating along the way rather than saving it up for the end smoothes
out the development process by surfacing bugs and other problems quickly
while they are still small and manageable. In addition, business
functionality and requirements can be verified by interested parties as
they become available and any course corrections can be made while they
are still small. Not only does keeping an application deployable
minimize the size of potential problems, it also ensures that when they
are found you don’t have to hunt through code from a week or month ago
to correct them.

Some companies go beyond keeping their software deliverable and actually
deploy every build to production, but following continuous delivery
practices doesn’t necessitate this. Building iteratively and integrating
along the way keeps software deliverable even when it isn’t desirable to
actually deploy it. Waiting for a feature to be fully mature before
deploying it to production still makes sense. A typical workflow is to
deploy all builds to a development environment where partially
implemented (but still stable) features can be explored in a fully
integrated environment. Once the feature is deemed complete, the build
artifact is promoted and released to production.

CI and CD are only as powerful as the teams using them however. How
teams organize and collaborate around these practices will largely
determine how successful they are.

## Keeping Configuration Lean

Microservices, like all software, usually require some sort of
configuration, and configuring the many services typically seen in a
microservice architecture can become confusing. By keeping it
lightweight and employing consistent strategies from service to service
we can help keep configuration manageable.

One way to keep configuration manageable is to have the environment
expose it to each microservice rather than bundling it with the
application. This separation keeps services decoupled from individual
environments making them more portable. When a microservice gets its
configuration from the environment it is running in, there can be less
divergence between how it is run in each. This reduces risk and makes
techniques like continuous integration and local development simpler.

Another way to keep configuration manageable is to employ convention
over configuration. This design technique simplifies configuration by
reducing the number of properties that must be maintained. Microservices
already provide an enormous amount of flexibility and exposing a vast
amount of configuration options is unnecessary.

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
before your are supporting so many services that issues or deficiencies
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

