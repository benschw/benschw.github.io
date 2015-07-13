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

[The Twelve Factor App](http://12factor.net/) is a description of how to build apps that run well on
[Heroku](https://devcenter.heroku.com/articles/architecting-apps), but it's also proven to be of general usefulness in
describe good principals for modern web application design.

A twelve factor app is only useful if you have an infrastructure that supports it however; that's what we'll be focusing on here.

<!--more-->

Some of the twelve factors are more prescriptive then others, but most of them boil down to a few general principals:

- Maintain portability between environments by keeping a clean contract with your infrastructure.
- Use declarative automation to maintain environments and deployments in order to keep things repeatable.
- Allow for scaling and high availability without a bunch of extra work.
	
This post will walk you through building an example infrastructure that holds to these principals using
[Vault](https://vaultproject.io/) to manage MySQL credentials and [Consul](https://consul.io/) for service discovery.
We'll build the core, land a demo [todo service](https://github.com/benschw/vault-todo) in the cluster, and then take a look at how the
different services interact and how they behave when there are failures.


## Getting Started

We'll be building out the example infrastructure in a cluster with [Vagrant](https://www.vagrantup.com/); everything needed to follow along is 
included [on github here](https://github.com/benschw/vault-demo).

The demo cluster is essentially a bunch of infrastructure to support an example `todo` REST api written in [Go](http://golang.org/).
(You can find the source for it [here](https://github.com/benschw/vault-todo) but feel free to
ignore it; the cluster will install a copy built and hosted by [Drone](https://drone.io/github.com/benschw/vault-todo/files)
and I'll explain how to use it later on.)

The example `todo` service is very simple and its only dependency is a mysql database, but
sharing database credentials while maintaining environment independence and security is easier said then done.

We can't keep credentials consistent across all environments because
that wouldn't be secure. We could drop config files on the box for our app to read, but that isn't the most
secure thing either and it is hard to manage (we would have to keep track of all those creds and where they go
as well as have a game plan for changing them.)

[Vault](https://vaultproject.io/) solves these problems for us by managing the creation and access to creds with the
[MySQL Secret Backend](https://vaultproject.io/docs/secrets/mysql/index.html),
what a given app has access to with
[Access Control Policies](https://vaultproject.io/docs/concepts/policies.html),
and pluggable auth backends (our demo will use the [App ID Auth Backend](https://vaultproject.io/docs/auth/app-id.html)).

A second problem is that your MySQL server probably lives at a different address in each environment.
We use [consul](https://consul.io/) to provide a consistent way to discover it.
This way we don't have to care about the actual address to MySQL, we can always just look it up via `mysql.service.consul`
regardless of what environment we are in.

With these problems solved, we are left with a single `todo` artifact that provides our service and gets all of its configuration
from the environment it is installed in. This way we can install the same thing in all environments and add as many instances as
we want to scale it.


### The VMs
Before we start provisioning the cluster, here's a list of the VMs we will build and what their role in the cluster is.

- `consul` provides our consul server (in a real environment, we would have several instances to provide high availability.)
  Services in the cluster register their address with consul and discover other services through it, and vault makes
  use of the key/value store it exposes as a [data backend](https://vaultproject.io/docs/config/index.html).
- `vault0` is one of two nodes running the vault server. Though vault can be used for much more, we are only using it
  to generate and expose MySQL credentials to our todo services. In addition to storing its data in consul, vault
  registers its address with consul with a health check configured that ensures only healthy, unsealed instances of vault
  are offered up for use.
- `vault1` is the second vm running the vault server. Since it will boot second, it will come online in `stand by` mode. This means
  that it won't actually respond to requests from services, but instead redirect them to the leader (`vault0`.)
  In the event of a failure on `vault0`, it will take over as leader and start servicing requests directly.
- `mysql` provides a MySQL server. Vault is configured to manage creds for it using a _vaultadmin_ account and
  our todo services will persist todo entries to it.
- `todo0` is an instance of our todo app, a REST api that manages todo entries. It uses MySQL (discovered with consul) 
  for data persistence and vault (also discovered with consul) to aquire MySQL creds.
- `todo1` is a second instance of the todo service. Since these services are stateless, they are also totally interchangable.

### Configuring the Cluster

Provisioning this cluster is a little more involved than a typical vagrant cluster. Configuring and managing
vault shouldn't be done entirely by configuration management since you're going to rely on it to keep your secrets safe.
We typically want these operations to be initiated (or even performed directly) by a human and not a
system that remains perpetually authenticated within our datacenter.

For this reason, I've provided scripts to configure vault rather than doing it in puppet the way the rest of 
the cluster is configured. These scripts are in no way secure (Probably shouldn't write out the vault key and root token to files
accessible within your production cluster for instance) but are included to illustrate the separation of configuration concerns while
trying to keep the demo cluster automated.

_Following are the scripts used to configure vault:_

#### [01-init.sh](https://github.com/benschw/vault-demo/blob/master/01-init.sh)

- *[Initialize the Vault Data Store.](https://vaultproject.io/docs/http/sys-init.html)* This must be run once, when you bring your first vault server online in an environment.

#### [02-unseal.sh](https://github.com/benschw/vault-demo/blob/master/02-unseal.sh)

- *[Unseal each Vault Server.](https://vaultproject.io/docs/http/sys-unseal.html)* Every time a vault server is started (either when bringing on a new server or restarting
  an existing one) it must be unsealed. If everything needed to access secret data was stored at rest, it would be easier to break in.

#### [03-configure.sh](https://github.com/benschw/vault-demo/blob/master/03-configure.sh)

- *[Create a "todo" Policy.](https://vaultproject.io/docs/http/sys-policy.html)* This manages what secrets our app will have access to once authenticated.
- *Set up the [MySQL Backend.](https://vaultproject.io/docs/secrets/mysql/index.html)*
	- *Mount a MySQL Secret Backend.* This component will allow vault to generate database credentials dynamically for our app.
	- *Configure MySQL Secret Backend.* Set privileged connection settings for vault to use when creating credentials;
      set the lease and max usage period for generated credentials (We are just leasing them for a minute to make the demo easier to inspect)
	- *Create a MySQL "todo" Role.* With vault configured to create credentials, we next set up a role
      with a templated SQL statement that will grant the appropriate database permissions for our "todo" app. The username and password aren't included, because that's
	  what vault will be generating for us.
- *Set up the [App-Id Auth Backend.](https://vaultproject.io/docs/auth/app-id.html)*
	- *Enable the "app-id" Auth Backend.* There are several options built into vault for authentication; we will be using "app-id".
    This method relies on two tokens to authenticate. One, the `app-id`, is created ahead of time and can be included in your VM with config management.
	The second token, `user-id`, needs to be unique per instance and made available in some way other than config management to keep our eggs out of a single basket.
	- *Create "app-id" Token for "todo" App.* This is the `app-id` used by each instance of our `todo` service. When we add it to vault, 
    we also associate it with the "todo" policy (which in turn allows access to the mysql "todo role" credential generator.)
    In addition to setting the app-id here, we have [made it available via heira](https://github.com/benschw/vault-demo/blob/master/hiera/todo0.yaml) 
	for puppet to configure the "todo" instances with.


#### [04-provision-todo.sh](https://github.com/benschw/vault-demo/blob/master/04-provision-todo.sh)

- *Create "user-id" Token for "todo" App.* Finally, we create two `user-id`s for our two `todo` instances and pass them to `vagrant up todo0` and `vagrant up todo1`
	as environment variables so they can be set on the new instances without going through our puppet configuration. In a real environment, this would ensure that only
	trusted instances were given a `user-id` since a privileged user must be authenticated to create one.
	The "todo" service's [init script](https://github.com/benschw/vault-demo/blob/master/puppet/templates/todo.init.erb) will pick up the user-id and app-id
	and inject them as environment variables into the todo service.

### Just Build it Already!
	
	# clone the demo repo
	git clone https://github.com/benschw/vault-demo.git
	cd vault-demo

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
a highly consistent and highly available key/value and service discovery cluster. It uses
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
just scan through [all of my posts](/all-posts/) - I use consul in a lot of them.)

### Vault
Each vault instance is stateless and a cluster of them is as HA as its backend. We are using consul's key/value
store as a backend, so we can make vault HA by standing up two servers backed by our consul cluster.

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

For completeness, here's our service crashing hard when we take away MySQL:

<a href="/images/mysql-crop-opt.gif"><img class="post-image-full" src="/images/mysql-crop-opt.gif" alt="mysql failure demo" width="618" height="300" class="alignnone size-full" /></a>

### Todo
Our todo service is stateless, relying entirely on MySQL to store todo entries.
In addition, we are always requesting an address to it through consul which
will only respond with addresses to healthy instances. We are also registering the "todo" service with consul
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


## That's great, sign me up!

Vault is a promising application, but there are a few areas where its immaturity is still cause for concern.

One, it's hard to automate. Managing secrets securely is hard and to do it right a person often has to get involved.
The pain (inconvenience) this causes is especially apparent in the "unseal" requirement when starting a vault server.
This is addressed [in the docs](https://vaultproject.io/docs/concepts/seal.html) as something there are plans to address,
but for now we're stuck doing it by hand.

Another potential problem is a weak ecosystem. It's hard to expect too much since the product is so new, but it's still
difficult to adopt a bleading edge application to use at the core of your infrastructure when it's hard to find people
talking about it. Additionally, there isn't community support software (like a puppet module to install it) yet, so
you'd be managing a lot yourself (you can hound [solarkennedy](https://twitter.com/solarkennedy) for this, he did a great job
with [puppet-consul](https://github.com/solarkennedy/puppet-consul)).

Lastly, it would be really nice if there was a mechanism to scale it. [Scaling the backend](https://vaultproject.io/docs/concepts/ha.html)
might be a big part of this, but its not the whole picture and there are certain usecases (using vault to protect large 
amounts or a high throughput of data with the [Transit Secret Backend](https://vaultproject.io/docs/secrets/transit/index.html))
that probably can't be met with a single node.

All that being said, [Hashicorp](https://hashicorp.com/) has a great track record of building solid, well received
apps (such as [consul](https://consul.io/) and [vagrant](https://www.vagrantup.com/) featured in this demo) and
vault is still very young ([April 28th, 2015](https://hashicorp.com/blog/vault.html)) so I have high hopes
that this will be another win for safe, resilient, and simple infrastructure.


