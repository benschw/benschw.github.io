---
layout: post
status: publish
published: true
title: Microservices
author_email: benschw@gmail.com
categories:
- Post
tags: []
---


## How did we get here?

The problem with writing successful software is that you are never done.
When we design software, we are constantly balancing just getting the
application to work with predicting how it will be used and how it will
grow. For ages we have been doing this, often with great success, by
dividing the problem into libraries and components that work together
within a monolithic application's single runtime to accomplish the job.
If things stopped there, we might be fine, except with success come
more users and more features. For a while, as the application grows and
evolves our design holds up and we are able to expand functionality and
shore up the infrastructure as we grow.

But eventually (inevitably), things start to break down. A part of the
application that started out simple has transformed into code that no
one wants to touch because it has been subjected to a gazillion
"enhancements" without ever knowing the love of being refactored. The
database has ended up with one particular table that has become super
important and is joined to in SQL queries by virtually everything (so we
can never, ever, ever, alter the schema without introducing a torrent of
regression bugs.)

As if that isn’t enough, the app's wild success has led to tripling the
head count of the development department to crank out new features;
except the additional developers don't add velocity, they add bugs and
frustration. At first, they tried feature branches to allow for parallel
development, except they ended up spending half their time merging
branches into master and solving integration problems. Next, they
decided to just work directly out of master and only release quarterly
(because that is how often they could coordinate complete features
between teams.) There are still a ton of integration headaches and bugs.

There are a million and one ways that well meaning and talented
developers can end up in this situation but only two ways to get out of
it: You can roll up your sleeves, wrap your brain around the problem,
and methodically go about reversing the damage; Or else you can throw it
all out and undertake a rewrite.

Regardless of which path you take (or maybe you're starting a new project and
don't have these problems... yet) microservices might be able to help manage
the complexity.

## What is a microservice?

Microservices aren't a silver bullet. They aren't a one-size-fits-all
solution either. They don't even really reduce complexity (they just
shift it around.) Microservices are a design strategy that is very good
at compartmentalizing the components of an application so that they can
grow and evolve independently over time without negatively impacting the
design of other components or the application as a whole. In some ways
microservices are yet another application design pattern, however in
other ways they are the next evolutionary step in application
architecture.

Practically speaking, microservices are small, loosely coupled, and
independently deployable services that are built around a business
function. We have always designed applications by breaking them down
into components that encapsulate a bounded context and can be composed
to expose greater functionality; By implementing these components as
microservices, we are able to better manage complexity and the evolving
needs of our application. By organizing the bounded context of each
microservice around a business function, our components can have interfaces
that expose functionality without necessitating an unnecessary understanding
of its implementation.

Implementing our application's components as web services comes at a
cost though. A high degree of automation and visibility is required to
deploy and support distributed architectures, and concerns such as
security and tolerance to failure must be addressed. For this reason, a
microservice architecture is not right for every problem and you will
have to weigh whether or not the complexities and problems solved by
microservices outweigh the ones they introduce. That said, many of the
complexities that come with microservices are up front costs that do not
increase over time or as you introduce new microservices.

Once you have weighed the pros and cons, and if you decide to move
forward with a microservice architecture, the next step is to start
designing it. At a high level, this means identifying the services which
will comprise an application and then determining how they will be
built, run, and supported. Whether introducing microservices to augment
an existing monolith application or from scratch with a greenfield
project, we must start at the same place. We start by analyzing the
application we are building in the context of how our company is
organized and according to our particular needs.

There is no canonical list of capabilities that a microservice should have,
but there are characteristics common among successful microservice designs
that have emerged and are quickly becoming best practices.

## Application Design with Microservices

Applications are typically comprised of smaller building blocks known as
components that collaborate to provide greater functionality and
microservices are no different. The primary distinction between a
monolith and microservice architecture is that the components of a
microservice architecture are implemented as web services. Just like
with a monolith, identifying the divisions of your application that will
be used as component boundaries is a crucial step in designing a
successful microservice architecture.

One of the advantages of microservices is that evolving the design of a
microservice, or even rewriting one completely, is relatively easy to
accomplish, but in order for this to be true it is important to plan a
good component model. First of all, components should be small enough
that when they are implemented as services they are easy to understand. In
addition, they should encapsulate all the business logic and data they
need in order to provide their functionality. Finally, they should be
fungible (it should be possible to replace one component without
refactoring others.)

### Loose Coupling with Bounded Contexts

A good microservice should encapsulate a bounded context. A bounded
context is a concept that comes from Domain-Driven Design (or DDD). In
DDD, the components of an application are organized around the various
contexts or domains in which your software can be interpreted.

As software gets larger, it becomes harder and harder to describe it
with a unified model. Your software might serve three different
departments in your company that each have their own definition for what
a product is, or it might be used by two different types of customers.
Describing all of these situations in a unified model is confusing and
makes communication hard.

To solve this problem, DDD says that you should divide your application
into bounded contexts, each with its own unified model. By providing
a context in which to interpret the model, it is ensured that the
vocabulary used will not contradict that of other components. This context
frees up the component's authors to describe their understanding of
the world as they see fit and to evolve that understanding (and vocabulary)
over time.

While bounded contexts are useful generally in software design, they are
especially relevant for microservices. A microservice provides a natural
boundary within which to encapsulate a bounded context. Organizing
microservices around bounded contexts helps to keep the task of
maintaining an accurate and meaningful model more intuitive. It also
facilitates an evolving model by explicitly defining the boundaries
within which the bounded context exists (and thus where changes can
occur without affecting the system as a whole.)

### Encapsulating a Business Function

One of the defining characteristics of a microservice is that it is
organized around a business function, but what does that mean and why is
it so important? Using a business function as the bounded context of a
microservice means including everything needed to provide some
functionality to the application as a whole in one place. This is
central to microservices for a couple of main reasons. For one, it helps
promote loose coupling by removing the need for repeated logic. Two, it
mimics the the organization of the business as a whole, which software
tends to gravitate towards naturally anyways.

Dividing applications in ways that cross-cut business function (as is
done in n-tier architectures where applications are separated into
layers such as presentation, business logic, and database) leads to
leaky, hard to maintain abstractions. When multiple components have to
be concerned with the same business function, implementation details are
hard to encapsulate and logic often gets repeated. As a result, changes
to one component usually require corollary updates to the other
components concerned with the same business function. In contrast,
dividing applications around business functions creates loosely coupled
components that can evolve or expand without breaking contracts with the
components which depend upon them.


<img width="100%" src="/images/ms-01.png" />

_In a three tier application, business functions often span multiple components
which leads to tightly coupled components. Microservices are each organized
around a business function promoting loose coupling._



Conway’s law states that software designs tend to mimic the
communication structures of the organizations which produce them. The
reasoning behind this idea is that when designing and integrating
software, people are using their organization's communication channels
to come to agreements. Thus natural bounded contexts form between the
communication barriers. This is not just limited to how developers
communicate either. How the business discusses and plans requirements
also has an influence.

By understanding this phenomenon however, you can turn it to your
advantage. By scoping a microservice to a business function,
communication barriers can be avoided. Fewer people have to understand
the bounded context, there is less confusion when planning requirements,
and in general there is less latency and confusion in getting things
done.

### Communicating with Distributed Components

Designing the components of an application is only half the battle
however; the components also need to communicate. In order to keep an
application’s components loosely coupled and maintainable, microservices
should expose a tightly controlled interface and use lightweight and well
known technologies.

Since communication bridges the bounded context encapsulated by each
microservice, it must be a part of the shared understanding everyone has
for the application. This means that simplicity is important and unlike
the technical decisions for individual microservices, you should
probably limit the number of technologies used to perform communication.
There are still different requirements for different types of
communication however, so don't feel like you have to settle on only
one.

A common microservice communication strategy is to expose RESTful JSON
APIs over HTTP. This works well for many components since the canonical
HTTP verbs lend themselves to getting, adding, updating, and deleting
data, and REST provides a good amount of structure without being so
prescriptive that clarity is sacrificed. Another common technique is to
use messaging with a messaging broker like RabbitMQ. In addition to allowing
for asynchronous communication, messaging allows for further decoupling
of components when used to implement patterns such as events.

Another consideration when choosing communication mechanisms is
portability. Even if every microservice in an application is written in
the same language, choosing a portable communication mechanism is still
a good idea. You may have to integrate with a third party or reporting
software. Using a portable communication mechanism ensures that there
will be library support no matter what language needs to use the
microservice.

In addition to how your application exposes its functionality and
information, what it exposes must also be determined. An individual API
is still within the bounded context of its respective service so it can
be managed according to its own needs. That said, the overall simplicity
of the application can be enhanced if there is some consistency. In the
end there is no right way to balance these two concerns and the
individual needs of an application and a given microservice interface
must be analyzed.

## The Technical Flexibility and Constraints of Microservices

Selecting and governing technologies for a microservice architectures is
different from selecting and governing the technologies of a monolith.
Microservices can leverage different technologies and even different
languages because of the isolation provided by their natural boundaries.
Decentralized technical design means governance can be decentralized as
well. These two traits allow microservice applications to stay flexible
and continually evolve. On the other hand, there are benefits to be had
from keeping integration technologies such as the mechanism by which
microservices communicate and the contract they hold with their
infrastructure part of an overall strategy.

### Implementing Data Persistence

Almost every piece of software has a need to persist data, but their
individual needs are often very different. Traditionally, the rule of
thumb is to select a good general purpose database that might not be the
best fit for many of an application's needs, but is sufficient to
satisfy them all. In microservices, the database is a part of the
bounded context. This means that each microservice should have its own
data store and that other services should not use it directly.

<img width="100%" src="/images/ms-02.png" />

_A microservice’s data is a part of its bounded context and should not be
shared except through its API_


Giving each microservice its own data store means that schemas can be
simple. Since each data store only exists within one bounded context
there is no need to worry about a unified model. The data schema only
needs to support the needs of one specific service. With microservices,
data can only be retrieved by other components through the microservice
interface. This allows the schema or even underlying technology to be
refactored and evolve will low risk and complexity. In the case of a
monolithic application’s database, tables often become an integration
point used across many components. This leads to a stagnant structure
that is very risky and complex to modify.

Isolating a data store behind one microservice also allows for the data
store technology to be more specialized. The best database (or
databases) can be selected for each microservice without increasing the
complexity of the application as a whole. One service can leverage a
lightweight relational database and another with vast amounts of data
can use an object store distributed across many nodes. This does not
mean that there is no cost for using multiple databases however; it is
still an additional technology to learn and operationalize.

Another aspect of data persistence is the transactionality requirements
of your application. It is not possible to achieve ACID (atomic,
consistent, isolated, and durable) compliant data persistence when the
task of persisting data is shared among more than one microservice. In
fact the CAP theorem (consistency, availability, and partition
tolerance) states that a distributed system can only guarantee two of
the three CAP attributes. This means that one of the three guarantees
will have to be sacrificed if an operation spans multiple microservices.

In addition to the flexibility of selecting optimized technologies for a
given microservice, the isolation of strong boundaries allows for
different designs to be applied. With a monolith architecture, the same
organizational patterns are generally repeated in an effort to keep the
application as a whole more understandable. With microservices it is
much more intuitive to solve individual problems with individual
solutions. This means that simple components, for instance those that
are little more than data access services, can get away with simple
designs and that components with more complexity can leverage a more
involved design. In addition, the complex problems can be better managed
because the design can be tuned to the specific complexities of that
problem.

Security is one example where leveraging microservice isolation to solve
specific problems with specific solutions is beneficial, but it is also
an example of where microservices introduce new complexities.

### Securing Microservices

Securing microservices is no small task. By dividing our application
into web services, we are exposing a lot of functionality that might
have remained hidden in a monolith application. This leaves a larger
surface for attack and means that even component interfaces which aren't
a part of the public API deserve closer scrutiny.

Keeping in mind what the services do and the sensitivity of the data
they expose, different strategies can be employed to secure your
application. Services that are only used internally and services that
make up the public API should be identified and an appropriate level of
security selected for each. Unless the application is completely
anonymous, the public API will likely need to be secured. It may be
sufficient to protect internal-only services by walling them off from
the public internet with networking, but if your application is higher
risk or uses sensitive data, then a more robust solution is probably
required. Depending on your application, encrypted communication might
be warranted too, even if the traffic never leaves your network.

Securing microservices can be a very complex problem, but it also has
its advantages. The services of a microservice architecture might be a
greater exposure than the components of a monolith, but they are also
very strong boundaries that are easier to ensure don't drift over time.
For this reason, controlling how the components of an application
communicate and limiting what each has access to can actually be a less
sprawling task with microservices than with the components of a
monolith. In addition, while an overarching security strategy should be
employed, the individual security models and implementations of each
microservice can be tuned and optimized to its needs.

