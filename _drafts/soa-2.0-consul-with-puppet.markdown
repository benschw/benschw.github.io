---
layout: post
title: SOA 2.0 - Provisioning Consul with Puppet
categories:
tags: []
---

*Coming up*: A couple of posts about introducing Consul for _service discovery_ and Spring Boot for _microservices_ to an ecosystem that isn't quite ready for Docker. In this post, I'll cover provisioning (and wiring up) a consul cluster and a set of Spring Boot applications with Puppet. In the next post, I'll show you how to start using some of Spring Actuator and Codahale Metrics' goodness to stop caring so much about the _TLC_ that went into building up any particular VM.

<!--more-->

Sometimes I hate that I work for a company with a bunch of products in production, or else that we have a ton of new ideas in the pipeline. It would be preferable if we could start from scratch with what we know now, or if we could spend the next decade on a complete rewrite.

Alas we do have applications running on stogy old long-lived VMs which customers rely on and grand ideas for how to solve other problems these customers have.

Without dropping terms like "hybrid cloud" (oops,) I'm going to outline one approach for introducing some cloud flavor into an ecosystem with roots in long lived, thick, VMs. Without going "Full Docker," we can still start reducing our dependence on the more static way of doing things by introducing service discovery and targeted/granular/encapsulated services (sorry, I was trying to avoid the term "Microservice").

Since I'd rather show you an example than espouse a bunch of ideas (despite the diatribe you've been reading or ignoring thus far,) from here on out I'll be limiting my discussion to: _using Puppet to build out a stack of Spring Boot microservices which utilize Consul for service discovery._

## Get your feet wet

Before we get started, this whole example is available [on Github in the form of a Vagrant Stack](https://github.com/benschw/consul-cluster-puppet). Just follow the instructions in the README (or keep reading) and you'll have a production-ish set of VirtualBox VMs doing their thing: three Consul server nodes clustered up, a UI to track your Consul cluster state, a Spring Boot demo application, and a pair of Spring Boot back-end services (named "foo") for the demo app to discover and utilize.

<a href="/images/consul-puppet.png"><img src="/images/consul-puppet.png" alt="Consul Stack" width="750" height="306" class="alignnone size-full wp-image-107" /></a>

### Get your stack running:

	git clone https://github.com/benschw/consul-cluster-puppet.git
	cd consul-cluster-puppet
	./deps.sh
	./build.sh
	vagrant up

### Try out the endpoints:

- [Consul Status Web UI](http://172.20.20.13:8500/ui/#/dc1/services)
- [Demo App](http://172.20.20.20:8080/demo)
	- ["Foo" instance 1](http://172.20.20.21:8080/foo)
	- ["Foo" instance 2](http://172.20.20.22:8080/foo)

_p.s. The IPs are specified in the Vagrantfile, so these links will take you to your stack_

_p.p.s. If you want to play around with Consul some more, take a look at [this post](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/); a similar example where I focus more on what's provided by Consul._

## Getting your Puppet on

So what are we actually doing? We're doing as little as possible and trying to factor out any mutability into Hiera configs. There are existing puppet modules that can do the heavy lifting for us, and there are limited distinctions we require between different services and nodes that can be enumerated as properties rather than unique puppet code.

### Modules
All that we have to do is compose other people's work into a stack. 

- [solarkennedy/puppet-consul](https://github.com/solarkennedy/puppet-consul) - provisions our Consul cluster and the Consul client agents registering/servicing our applications.
- [puppet-dnsmasq](https://github.com/rlex/puppet-dnsmasq) - wires the consul client agent (which doubles as a DNS server for our discoverable services) into our applications. I.e. If our app looks something up that ends in ".consul" it routes through localhost:8600 (the consul agent.)

### Hiera

We use a Hiera config to specify an address to reach the Consul server cluster by and to give a name to each application booting into our stack.

_(You have to find consul somehow - whether you're a server seeking to join the cluster, or a client trying to register or find a service. In the real world we would treat these cases differently and incorporate a load balancer or at least a reverse proxy. But let's just call this our single point of failure and designate a reliable IP address. So we dump `172.20.20.10` as the consul server node everyone joins to in `common.yaml`. Since saying "single point of failure" makes me uncomfortable, let me note here that we could replace this IP with a hostname and blurt out "Excercise for the reader!".)_

In addition to `common.yaml` is a config for each node that specifies a "svc\_name" identifying each service we are provisioning. There is one "demo" instance and two "foo" instances. This name is caught by the _consul service define_ and used to identify the application when registering with consul.


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






