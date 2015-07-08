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
The rest of this post is a walk through of a demo cluster build with [Vagrant](https://www.vagrantup.com/).
_Everything needed to follow along is included [on github here](https://github.com/benschw/vault-demo)._

The demo cluster is essentially a bunch of infrastructure to support an example `todo` REST api written in [Go](http://golang.org/).
(You can find the source for it [here](https://github.com/benschw/vault-todo) but feel free to
ignore it too; the cluster will install a copy built and hosted by [Drone](https://drone.io/).)

The example `todo` service is very simple and its only dependency is a mysql database, but supporting this
while maintaining the [twelve factor app methodology](http://12factor.net/) is easier said then done.

The main problems requiring MySQL introduces, are the requirements around sharing database credentials while
maintaining environment independence. We can't keep everything the same for all environments, because
that wouldn't be secure. We could drop config files on the box for our app to read, but that isn't the most
secure thing either and it is hard to manage. On top of all that, we have to keep track of all those creds for various apps
and have a game plan for if we ever need to change them.

Vault solves these problems for us by managing the creation and access to creds with the
[MySQL Secret Backend](https://vaultproject.io/docs/secrets/mysql/index.html), in addition to
the policies which define what a given app has access to with native
[Access Control Policies](https://vaultproject.io/docs/concepts/policies.html) and
pluggable auth backends (our demo will use the [App ID Auth Backend](https://vaultproject.io/docs/auth/app-id.html)).

A second problem, is that your MySQL database probably lives at different addresses in different environments.
We use `consul` to addresses this issue by always looking up the address to MySQL via consul. This way we
don't have to care about the actual address to MySQL, we can always just look it up via `mysql.service.consul`
regardless of what environment we are in.

With these problems solved, we are left with a single `todo` service artifact that we can install
in any environment and that we can scale by adding as many instances as we want.


### Building Your Cluster

#### The VMs
- `consul` is our consul server vm which all other nodes with register and discover through.
  It also offers up its key/value store for vault to use as a [data backend](https://vaultproject.io/docs/config/index.html).
  In a real environment, we would want more instances of this clustered up to provide high availability.
- `vault0` is one of two nodes running the vault server. When it comes online, the vault service is registered with consul
  so that other services (`todo`) can discover it. Its health check is configured such that it is made available when
  the vault server is running and unsealed. It is configured to store all of its secret data in consul under the `vault` key.
  Vault's sole job in our demo cluster is to generate mysql credentials and expose them to our `todo` services.
- `vault1` is the second vm running the vault server. Since it will boot second, it will come online in `stand by` mode. This meens
  that it won't actually respond to requests from services, but instead redirect them to the leader (`vault0`.)
  In the event of a failure on `vault0`, it will take over as leader and start servicing requests directly.
- `mysql` is a mysql server. Vault is configured to manage creds for it using a `vaultadmin` account created with puppet, and
  our `todo` services will use it to store the todo entriess that it supports.
- `todo0` is an instance of our todo REST api. It is a stateless app that manages todo entries, 
  uses MySQL (discovered with consul) to for data persistence, and uses vault to aquire creds to its MySQL database.
- `todo1` is a second instance of the todo service. Since these services are stateless, they are also totally interchangable.

#### Helper Scripts
puppet-deps.sh  

01-init.sh  
02-unseal.sh  
03-configure.sh  
04-provision-todo.sh  

test-todo-service.sh 
hiera  puppet  
README.md  root_token  
set_user_id.sh  

#### Just Build it Already!
	
	# provision the core infrastructure
	vagrant up consul vault0 vault1 mysql

	# initialize, unseal, and configure `vault`
	./01-init.sh && ./02-unseal.sh && ./03-configure.sh 
	
	# mint `user-id`s and provision the `todo` instances configured with them
	./04-provision-todo.sh  

	# confirm that everything went well
	./test-todo-service.sh 

	# how do I know that test script isn't faking something?
	curl -X POST http://172.20.20.14:8080/todo -d '{"status": "new", "content": "Hello World"}'


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

(Here's a post I wrote previously on [Provisioning Consul with Puppet](/2014/10/consul-with-puppet/), or
just scan through [all of my posts](/all-posts/) - I think roughly half are about consul :))

So, sorry to disapoint, but we only have one consul vm in this demo and if we take it away bad things
will happen. I'll skip the "fail" video however, since this is a solved problem
that I only omitted in the demo because I was already up to 6 vms.

### There are a few warts though...

- requires a person to unseal
- requires a person to provision instances
- doesn't scale with the addition of new nodes
- weak ecosystem
	- not much buzz about it
	- no puppet module

All that being said, [Hashicorp](https://hashicorp.com/) has a great track record of building solid, well received
apps (such as [consul](https://consul.io/) and [vagrant](https://www.vagrantup.com/) featured in this demo) and
vault is still very young ([April 28th, 2015](https://hashicorp.com/blog/vault.html)) so I have high hopes
that this will be another win for safe, resilient, and simple infrastructure.


