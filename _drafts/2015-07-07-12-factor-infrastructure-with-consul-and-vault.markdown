---
layout: post
status: publish
published: true
title: 12 Factor Infrastructure with Consul and Vault
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---




<!--more-->

## The Twelve Factor App

## Consul & Vault



## Try it Out with Vagrant
overview

### Building Your Cluster

#### The VMs

#### Helper Scripts

### Todo, a REST Service

### Can we break it?

In the following sections I will explain how the todo service behaves in the
face of various failures. Each failure I introduce is accompanied by a recording
which will hopefully help illustrate the various behaviors.

Each recording has the same seven terminal panes included:

- The top left pane is a health check running from my host OS to monitor the two `vault` and two `todo` vms.
  (The top two addresses are `vault`, the bottom two are `todo`)
- The bottom left pane is also a terminal on my host OS.
- The right panes are sessions in each vm (except the consul server) where I will
  start and stop services to simulate failures. From top to bottom: `vault0`, `vault1`, `mysql`, `todo0`, `todo1`.

#### Todo Failures
Our todo service is stateless, relying entirely on MySQL to store todo entries. 
In addition, we are always requesting an address to an instance through consul, which
will only respond with healthy addresses.

This means that any particular instance can come and go without interupting service to the `todo` service as a whole.

In the top left pane you can track the status of the todo instances.
The "Health" column shows the instance's status according to consul, and the "Test"
column shows the instance's status according to a test run from our host OS. For the most part
this test won't fail because we aren't testing services known to be unhealthy, but there is
a narrow window (up to 5s) after the instance has been stopped but before consul has run its
health check and noticed the problem.

<a href="/images/todo-crop-opt.gif"><img class="post-image-full" src="/images/todo-crop-opt.gif" alt="todo failure demo" width="851" height="446" class="alignnone size-full" /></a>


#### Vault Failures
Vault provides high availability differently from our todo service. All requests
are routed to the `leader` server and additional servers are just standing by to
accomplish a hot failover in the event of a problem with the current leader.

Multiple failover instances offer essentially the same resiliency as multiple stateless 
services, but don't allow for the ability to scale by adding new instances.

In the following recording, you can see that both todo instances remain healthy unless
all vault servers go down.

You can also see that the todo services don't start failing for awhile after both
vault servers are in a critical state (or maybe you can't since the recording is sped up so much...)
This is because the mysql creds vault is exposing to the todo service are good for a minute
so it doesn't realize vault is gone for up to a minute. We could actually avoid a "todo"
failure alltogether by hanging onto our old connection if vault isn't available,
but I left that logic out of the todo service since this is largely a vault demo.
Additionally, we wouldn't want to entirely rely on this since new services would have
nowhere to get their creds from.

Another thing to note is that after I start a vault server back up, I still need to unseal it
(by running a script from my host OS in the bottom left pane) before it becomes healthy again.
_Every time we add a new vault server or restart an existing one, it must be manually unsealed._


<a href="/images/vault-crop-opt.gif"><img class="post-image-full" src="/images/vault-crop-opt.gif" alt="mysql failure demo" width="851" height="446" class="alignnone size-full" /></a>

_At the time of writing this, the most recent vault release is `0.1.2`. This release has a bug that
makes failing over with a consul backend very slow. The bug is fixed in `master` however,
so I went ahead and built the server used in this demo from that._

#### MySQL Failures
Last, the uncomfortable single point of failure: MySQL.

There are of course strategies involving replicating to slaves or even master-master replication,
but those are all out of scope for this demo.

For completeness however, here's our service crashing hard when we take away MySQL:

<a href="/images/mysql-crop-opt.gif"><img class="post-image-full" src="/images/mysql-crop-opt.gif" alt="mysql failure demo" width="851" height="446" class="alignnone size-full" /></a>

#### Consul Failures
Consul uses [The Raft Consensus Algorithm](https://raftconsensus.github.io/) to manage
a highly consistent key/value and service discovery cluster, but I didn't include one in this demo.

(Here's a post I wrote previously on [Provisioning Consul with Puppet](/2014/10/consul-with-puppet/))

Even more out of scope!
