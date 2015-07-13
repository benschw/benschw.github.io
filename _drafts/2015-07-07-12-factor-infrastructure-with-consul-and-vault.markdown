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

- The Twelve Factor App

- Consul & Vault



## Let's build a cluster in Vagrant
The rest of this post is a walk through of a demo cluster build with [Vagrant](https://www.vagrantup.com/).
_Everything needed to follow along is included [on github here](https://github.com/benschw/vault-demo)._

The demo cluster is essentially a bunch of infrastructure to support an example `todo` REST api written in [Go](http://golang.org/).
(You can find the source for it [here](https://github.com/benschw/vault-todo) but feel free to
ignore it; the cluster will install a copy built and hosted by [Drone](https://drone.io/github.com/benschw/vault-todo/files).)

The example `todo` service is very simple and its only dependency is a mysql database, but supporting this
while maintaining the [twelve factor app methodology](http://12factor.net/) is easier said then done.

The main problems that using MySQL introduce surround sharing database credentials while
maintaining environment independence and security. We can't keep everything the same for all environments, because
that wouldn't be secure. We could drop config files on the box for our app to read, but that isn't the most
secure thing either and it is hard to manage (we would have to keep track of all those creds and where they go
as well as have a game plan for changing them.)

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


### The VMs
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

### Configuring the Cluster

In addition to [puppet-deps.sh](https://github.com/benschw/vault-demo/blob/master/puppet-deps.sh) 
(a script to clone all the puppet modules used for provisioning the cluster VMs), there are a series of scripts to
automate setting up `vault`: [01-init.sh](https://github.com/benschw/vault-demo/blob/master/01-init.sh),
[02-unseal.sh](https://github.com/benschw/vault-demo/blob/master/02-unseal.sh),
[03-configure.sh](https://github.com/benschw/vault-demo/blob/master/03-configure.sh),

In the fourth script, [04-provision-todo.sh](https://github.com/benschw/vault-demo/blob/master/04-provision-todo.sh),
`user-id` auth tokens are added to vault and then injected into vagrant to provision the `todo` services.


This work could be included in the normal vagrant provisioning, but it doesn't belong there. In order to rely on vault
to keep our data secret, we can't just allow our normal config management to manage it. Since our secrets are only as
reliable as the source managing them, we typically want these to be one off operations performed by a human and not a
system perpetually authenticated in our datacenter.

Since we are just trying things out though, I've scripted the work needed to bootstrap our example (but kept it out
of vagrant provisioning so it would be easier to picture the different aspects of configuring a cluster to use vault.)


Take a look at the scripts to see exactly whats going on, but basically it uses the vault REST api to perform the following work:

- *[Initialize the Vault Data Store.](https://vaultproject.io/docs/http/sys-init.html)* This must be run once, when you bring your first vault server online in an environment.
- *[Unseal each Vault Server.](https://vaultproject.io/docs/http/sys-unseal.html)* Every time a vault server is started (either when bringing on a new server, or restarting
  an existing one) it must be unsealed. If everything needed to access secret data was stored at rest, it would be easier to break in.
- *[Create a "todo" Policy.](https://vaultproject.io/docs/http/sys-policy.html)* This manages what secrets our app will have access to once authenticated.
- *Set up the [MySQL Backend.](https://vaultproject.io/docs/secrets/mysql/index.html)*
	- *Mount a MySQL Secret Backend.* This component will allow vault to generate database credentials dynamically for our app.
	- *Configure MySQL Secret Backend.* Set privileged connection settings for vault to use when creating credentials;
      set the lease and max usage period for generated credentials (We are just leasing them for a minute to make the demo easier to inspect)
	- *Create a MySQL "todo" Role.* With vault configured to create credentials, we next set up a role
      with a templated SQL command that will grant the appropriate database permissions for our "todo" app. The username and password aren't included, because that's
	  what vault will be generating for us.
- *Set up the [App-Id Auth Backend.](https://vaultproject.io/docs/auth/app-id.html)*
	- *Enable the "app-id" Auth Backend.* There are several options built into vault for authentication; we will be using "app-id".
    This method relies on two tokens to authenticate. One, the `app-id`, is created ahead of time and can be included in your VM with config management.
	The second token, `user-id`, needs to be unique per instance and made available in some way other than config management to keep all our eggs out of one basket.
	- *Create "app-id" Token for "todo" App.* This is the `app-id` used by each instance of our `todo` service. When we add it to vault, 
    we also associate it with the "todo" policy (which in tern allows access to the mysql "todo role" credential generator.)
    In addition to setting the app-id here, we have [made it available via heira](https://github.com/benschw/vault-demo/blob/master/hiera/todo0.yaml) to puppet to configure the "todo" instances with.
	- *Create "user-id" Token for "todo" App.* Finally, we create two `user-id`s for our two `todo` instances and pass them to `vagrant up todo0` and `vagrant up todo1`
	as environment variables so they can be set on the new instances without going through our puppet configuration. In a real environment, this would ensure that only
	trusted instances were given a `user-id` since a privileged user must be authenticated to create one.

### Just Build it Already!
	
	# clone the puppet modules used to provision our cluster
	./puppet-deps.sh  
	
	# provision the core infrastructure
	vagrant up consul vault0 vault1 mysql

	# initialize, unseal, and configure `vault`
	./01-init.sh && ./02-unseal.sh && ./03-configure.sh
	
	# mint `user-id`s and provision the `todo` instances configured with them
	./04-provision-todo.sh

	# confirm that everything went well
	./test-todo-service.sh
	
If you want to watch the todo service come online like in my recording below, just run the test script with watch:

	watch --color ./test-todo-service.sh

_recording of the cluster being provisioned_
<a href="/images/boot-crop-opt.gif"><img class="post-image-full" src="/images/boot-crop-opt.gif" alt="provisioning the cluster" width="618" height="300" class="alignnone size-full" /></a>


Sure the test works, but maybe you want to see the service in action for yourself!
Here's an example of how to use the `todo` api:

	curl -X POST http://172.20.20.14:8080/todo -d '{"status": "new", "content": "Hello World"}'
	{"id":1,"status":"new","content":"Hello World"}

	curl http://172.20.20.14:8080/todo/1
	{"id":1,"status":"new","content":"Hello World"}

	curl -X PUT http://172.20.20.14:8080/todo/1 -d '{"status": "open", "content": "Hello Galaxy"}'
	{"id":1,"status":"open","content":"Hello Galaxy"}

	# (we can use the other node too)
	curl http://172.20.20.15:8080/todo/1
	{"id":1,"status":"open","content":"Hello Galaxy"}

	curl -i -X DELETE http://172.20.20.15:8080/todo/1
	HTTP/1.1 204 No Content
	Content-Type: application/json
	Date: Thu, 09 Jul 2015 15:21:48 GMT



## How does it all work?

In the following sections I will talk about how the various components scale and interact as well as how
they (and subsequently the todo service) behave in the face of various failures.
Each failure I introduce is accompanied by a recording which will hopefully help
illustrate the behaviors.

Each recording has the same seven terminal panes included:

- The top left pane is a health check running from my host OS to monitor the two `vault` and two `todo` vms.
  (The top two addresses are `vault`, the bottom two are `todo`)
- The bottom left pane is also a terminal on my host OS.
- The right panes are sessions in each vm (except the consul server which I left out) where I will
  start and stop services to simulate failures. From top to bottom: `vault0`, `vault1`, `mysql`, `todo0`, `todo1`.

### Consul
Consul uses [The Raft Consensus Algorithm](https://raftconsensus.github.io/) to manage
a highly consistent and highly available key/value and service discovery cluster. It also uses
[Serf and the Gossip Protocol](https://www.serfdom.io/docs/internals/gossip.html)
to share state between the cluster nodes. This essentially allows each node to discover
all other nodes (as well as the services registered on them) by simply joining the cluster.

Every VM has a consul client running on it that keeps the primary service of that VM
registered with consul for discovery. This way, VMs can come and go or change IP and
the services that rely on them don't need to be reconfigured.

...But I only included a single consul server node in this demo and if we take it away bad things
will happen. I'll skip the "fail" video since this is a solved problem
that I only omitted in the demo because I was already up to 6 vms.

(Here's a post I wrote previously on [Provisioning Consul with Puppet](/2014/10/consul-with-puppet/), or
just scan through [all of my posts](/all-posts/) - I think roughly half are about or use consul.)

### Vault
Each vault instance is stateless and are as HA as their backend. We are using consul's key/value
store as a backend, so we can make vault HA by standing up two servers, both pointed at our consul server.

Vault provides high availability by electing a `leader` server and having additional servers
standing by to take over in the event of a problem. These nodes also do request forwarding to the leader.

Multiple failover instances offer essentially the same resiliency as multiple stateless
services, but they don't help to scale the application. In
[the vault docs](https://vaultproject.io/docs/concepts/ha.html) they state that
"in general, the bottleneck of Vault is the physical backend itself, not Vault core"
and suggest scaling the backend (consul in our case) to increase vault's scalibility.

#### failure demo:

In the following recording, you can see that both todo instances remain healthy unless
all vault servers go down.

You can also see that the todo services don't start failing for awhile after both
vault servers are in a critical state. This is because the mysql creds vault is 
exposing to the todo service are good for a minute, so the app doesn't realize vault
is gone for up to a minute. We could actually avoid a "todo" failure alltogether 
by hanging onto our old connection if vault isn't available, but I left that 
logic out of the todo service since this is largely a vault demo. Additionally, 
we wouldn't want to entirely rely on this since new services would have nowhere 
to get their creds from.

Another thing to note is that after I start a vault server back up, I still need to unseal it
(by running a script from my host OS in the bottom left pane) before it becomes healthy again.
_Every time we add a new vault server or restart an existing one, it must be manually unsealed._


<a href="/images/vault-crop-opt.gif"><img class="post-image-full" src="/images/vault-crop-opt.gif" alt="mysql failure demo" width="618" height="300" class="alignnone size-full" /></a>

_At the time of writing this, the most recent vault release is `0.1.2`. This release has a bug that
makes failing over with a consul backend very slow. The bug is fixed in `master` however,
so I went ahead and built the server used in this demo from that._

### MySQL
Next up, the uncomfortable single point of failure: MySQL.

There are of course strategies involving replicating to slaves or even master-master replication,
but those are all out of scope for this demo.

We are still, however, exposing the address to MySQL to our "todo" service with consul so
that if we decided to add in an HA mechinesm, it could be done without needing to
rework our application.

#### failure demo:

For completeness however, here's our service crashing hard when we take away MySQL:

<a href="/images/mysql-crop-opt.gif"><img class="post-image-full" src="/images/mysql-crop-opt.gif" alt="mysql failure demo" width="618" height="300" class="alignnone size-full" /></a>

### Todo
Our todo service is stateless, relying entirely on MySQL to store todo entries.
In addition, we are always requesting an address to an instance through consul, which
will only respond with healthy addresses. We are also registering the "todo" service with consul
so as long as others discover it through that interface, we can scale it by adding instances.

There is no other configuration needed for our app, but if there was we could add it to consul's
key/value store in order to maintain a clean contract with our system and zero divergence
between environments.

This means that our todo service can be installed in any environment without modification 
and that instances can come and go (and new instances can be added) and they will 
neatly fold in the the existing ecosystem.

#### failure demo:

In the following recording, track the status of the todo instances in the top left pane.
The "Health" column shows the instance's status according to consul, and the "Test"
column shows the instance's status according to a test run from our host OS. For the most part
this test won't fail because we aren't testing services known to be unhealthy, but there is
a narrow window (up to 5s) after the instance has been stopped but before consul has run its
health check and noticed the problem.

<a href="/images/todo-crop-opt.gif"><img class="post-image-full" src="/images/todo-crop-opt.gif" alt="todo failure demo" width="618" height="300" class="alignnone size-full" /></a>


## There are a few blemishes though...

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


