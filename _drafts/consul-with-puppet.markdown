---
layout: post
title: Provisioning Consul with Puppet
categories:
tags: []
---

*Coming up*: A couple of posts about incorporating [Consul](http://www.consul.io/) for _service discovery_ and [Spring Boot](http://projects.spring.io/spring-boot/) for _microservices_ in an ecosystem that isn't quite ready for [Docker](https://www.docker.com/). In this post, I'll cover provisioning (and wiring up) a consul cluster and a set of [Spring Boot](http://projects.spring.io/spring-boot/) applications with [Puppet](http://puppetlabs.com/). In [the next post](/2014/10/spring-boot-actuator/), I'll show you how to start using some of [Spring Actuator](http://spring.io/guides/gs/actuator-service/) and [Codahale Metrics](https://github.com/dropwizard/metrics)' goodness to stop caring so much about the _TLC_ that went into building up any particular VM.

<!--more-->

Sometimes I hate that I work for a company with a bunch of products in production, or else that we have a ton of new ideas in the pipeline. It would be preferable if we could start from scratch with what we know now, or if we could spend the next decade on a complete rewrite.

Alas we do have applications running on stogy old long-lived VMs which customers rely on and grand ideas for how to solve other problems these customers have.

Without dropping terms like "hybrid cloud" (oops,) I'm going to outline one approach for introducing some cloud flavor into an ecosystem with roots in long lived, thick, VMs. Without going "Full Docker," we can still start reducing our dependence on the more static way of doing things by introducing service discovery and targeted/granular/encapsulated services (sorry, I was trying to avoid the term "[Microservice](http://martinfowler.com/articles/microservices.html)").

Since I'd rather show you an example than espouse a bunch of ideas (despite the diatribe you've been reading or ignoring thus far,) from here on out I'll be limiting my discussion to: _using Puppet to build out a stack of [Spring Boot](http://projects.spring.io/spring-boot/) microservices which utilize Consul for service discovery._

## Get your feet wet

Before we get started, this whole example is available [on Github in the form of a Vagrant Stack](https://github.com/benschw/consul-cluster-puppet). Just follow the instructions in the README (or keep reading) and you'll have a production-ish set of VirtualBox VMs doing their thing: three Consul server nodes clustered up, a UI to track your Consul cluster state, a Spring Boot demo application, and a pair of Spring Boot back-end services (named "foo") for the demo app to discover and utilize.

<a href="/images/consul-puppet.png"><img src="/images/consul-puppet.png" alt="Consul Stack" width="750" height="306" class="alignnone size-full wp-image-107" /></a>

### Get your stack running:

	git clone https://github.com/benschw/consul-cluster-puppet.git
	cd consul-cluster-puppet
	./deps.sh # clone some puppet modules we'll be using
	./build.sh # build the Spring Boot demo application we'll need
	vagrant up

### Try out the endpoints:

- [Consul Status Web UI](http://172.20.20.13:8500/ui/#/dc1/services)
- [Demo App](http://172.20.20.20:8080/demo)
	- ["Foo" instance 1](http://172.20.20.21:8080/foo)
	- ["Foo" instance 2](http://172.20.20.22:8080/foo)

_p.s. The IPs are specified in the Vagrantfile, so these links will take you to your stack_

_p.p.s. If you want to play around with Consul some more, take a look at [this post](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/); a similar example where I focus more on what's provided by Consul._

## Getting your Puppet on

So what are we actually doing? We're doing as little as possible and trying to factor out any mutability into Hiera configs. There are existing puppet modules that can do the heavy lifting for us, and there are limited distinctions we require between different services and nodes whichs can be enumerated as properties rather than unique puppet code.

### Modules
All that we have to do is compose other people's work into a stack. 

- [solarkennedy/puppet-consul](https://github.com/solarkennedy/puppet-consul) - provisions our Consul cluster and the Consul client agents registering/servicing our applications.
- [puppet-dnsmasq](https://github.com/rlex/puppet-dnsmasq) - routes consul DNS lookups to the consul agent (I.e. If our app looks something up that ends in ".consul" it routes through localhost:8600 -- the consul agent.)

### Hiera

In a [Hiera config](https://github.com/benschw/consul-cluster-puppet/tree/master/hiera), we can specify an address by which to reach the Consul server cluster and a name to label each application booting into our stack.

_(You have to find consul somehow - whether you're a server seeking to join the cluster, or a client trying to register or find a service. In the real world we would treat these cases differently and incorporate a load balancer or at least a reverse proxy; but let's just call this our single point of failure and move on. So we dump `172.20.20.10` as the consul server node everyone joins to in `common.yaml`._ 

_Ok, saying "single point of failure" makes me too uncomfortable and I can't just move on. Instead, imagine me muttering something about a hostname and then blurting out "Excercise for the reader!".)_

In addition to [common.yaml](https://github.com/benschw/consul-cluster-puppet/blob/master/hiera/common.yaml) is a config [for each node](https://github.com/benschw/consul-cluster-puppet/tree/master/hiera) that specifies a "svc\_name" identifying each service we are provisioning. There is one "demo" instance and two "foo" instances. This name is caught by the _consul service define_ and used to identify the application when registering with consul.


### Thus...

#### Consul Server

	class { 'consul': 
		# join_cluster => '172.20.20.10', # (provided by hiera)
		config_hash => {
			'datacenter' => 'dc1',
			'data_dir'   => '/opt/consul',
			'log_level'  => 'INFO',
			'node_name'  => $::hostname,
			'bind_addr'  => $::ipaddress_eth1,
			'bootstrap_expect' => 3,
			'server'     => true,
		}
	}

#### Consul Client

	class { 'consul':
		config_hash => {
			'datacenter' => 'dc1',
			'data_dir'   => '/opt/consul',
			'log_level'  => 'INFO',
			'node_name'  => $::hostname,
			'bind_addr'  => $::ipaddress_eth1,
			'server'     => false,
			'start_join' => [hiera('join_addr')], # (...hiera)
		}
	}

#### Consul Service Definition

	consul::service { $service_name: # (indirectly provided by hiera... look at app.pp)
		tags           => ['actuator'],
		port           => 8080,
		check_script   => $health_path,
		check_interval => '5s',
	}


#### Dnsmasq

	include dnsmasq
	
	dnsmasq::dnsserver { 'forward-zone-consul':
		domain => "consul",
		ip     => "127.0.0.1#8600",
	}


### Etc.

There's more to it then that, but including installing the demo jar and its init scripts for our example, it's pretty straight forward. Take a look at [the code](https://github.com/benschw/consul-cluster-puppet/tree/master/puppet).

The three files `app.pp`, `server.pp`, and `webui.pp` represent the three roles our various nodes fulfill. The consul server agents are all "servers", the consul web ui is a "webui," and all of our spring apps (both the demo and the foo services) are "apps." Since our goal was to make the redundant copies (extra foos and server agents) first class citizens, it makes sense that there is no differences in how we provision them.

## Moving On

Those VMs have served you well; they've been with you with you in sickness and in health... but also vise versa. At this point, most people agree that little is gained by anthropomorphizing your servers. But most people also still have enough invested in them that it's not totally intuitive how to move on.

Introducing service discovery and microservices to your stack is one approach. Services like Consul work well as a decoupled system to augment an existing stack. You can easily layer it on, start relying on it for new applications, but not have to invest time or money retrofitting your old software.

In my next post I'll be going over how the Spring Boot application framework fits into this _brave new world._ Don't let the Java name-drop fool you however, it's still a infrastructure post. I'll be covering _health checks_ and _metrics_, or ["How to know when stuff's fracked and how to do something about it."](/2014/10/spring-boot-actuator/)