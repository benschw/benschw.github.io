---
layout: post
title: Service Discovery for Golang with Consul
---

In [a blog post](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/) from a couple weeks ago, I walked through a demo illustrating the power of using [Confd](https://github.com/kelseyhightower/confd) and DNS to keep your applications decoupled from the specifics of [Consul](http://www.consul.io/) when implementing service discovery and configuration management for your applications.

In this post I am going to introduce [the library](https://github.com/benschw/dns-clb-go) I wrote to manage DNS based service discovery (like what is provided by [Consul](http://www.consul.io/) and [SkyDNS](https://github.com/skynetservices/skydns)) in a Go application. It is essentially a naive load balancer with a focus on supporting high availability and extensibility.

<!--more-->

<a href="http://www.reddit.com/r/todayilearned/comments/1zv60v/til_of_cunninghams_law_the_best_way_to_get_the/" target="_blank" ><img src="/images/cunninghams-law.png" alt="Cunningham's Law" /></a>

When researching my [previous post](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/), I was amazed to find that there didn't seem to be any well established patterns or solutions for working with SRV records. Since I'm still fairly certain that this is due to my poor use of _Google_, I'm going to imploy [Cunningham's Law](http://meta.wikimedia.org/wiki/Cunningham's_Law) to get some answers. If this isn't the case, and the people working with SRV records really are keeping their solutions to themselves, then maybe this library can be of some use to people.

Hopefully that disclaimer will protect me from ridicule and public humiliation.

# dns-clb-go

Without further excuses, here it is: [dns-clb-go](https://github.com/benschw/dns-clb-go).

.