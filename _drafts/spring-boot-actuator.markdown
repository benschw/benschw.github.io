---
layout: post
title: Spring Boot, Actuator, and Codahale Metrics
categories:
tags: []
---

_AKA: How to know when stuff's fracked and how to do something about it._

In my previous post, [Provisioning Consul with Puppet](/2014/10/consul-with-puppet/), I covered a first step towards ephemeral nirvana for your stack. In this post I'll talk a little about how the [Spring Boot](http://projects.spring.io/spring-boot/) framework (and especially [Actuator](http://spring.io/guides/gs/actuator-service/)) can help move you towards this goal... and how [Codahale Metrics](https://github.com/dropwizard/metrics) can help out even more. Additionally, I'll walk you through using [spotify's "dns-java" lib](https://github.com/spotify/dns-java) to leverage the [consul](http://www.consul.io/) DNS server for service discovery.

<!--more-->

You can read [my justification for writing these posts](/2014/10/consul-with-puppet/) in part 1; here I'm going to jump right into the example.

## Getting Started

I'm using the same [Vagrant stack and demo app hosted on Github](https://github.com/benschw/consul-cluster-puppet) so go get your copy now.

The Stack consists of:

- three Consul server nodes clustered up
- a UI to track your Consul cluster state
- a Spring Boot demo application
- a pair of Spring Boot back-end services (named "foo") for the demo app to discover and utilize.

<a href="/images/consul-puppet.png"><img src="/images/consul-puppet.png" alt="Consul Stack" width="750" height="306" class="alignnone size-full wp-image-107" /></a>

### Running your stack:

	git clone https://github.com/benschw/consul-cluster-puppet.git
	cd consul-cluster-puppet
	./deps.sh # clone some puppet modules we'll be using
	./build.sh # build the Spring Boot demo application we'll need
	vagrant up

Same steps as before (same example as before...) but I'll point out a couple things this time.

- [demo](https://github.com/benschw/consul-cluster-puppet/tree/master/demo) is the java app src root
	- `build.sh` just runs "./gradlew" on this source root to build our app into a jar
- I'm using [spotify's "dns-java" lib](https://github.com/spotify/dns-java) to read SRV records. At the time of writing this, functionality I needed for metrics integration only existed in master, so I've included a build in "/demo/spotify/." They're building in [some additional goodness](https://github.com/spotify/dns-java/issues/5) before cutting a new release.

### The endpoints:

The IPs are specified in the Vagrantfile, so these links will take you to _your_ stack

- [Consul Status Web UI](http://172.20.20.13:8500/ui/#/dc1/services)
- [Demo App](http://172.20.20.20:8080/demo)
	- ["Foo" instance 1](http://172.20.20.21:8080/foo)
	- ["Foo" instance 2](http://172.20.20.22:8080/foo)

## Integration

Feeling déjà vu? Good, you read [the last post.](/2014/10/consul-with-puppet/) But I promise that's all over; now I'll talk you through:

- Leveraging consul to discover services
- Producing metrics and health monitoring for your Spring Boot app

### Consul Integration
I've included a sample ["LoadBalancer" implementation](https://github.com/benschw/consul-cluster-puppet/tree/master/demo/src/main/java/com/github/benschw/springboot/srvloadbalancer) in the demo to abstract out working with SRV records so that you can get the address of a service as follows:
	
	LoadBalancingStrategy strategy = new RoundRobinLoadBalancingStrategy();

	DnsSrvResolver resolver = DnsSrvResolvers.newBuilder()
			.cachingLookups(true)
			.retainingDataOnFailures(true)
			.metered(new CodahaleSpringBootReporter(metricsRegistry))
			.dnsLookupTimeoutMillis(1000)
			.build();

	loadBalancer = new LoadBalancer(strategy, resolver);

	HostAndPort node = loadBalancer.getAddress("foo");

	String address = LoadBalancer.AddressString("http", node) +  "/foo";

    RestTemplate restTemplate = new RestTemplate();
    Foo foo = restTemplate.getForObject(address, Foo.class);

(See the `demo` app using it to look up `foo` [here](https://github.com/benschw/consul-cluster-puppet/blob/master/demo/src/main/java/com/github/benschw/consuldemo/resources/DemoController.java))

#### Example Output
The output of [http://172.20.20.20:8080/demo](http://172.20.20.20:8080/demo):

	{
		fooResponse: {
			message: "Hello from foo1"
		},
		selectedAddress: {
			port: 8080,
			hostText: "foo1.node.dc1.consul."
		}
	}

- `fooResponse` shows the output from the `foo` service, which reports back its hostname
- `selectedAddress` shows what the consul LoadBalancer gave us back when we asked for an address

Our demo app uses the LoadBalancer library to look up the `SRV` addresses from the Consul DNS server (supplied by the local consul agent.) It then selects one based on our strategy (round robin by default.) Finally it forms the address (`A` record plus port) to complete its request (this address is also resolved through the Consul DNS server.)

### Health
Spring boot exposes a "Health" endpoint that allows us to query our service to see if it is running and healthy. By default this runs along side our app on the same port, but for our demo [we've routed it to port 8081](https://github.com/benschw/consul-cluster-puppet/blob/master/demo/src/main/resources/application.properties) (to keep the admin functions separate and support keeping these endpoints private in the future if we wish.)

One last piece: consul checks health by executing a script and looking at the return value, so I've included [health.py](https://github.com/benschw/consul-cluster-puppet/blob/master/demo/health.py) to parse our health endpoint JSON into a return code.

#### Example
Typically, everything just works. So if we hit the health endpoint ([http://172.20.20.20:8081/health](http://172.20.20.20:8081/health)) all we see is "UP"

	{
		status: "UP"
	}

If the app goes down, this page obviously won't be here any more, but additionally we can register specific checks that can be tripped even if the app doesn't crash (e.g. the node ran out of disk space or we can't connect to the database.)

	@Component
	public class FooServiceHealthyIndicator extends AbstractHealthIndicator {

    	@Autowired
		private LoadBalancer loadBalancer;

		@Override
		protected void doHealthCheck(Health.Builder builder) throws Exception {
			HostAndPort node = loadBalancer.getAddress("foo");

			if (node != null) {
				builder.up();
			} else {
				builder.down();
			}
		}
	}

Sometimes we want to know about a problem but don't necessarily want to take the application out of load balance. For example, If `demo` needs `foo` in order to function fully, but it can still run in a degraded state without it, we wouldn't want all instances of demo to go away if Consul is reporting that no `foo`s are available. In this case we could instead "warn" that something isn't right, but leave the demo service available for discovery:

To modify the above class, just replace `builder.down()` with `builder.status("WARN")`.

This is the way we have it implemented in the demo we're running, so if we shut down both `foo` services (`vagrant halt foo0 foo1`) we'll see the following from our `demo` health endpoint:

	{
		status: "WARN"
	}

Notice that our copy of demo is only in a warn state (not critical), so if something tries to resolve it through consul, it will still be available.

### Metrics
Wiring Codahale metrics into Spring boot isn't a big deal with the help of [ryantenney/metrics-spring](https://github.com/ryantenney/metrics-spring). My implementation for this example is nestled in [its own package](https://github.com/benschw/consul-cluster-puppet/tree/master/demo/src/main/java/com/github/benschw/springboot/metrics) and wired up in our application [config](https://github.com/benschw/consul-cluster-puppet/blob/master/demo/src/main/java/com/github/benschw/consuldemo/ApplicationConfiguration.java).

This allows for the use of the `@timed` annotation on resource methods to time all endpoints by name.

It also allows us to explicitly tap into the MetricRegistry:

	lookups = metrics.timer(MetricRegistry.name(CodahaleSpringBootReporter.class, "srvlookup"));

	Timer.Context context = lookups.time();
	// do stuff
	context.stop();

#### Example Output

	{
		demo.meter.mean.DemoController.demo: 0.004174263352818219,
		demo.meter.one-minute.DemoController.demo: 0.029097939451186338,
		demo.meter.five-minute.DemoController.demo: 0.009890715011966878,
		demo.meter.fifteen-minute.DemoController.demo: 0.0051311229462762085,
		demo.timer.min.DemoController.demo: 2930355,
		demo.timer.max.DemoController.demo: 214477268,
		demo.timer.median.DemoController.demo: 9271362,
		demo.timer.mean.DemoController.demo: 39808608.875,
		demo.timer.standard-deviation.DemoController.demo: 72246286.59474245,
		demo.meter.mean.CodahaleSpringBootReporter.srvlookup: 0.2003580661363458,
		demo.meter.one-minute.CodahaleSpringBootReporter.srvlookup: 0.23859104066267098,
		demo.meter.five-minute.CodahaleSpringBootReporter.srvlookup: 0.2090802942145022,
		demo.meter.fifteen-minute.CodahaleSpringBootReporter.srvlookup: 0.17895849086506815,
		demo.timer.min.CodahaleSpringBootReporter.srvlookup: 1604057,
		demo.timer.max.CodahaleSpringBootReporter.srvlookup: 125254192,
		demo.timer.median.CodahaleSpringBootReporter.srvlookup: 2939579,
		demo.timer.mean.CodahaleSpringBootReporter.srvlookup: 3894239.9505208335,
		demo.timer.standard-deviation.CodahaleSpringBootReporter.srvlookup: 6640297.013684536,
		demo.gauge.gauge.response.**.favicon.ico: 9,
		demo.gauge.gauge.response.demo: 33,
		demo.counter.CodahaleSpringBootReporter.srvlookupempty: 320,
		demo.counter.CodahaleSpringBootReporter.srvlookupfailures: 2,
		demo.counter.counter.status.200.**.favicon.ico: 1,
		demo.counter.counter.status.200.demo: 8,
		demo.counter.counter.status.304.**.favicon.ico: 2
	}

Oh Yeah! I forgot to mention that we are [timing our SRV address lookups](https://github.com/benschw/consul-cluster-puppet/blob/master/demo/src/main/java/com/github/benschw/springboot/srvloadbalancer/CodahaleSpringBootReporter.java). There are also counters for lookup failures and occurrences of empty result sets (successful query, but no available services to connect to.)

All this, timers on all the resource endoints, and counters on every status code served up.

## Next steps
So you've got Consul running and now you can make use of it (also see [Service Discovery for Golang with DNS](http://txt.fliglio.com/2014/05/client-side-loadbalancing-with-consul/) for my writeup on using Consul in Go).

A glaring omission of this post is how to actually do anything with your health and metrics data. Consul will operate on your health checks, but how can you incorporate this feedback with other things... like low memory and disk space, nodes reaching cpu capacity, or whatever has traditionally been a pain in your ass? Additionally, we haven't really talked about how to capture or aggregate all those metrics we're providing now.

we've run out of time... but here are some ideas...

- [Sensu](http://sensuapp.org/)
	- has a slew of community plugins for tracking the health of common components
	- uses Nagios style checks just like Consul, so you can monitor your health endpoint with this too
	- can serve as a metrics collector, passing on the data to something else (like graphite)
- [Statsd](https://github.com/etsy/statsd/) collect your metrics with this, optionally with [codahale integration](https://github.com/jjagged/metrics-statsd/)
- [Graphite](http://graphite.wikidot.com/) graph and expose your metrics once you have them
- [Graphene](http://jondot.github.io/graphene/) integrate with graphite and protect your eyes from unnecessary bleeding.