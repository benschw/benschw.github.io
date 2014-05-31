---
layout: post
title: Service Discovery for Golang with Consul
---

In [a blog post](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/) from a couple weeks ago, I walked through a demo illustrating the power of using [Confd](https://github.com/kelseyhightower/confd) and DNS to keep your applications decoupled from the specifics of [Consul](http://www.consul.io/) when implementing service discovery and configuration management for your applications.

In this post I am going to introduce [dns-clb-go](https://github.com/benschw/dns-clb-go), a library I wrote to manage DNS based service discovery (like what is provided by [Consul](http://www.consul.io/) and [SkyDNS](https://github.com/skynetservices/skydns)) in a Go application. It is essentially a naive load balancer with a focus on supporting high availability and extensibility.

<!--more-->


# Service Discovery with DNS

DNS SRV records are a great mechanism for sharing service location in a dynamic way, but you still need something to interpret them. [dns-clb-go](https://github.com/benschw/dns-clb-go) is a library written in Go which does just that.

Service discovery solutions like [Consul](http://www.consul.io/) and [SkyDNS](https://github.com/skynetservices/skydns) can expose the location of services via SRV records so that your application only needs to speak "DNS" and not understand a custom REST API. This allows for your integration to be with a well understood and well documented protocol, and for your integration to be more portable than if you were to implement service discovery with an opinionated API like [Eureka](https://github.com/Netflix/eureka) or [Etcd](https://github.com/coreos/etcd).

## SRV Records

So what are SRV records? Here's an example from a consul cluster hosting a service named "my-svc."

	$ dig @127.0.0.1 -p 8600 my-svc.service.consul SRV
	...

	;; ANSWER SECTION:
	my-svc.service.consul.	0	IN	SRV	1 1 8076 service2.node.dc1.consul.
	my-svc.service.consul.	0	IN	SRV	1 1 8045 service1.node.dc1.consul.

	;; ADDITIONAL SECTION:
	service2.node.dc1.consul. 0	IN	A	172.20.20.14
	service1.node.dc1.consul. 0	IN	A	172.20.20.13

	...

As you can see, the DNS server (running in the consul agent here) responds to my lookup for the "my-svc" service with all available instance of the service known to the cluster (two in this case.) These SRV records show the port each instance is running on (8076 & 8045) as well as an A record to resolve them with. You can then drill down on those A records to get an IP.


## dns-clb-go

`dns-clb-go` will resolve a name for you and give back a valid ip and port. It is designed such that both the DNS lookup and the address selection are pluggable, facilitating different caching and load balancing strategies to be employed.

Out of the box, there are two examples of each implemented, but the real power is in the flexibility the library has, which allows you to easily customize how your resolve SRV records for the specific needs of your applications.

### Load Balancing
- _Random:_ randomly select an address from the pool of available SRV records
- _Round Robin:_ Cycle through the pool of available SRV records

To implement your own load balancer, you need to satisfy this interface:

	type LoadBalancer interface {
		GetAddress(name string) (dns.Address, error)
	}

(where and address is...)

	type Address struct {
		Address string
		Port    uint16
	}

### Caching
- _None:_ Don't cache; perform the DNS lookup each time
- _TTL:_ Cache all lookups for up to _N_ seconds. This will only perform the lookup when needed, but the value will be reused for up to the number of seconds specified by _ttl_.

To implement your own caching strategy, you need to satisfy this interface:

	type Lookup interface {
		LookupSRV(name string) ([]net.SRV, error)
		LookupA(name string) (string, error)
	}

### Putting it all together

The package [github.com/benschw/dns-clb-go/clb](http://godoc.org/github.com/benschw/dns-clb-go/clb) provides factory functions to easily construct your library and get going. 

Querying for "my-svc" from the consul example above. No caching is used, and load balancing is done in round robin:

	c := NewClb("127.0.0.1", "8600", RoundRobin)
	address, err := c.GetAddress("my-svc.service.consul")
	if err != nil {
	    fmt.Print(err)
	}
	fmt.Printf("%s", address.String()) // 172.20.20.14:8076

## Feedback
<a href="http://www.reddit.com/r/todayilearned/comments/1zv60v/til_of_cunninghams_law_the_best_way_to_get_the/" target="_blank" ><img src="/images/cunninghams-law.png" alt="Cunningham's Law" /></a>

While researching my [previous post](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/), I was amazed to find that there didn't seem to be any well established patterns or solutions for working with SRV records. Since I'm still fairly certain that this is due to my poor use of _Google_, I'm going to imploy [Cunningham's Law](http://meta.wikimedia.org/wiki/Cunningham's_Law) to get some answers. If this isn't the case, and the people working with SRV records really are keeping their solutions to themselves, then maybe this library can be of some use to people.

If this is useful to anyone, let me know. If I'm off-base, let me know. In the interest of putting more information out there, I'd like to make available any resources or experiences people have found/had online to improve this library and more importantly, make this problem easier to solve.

Comment below, or just shoot me an email: [benschw@gmail.com](mailto:benschw@gmail.com)