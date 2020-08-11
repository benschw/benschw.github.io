---
layout: post
status: publish
published: true
title: Dependency Injection, Duck Typing, and Clean Code in Go
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

Along the path to learning to program in [golang](http://golang.org/), one thing that took some getting used to for me was using [dependency injection](http://en.wikipedia.org/wiki/Dependency_injection) and [duck typing](http://en.wikipedia.org/wiki/Duck_typing) effectively. In this post I'll attempt to show how these concepts can be used to create clean and testable code.

Below I'll walk you through refactoring a simple cli application by utilizing di (dependency injection) and duck typing to make it cleaner and more testable. After that, I'll lay out a (only slightly) less trivial example and show how di and duck typing can help you to maintain and test a microservice in go.

<!--more-->

## Discover, a cli app

`discover` is a cli application that uses [Consul](https://consul.io/) (take a look [here](http://txt.fliglio.com/2014/05/encapsulated-services-with-consul-and-confd/) for a post of mine on writing applications with service discovery using Consul) to discover an address for the service of your choosing.

Usage Example (where I have a service named "my-service" registered with consul):

	$ discover -service-name my-service
	$ http://192.168.0.100:8080


To illustrate the power of di and duck typing for managing composition in your application, I'm going to take `discover` and refactor it by layering in di and then duck typing. Along the way, I'll show you why each refactor makes the code better.

### Gotta start somewhere...

Below is the "first iteration" of the `discover` app. It's fully functional, but as you'll see there are some problems. 

([full example src](https://github.com/benschw/di-duck-types-clean-code-ex/tree/master/default))

main.go
{% highlight go %}
func main() {
	dnsServer := flag.String("dns", "127.0.1.1:53", "dns server address")
	svcName := flag.String("service-name", "", "consul service name")
	flag.Parse()

	dnsParts := strings.Split(*dnsServer, ":")
	lb := clb.NewClb(dnsParts[0], dnsParts[1], clb.Random)

	address, _ := lb.GetAddress(*svcName + ".service.consul")

	fmt.Printf("http://%s:%d", address.Address, address.Port)
}
{% endhighlight %}

This is a pretty simple application. We're letting the [`clb` package](https://github.com/benschw/dns-clb-go) (client side load balancer) do all the work, so that all we have to do is supply a DNS server to use and a SRV record name to look up.

To test this however, we've got some problems. This is a pretty simple example, and maybe we could get away with not writing automated tests for it, but even with something trivial like this we'd probably get bitten by that decision eventually.

So to test it, we need to: 

- run a consul server
- register a service with it
- build `discover`
- run discover to look up the fixture service we registered
- compare the output with what we registered before

Since I'm a little obsessive, I went ahead and did just that:

test.sh
{% highlight bash %}
#!/bin/bash
...
echo '{"service": {"name": "test", "port": 8080}}' \
	> ./build/consul.d/test.json

./build/consul agent -server -bind 0.0.0.0 -bootstrap-expect 1 \
	-data-dir ./build/consul-data -config-dir ./build/consul.d > /dev/null &

CONSUL_PID=$!
sleep 5
...

EXPECTED=http://$IP:8080
FOUND=`./build/discover -dns localhost:8600 -service-name test`

kill $CONSUL_PID

# now test the output
...
{% endhighlight %}

_the full test can be found [here](https://github.com/benschw/di-duck-types-clean-code-ex/blob/master/default/test.sh)_

This is time consuming, brittle, and will only run on a Linux box. So what can we do to improve it?

### Injecting our dependencies

The first thing we'll want to address is that we can't use `go test` to test the application. In the example above, everything is rolled up into a single abstraction so we don't have any options other than testing the compiled artifact.

By separating the construction of our load balancer library from where we use it, we making testing this in go possible (although still not ideal.)

([full example src](https://github.com/benschw/di-duck-types-clean-code-ex/tree/master/di))

main.go
{% highlight go %}
func Discover(lb clb.LoadBalancer, addr string) string {
	address, _ := lb.GetAddress(addr + ".service.consul")

	return fmt.Sprintf("http://%s:%d", address.Address, address.Port)
}

func main() {
	dnsServer := flag.String("dns", "127.0.1.1:53", "dns server address")
	svcName := flag.String("service-name", "", "consul service name")
	flag.Parse()

	dnsParts := strings.Split(*dnsServer, ":")
	lb := clb.NewClb(dnsParts[0], dnsParts[1], clb.Random)

	fmt.Print(Discover(lb, *svcName))
}
{% endhighlight %}

discover_test.go
{% highlight go %}
func TestDiscover(t *testing.T) {
	//given
	expected := fmt.Sprintf("http://%s:8080", rando.MyIp())
	lb := clb.NewClb("localhost", "8600", clb.Random)

	// when
	found := Discover(lb, "test")

	// then
	if found != expected {
		t.Errorf("%s not equal to %s", found, expected)
	}
}
{% endhighlight %}


But... we still need to be running consul for this to work, so we still need our `test.sh` wrapper to orchestrate running our test. 

test.sh
{% highlight bash %}
...
./build/consul agent -server -bind 0.0.0.0 -bootstrap-expect 1 \
	-data-dir ./build/consul-data -config-dir ./build/consul.d > /dev/null &

CONSUL_PID=$!
sleep 5

go test

kill $CONSUL_PID
{% endhighlight %}
_the full test can be found [here](https://github.com/benschw/di-duck-types-clean-code-ex/blob/master/di/test.sh)_



### Making our DI more useful with Duck Typing

Sure it's great that we don't have to test our app through the cli anymore, but we really need to do something about those consul and wrapping bash script dependencies. Luckily, we aren't in the business of testing consul or even the load balancer library, so we can just mock it in our tests.

Thats where duck typing comes in. If we want to use a mock implementation of the load balancer, we can't have our `Discover` function depend on it. If the load balancer implemented an interface, we could use that in place of the structure name for our type hint, but it doesn't so we can't.

Luckily, in go (and other [structural type systems](http://en.wikipedia.org/wiki/Structural_type_system)) you can "implement an interface" without declaring that you are doing so simply by having a signature which matches the interface. It is this mechanism that makes it possible to have type safe duck typing in golang.

What we do is describe the signature of the function we are using from the load balancer library in an interface and start using our locally defined interface as our type hint.

([full example src](https://github.com/benschw/di-duck-types-clean-code-ex/tree/master/duck))

main.go
{% highlight go %}
type AddressGetter interface {
	GetAddress(string) (dns.Address, error)
}

func Discover(lb AddressGetter, addr string) string {
	address, _ := lb.GetAddress(addr + ".service.consul")

	return fmt.Sprintf("http://%s:%d", address.Address, address.Port)
}

func main() {
	dnsServer := flag.String("dns", "127.0.1.1:53", "dns server address")
	svcName := flag.String("service-name", "", "consul service name")
	flag.Parse()

	dnsParts := strings.Split(*dnsServer, ":")
	lb := clb.NewClb(dnsParts[0], dnsParts[1], clb.Random)

	fmt.Print(Discover(lb, *svcName))
}
{% endhighlight %}


Now in our test, we can build a `StaticAddressGetter` that also implements the `AddressGetter` interface, and supply it to the `Discover` function so that we can test the behavior of `Discover` without needing a real DNS server.

discover_test.go
{% highlight go %}
type StaticAddressGetter struct {
	Val dns.Address
}

func (lb *StaticAddressGetter) GetAddress(address string) (dns.Address, error) {
	if address == "test.service.consul" {
		return lb.Val, nil
	}
	return dns.Address{}, fmt.Errorf("invalid service name")
}

func TestDiscover(t *testing.T) {
	//given
	expected := "http://foo:8080"
	lb := &StaticAddressGetter{Val: dns.Address{Address: "foo", Port: 8080}}

	// when
	found := Discover(lb, "test")

	// then
	if found != expected {
		t.Errorf("%s not equal to %s", found, expected)
	}
}
{% endhighlight %}

So now we can get (virtually) the same level of test without custom bash scripting or a running instance of consul. A pleasant side effect (or arguably more important effect) of declaring the parts of a dependency you are leveraging in an interface, is you better contain you dependence on it. By writing to this application's interface instead of the `clb` package as a whole, we have a better idea of how we are coupled to it. This makes code reuse (even our own code) much easier to maintain.


## Greeting, a discoverable web-service

Below is code for a "Greeting" microservice (a json http app that returns "Hello World" when you issue a `GET` request on `/greeting`) that can be discovered using consul. I've applied the techniques outlined above and written a test for it.

Included with the server code is a client library both to aid in testing (see my post on [testing microservices in go](http://txt.fliglio.com/2014/12/testing-microservices-in-go/)) and to provide an abstraction which another service could import and use to integrate with the `Greeting` service.


([full example src](https://github.com/benschw/di-duck-types-clean-code-ex/tree/master/greeting))

All we do in our main function, is parse the cli flag (where to bind our http server), construct our http server, and call `RunServer` with the server injected.

main.go
{% highlight go %}
func main() {
	bind := flag.String("bind", "0.0.0.0:8080", "address to bind http server to")
	flag.Parse()

	server := ophttp.NewServer(*bind)

	RunServer(server)
}
{% endhighlight %}

In our server code, we bind our `GreetingHandler` function to the path `/greeting` and start up the web server. The handler will set the response to be "Hello World" (or actually "\"Hello World\"" since it's json encoded) and the status code to be 200.

server.go
{% highlight go %}
// Resource Handler for `/greeting`
func GreetingHandler(resp http.ResponseWriter, req *http.Request) {
	rest.SetOKResponse(resp, "hello world")
}

// Wire and start http server
func RunServer(server *ophttp.Server) {
	http.Handle("/greeting", http.HandlerFunc(GreetingHandler))
	server.Start()
}
{% endhighlight %}

In the client code, you might notice that our `AddressGetter` interface has cropped back up. Since we want services using our client to use consul to discover where our `Greeting` service is running, we are leveraging the same client side load balancer library seen above in our client. This way consumers of our service can get a new client with the `NewGreetingClient()` factory and be ready to go: The client knows how to find the service's address and how to communicate with its api.

client.go
{% highlight go %}
const ServiceAddress = "greeting.service.consul"

// Interface for Load Balancer
type AddressGetter interface {
	GetAddress(string) (dns.Address, error)
}

// Client Factory
func NewGreetingClient() *GreetingClient {
	return &GreetingClient{
		Lb:      clb.NewClb("localhost", "53", clb.Random),
		Address: ServiceAddress,
	}
}

// Client
type GreetingClient struct {
	Lb      AddressGetter
	Address string
}

func (c *GreetingClient) GetGreeting() ([]byte, error) {
	host, _ := c.Lb.GetAddress(c.Address)
	r, _ := rest.MakeRequest("GET", fmt.Sprintf("http://%s/greeting", host), nil)
	return rest.ProcessResponseBytes(r, http.StatusOK)
}
{% endhighlight %}

Because we used the `AddressGetter` interface as our client's type requirement, we can now implement a static `GreetingAddressGetter` for our component tests (I'm using the definition of component test outlined in my previous post, [testing microservices in go](http://txt.fliglio.com/2014/12/testing-microservices-in-go/)). 

This way, we can run the service directly inside out test on a known ip and port, and test it using our client configured to use that same ip and port.

server_test.go
{% highlight go %}
type GreetingAddressGetter struct {
	Val dns.Address
}

func (lb *GreetingAddressGetter) GetAddress(address string) (dns.Address, error) {
	if address == ServiceAddress {
		return lb.Val, nil
	}
	return dns.Address{}, fmt.Errorf("invalid service name")
}

func TestGreetingEndpoint(t *testing.T) {
	// given
	expectedGreeting := "\"hello world\""

	address := dns.Address{Address: "localhost", Port: uint16(rando.Port())}

	server := ophttp.NewServer(fmt.Sprintf("%s:%d", address.Address, address.Port))
	go RunServer(server)

	client := GreetingClient{
		Lb:      &GreetingAddressGetter{Val: address},
		Address: ServiceAddress,
	}

	// when
	greeting, _ := client.GetGreeting()

	// then
	if expectedGreeting != string(greeting[:]) {
		t.Errorf("expected '%s', got '%s'", expectedGreeting, greeting)
	}

	// teardown
	server.Stop()
}
{% endhighlight %}

_note that the `ophttp.NewServer` is thin wrapper for `http.ListenAndServe` that allows the server to be explicitly stopped_


## tldr

Coming from a background primarily in Java and PHP, I've always avoided duck typing. Though you can do it with both of these languages, you have to use reflection and handle runtime errors to make sure your signatures line up. It is more appropriate in those cases to refactor your dependency or when that's not an option, start sub-classing.

In go, inheritance isn't an option. Luckily, the language provides powerful tools for managing composition so that you won't miss it.

Hopefully that all made sense and was maybe even useful!
