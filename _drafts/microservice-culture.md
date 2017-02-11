---
layout: post
status: publish
published: true
title: Building a Microservice Culture
author_email: benschw@gmail.com
categories:
- Post
tags: []
---


## Building a Microservice Culture 

Adopting microservices is more than just learning a new design, it is
also a new way of building software that starts with the teams building
it. In the same way the software is organized around business functions,
so to should the teams be. This means teams should be cross functional
and include everyone needed to define, build, and run software for a set
of business functionality. The values and techniques of Agile
development and DevOps are ideal for building a culture that can take
full advantage of microservices.

### Agile

Microservices are a natural progression of agile software development.
Agile software development values building small, self organized, and
cross functional teams that are responsible for building and supporting
software. It is no accident that these values for a team of people sound
an awful lot like the values laid out for microservice software. Whether
microservice principals were born directly out of agile software or just
a response to the same problem, there is no question that the two go
hand in hand.

In the same way each microservice is organized around a business
function, so too should the team supporting the microservice be. With
agile teams, this is accomplished by building teams not just with
developers but with people from other functional areas of the company as
well. Typically, this means at least including a product owner with the
team. If you have quality assurance engineers then they too should be
included. It is also beneficial to have architects and system engineers
be a part of each agile team, however often there aren’t enough of these
people to go around and they must be shared among teams.

A team made up of people invested in a particular business function have
ownership and responsibility for the microservice that encapsulates that
business function. Of course a team will likely be responsible for
several business functions and several microservices, but they don’t
ever need to share ownership of a microservice. This protects the
bounded context of each microservice and plays to the effects of
Conway’s Law by organizing software in the same way the teams are
organized. In the same way that microservices which encapsulate a
business are loosely coupled the the rest of the application and as a
result can be lean and efficient, cross functional agile teams in charge
of a set of business functions or a product are kept loosely coupled
with other teams. This autonomy produces efficient and highly effective
teams.

Having loosely coupled teams also empowers teams to be self organized
and to evolve their practices and techniques. Much like the microservice
designs they are responsible for, agile team governance is
decentralized. Teams are empowered to define and evolve the practices
which work for them. Practices like retrospectives, where a team
periodically takes a step back and analyzes their practices and
techniques, help to empower self improvement. In a retrospective, a team
looks at which processes and techniques have been working, which haven’t
been working, and what could be tried to make them more effective. This
technique is equally applicable to the microservices they manage. Since
a team owns its microservices, they are empowered to model them
according to their specific domain and to update that model whenever it
makes sense. Teams still have to work together, just as microservices
must be integrated, but by keeping teams loosely coupled they can
continually optimize how they work without isolating themselves from the
other teams.

While Agile software development is largely about integrating product
stakeholders into the software development life cycle, equally important
is integrating the operational aspects of software development. In
recent years the term Devops has emerged to describe common ways of
doing just that.

### DevOps

DevOps is the name given for a number of practices and values involved
with improving both a company’s ability to manage and run its software,
and the relations between its development and operations teams. Often
DevOps gets confused with the tools or skills born out of its rise to popularity,
but in actuality Devops is about the culture of building and running
software as one integrated process.

In order for a microservice to be used effectively, its development
can’t stop when the tests pass and the build succeeds. Microservice
integrations, scaling requirements, and deployment cycles are every bit
as important to a microservice’s design as any particular implementation
detail. If teams are to be fully responsible for the microservices they
write then their involvement can’t stop once a feature is completed and
the microservice is ready to be deployed. The team is also responsible
for running and monitoring their software and the infrastructure it is
running on.

There are as many ways to integrate system operations more closely with
development as there are companies trying to do it, but mainly a balance
of three main approaches is used. One is to handle integrating system
operations the same way as is done with product owners in agile: embed a
system engineer on each agile team. When there aren’t enough system
engineers to go around (which is often the case) they can be a part of
more than one team. Another approach is to keep the system engineers
together as their own team but encourage communication and collaboration
between them and the agile teams. Sometimes these teams are even called
DevOps teams instead of system engineers to highlight their role of
working with development instead of down stream from them. A third way
is to put developers in charge of the operation of their own software.
This approach is by far the most difficult because finding engineers
that are experts in both fields is very hard, but when accomplished it
can be highly effective.

None of these methods are mutually exclusive however, and often the best
approach is to try different things out and see what combination or
balance works for you. How the concerns of development and operations
are melded together is the least important aspect of DevOps however;
more important is that a shared understanding of the development and
operational aspects of each microservice is held by the devs and the
ops.

Communication between different organizational units in a company is
frustrating and inefficient. For this reason, splitting up the
responsibility for a microservice can lead to overly complicated
implementations, broken encapsulation, and poorly understood
integrations that are prone to error. These concerns are no different
when applied to the management of a microservice’s implementation in
code or on its infrastructure in an environment. Sharing an
understanding for how a microservice is built and run results in more
stable software that is easier to maintain and evolve.

Microservices in particular go hand in hand with DevOps. Unlike
monolithic applications, the components of a microservice architecture
(microservices) integrate over various aspects of infrastructure that
have been historically the responsibility of a sysops team. Keeping this
responsibility isolated from the teams developing the microservices is
not tenable. In addition, a multitude of microservices with different
scaling requirements, datastores, and installation requirements requires
a high level of automation both for the production environment and for
the processes leading up to production. This automation can not be
successfully build by operations teams or development teams alone.

If this sounds intimidating, then I have some good news for you. The
relationship between microservices and DevOps is self-fulfilling and
symbiotic: If you have a mature DevOps culture, then introducing
microservices will be much easier. If you are having trouble fostering a
DevOps culture, then introducing microservices will almost certainly
drive its adoption.
