---
layout: post
status: publish
published: true
title: Agile Architecture
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

This is my take on how the [Agile Manifesto](https://agilemanifesto.org/) can be applied to architecture. While certainly not exhaustive,
I've tried to include not just generalizations but also tangible ways to apply the principals of Agile to your own architectural practices.

<!--more-->

## Individuals and interactions over processes and tools

### Shared understanding of the design
It is important for a dev team to have a shared understanding of the vision and
goals of an application and its design.

* A common understanding of an application's design:
	* Helps to ensure that collaboration can occur with minimal friction
	* Helps prevent false starts and wasted effort on divergent solutions
	* Results in a leaner application that behaves more efficiently

#### Method
* Maintain a high level design of the application that can be referenced. This design
  should be kept up to date as it evolves.
* Organize full team design sessions to help ensure that there is a shared understanding
  not just of how the application solves a problem, but why it does it in the way it does.

### Software benefits from more than one set of eyes
More than one developer should understand each software component and be involved in the
process of bringing it to life.

* Software built by more than one developer benefits from:
	* The multiple experiences and backgrounds of its authors
	* Constant discussion of a problem helps prevent fragile implementations and
	  development efforts that get "stuck in a rut"
	* Over time, it is easier to share knowledge about the component and ensure
	  there are people available to work on it

#### Method
* Pair programming or shared ownership over each software component ensures
  that the software is benefiting from a high degree of collaboration.
* Code Reviews can't replace collaboration: a code review from an outside developer
  is useful for many reasons, but if the outside developer has an insuficient
  depth of knowledge regarding the piece of software they will be unable to effectively
  review how well the software meets its goals and the review may turn into a proofreading excercise.

## Working software over comprehensive documentation

### Test your design early
Trying to determine how all the components of a system will interact to acheive
a project's goals leads to a waterfall approach. This either necesitates
rework when what we think we know changes, or else blind adherance to a plan without
realizing that we are not longer solving problems in the most effective way.

- Regardless of how much up front work goes into planning an implementation, our
  understanding of the problem is likely to evolve and our software implementation
  should evolve along with it.
- Determining how something will work based on up front assumptions has dimishing returns
  while iterative planning and review allows for a design to be refined with
  the best possible information.

#### Method
- Tracer bullet architecture (building out the scaffolding of the entire application
  before iterating on the implementation of its business logic) is one approach
  for ensuring that software works from day-one, can be grown and refined without
  deviating from the project's goals, and that risk isn't unnecessarily deferred.
- Build software iteratively rather than incrementally. (Compare to a printer
  vs. an artist: A printer creates a picture incrementally by drawing line by line
  starting at the top. An artist creates a picture iteratively by sketching the outline,
  then shading in the detail, and finally adding color and other final touches.)
	- With an iterative approach, designs and implementations can easily evolve
	  as more is known. With an incremental approach, problems aren't identified
	  until later and course corrections require more rework.

## Customer collaboration over contract negotiation

### Shared understanding of business objectives
It is important for a team to have a shared understanding with the business
regarding the vision and goals of a project.

- A common understanding of the business functions, domain knowledge, and nomenclature used to describe an application:
	- Ensures that the right features are built
	- Enables developers to provide feedback regarding the assumptions of the business
	- Facilitates an evolving solution that better meets the underlying goals of the application

#### Method
- Make the development team aware of why they are building an application, not just what it should do
- Promote discussion between development and the business regarding requirements
- Collaborate on building a roadmap and requirements for beta, mvp, and beyond
- Perform regular demos to ensure development is tracking with the business vision

## Responding to change over following a plan

### Build based on feedback from the system
As software is built, our understanding of how it works changes and up front planning
will likely diminish in relevance.

- The plan for building an application should evolve with our understanding of how our
  software is actually performing. As we learn more about the systems we are building
  our design and priorities should be updated to accomodate this new information.
- Software should be built to facilitate early feedback:
	- Understanding early how a design or integration plan stands up to actual
	  implementation makes it easier to course correct and less likely to result in
	  overly cumbersome interfaces that satisfy "what we thought we needed"
	  instead of "what we actually need"
	- When coupled components are developed separately and to a specification,
	  the likelyhood that an impedence mismatch will be introduced and allowed to
	  grow unchecked increases.

#### Method
- Regular backlog grooming with design discussions ensure that designs and requirements
  are kept up to date with current information
- Implement continuous integration and continuous deployment:
	- Prevents drift in integration goals by shedding light on impedence mismatches quickly
	- Brings design failures to light early so they can be corrected without creating
	  an excess of rework.
	- Brings design failures to light early so they can be corrected rather than
	  being allowed to remain and solved for with work-arounds.
	- Bugs are caught more quickly (though this is the least important benefit of CI/CD)
- Effective use of automated testing facilitates more frequent integration and thus
  faster and more frequent feedback

### Pay special attention to integrations with outside software
The adoption of new technologies and integration with vendors is often the biggest
source of risk for a project. In addition to bringing a design to life, it must
be integrated with a system that may not behave in a way that is expected.

- The full cost of integrating with a vendor or new technology can't be
  fully understood up front and won't be until completed.
- If the assumptions about a vendor or new technology prove to be wrong, a new
  solution may need to be found.

#### Method
- Integration with a vendor or new technology should be identified as higher
  risk and performed early. This will:
	- Remove the unknown cost of integration as soon as possible
	- Bring the domain knowledge into the team's shared understanding to ensure
	  that development doesn't procede with a blind spot
	- Give adequate time to go back to the drawing board if the vendor or
	  technology doesn't work out
- Use an existing technology instead. Does the problem being solved with a new
  technology really warrant the cost and risk of adopting a new technology?

## Other
### Optimize for the platform, not the local problem
The benefits of the consistency acheived through shared patterns and technologies
often outweigh the benefits of a software design that is optimized for a specific
problem.

- Consistent patterns, techniques, and technologies promote:
	- Systems that are understood and supportable by more people
	- Less automation and implementation work to get off the ground
	- Less risk from integrating with new software
	- Systems that can more easily be kept up to date

#### Method
- Determine if a similar problem has already been solved by another team
- When adopting a new technology, compare the pros and cons of using an existing
  technology. Are you accurately accounting for all the non-functional costs of
  bringing in new software?
