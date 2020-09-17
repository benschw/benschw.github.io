---
layout: post
status: publish
published: true
title: NSQ and Golang Messaging Primer
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
date: 2020-09-15 08:32:26.000000000 -05:00
categories:
- Post
tags: []
---

In this post, we'll look at how you can use [NSQ](https://nsq.io/) in your [golang](https://golang.org/)
applications to start leveraging messaging. Messaging offers the easiest way to build an async architecture,
for which there are a number of benefits ranging from scalability to the reduction of cascading errors.
In this post however, we will be focusing on how messaging can be used to decouple components in your software
by looking at a couple of common patterns for doing so (work queues & pub/sub).

<!--more-->


[NSQ](https://nsq.io/) is a realtime, distributed, horizontally scalable messaging platform.
Also, it's written in Go and is distributed as two simple binaries (plus an optional admin web app
and a collection of utility tools) so it is easy to install and keep up to date (no dependencies.)
There are a slew of both official & community supported [client libraries](https://nsq.io/clients/client_libraries.html),
and we will be using the officially supported [go](https://github.com/nsqio/go-nsq) one.


This post is divided up into four sections:

* First we'll get NSQ running in a local cluster using [Docker Compose](https://docs.docker.com/compose/).
* Next we'll build a couple of simple Go apps to publish to and consume from NSQ
* Third we will look at how to scale the consumption of our messages using the Worker pattern
* Finally we will update our example to implement the Pub/Sub pattern

_Follow along here, or clone the [demo repo](https://github.com/benschw/nsq-demo) if you prefer_

## Running NSQ

The NSQ design is dirt simple (definitely one of its strongest characteristics) both
to get running and to use. The recommended install layout is to run an instance of `nsqd`
alongside each service that is producing messages and to run a handfull (3-5 even
for very large installations) of `nsqlookupd` instances for message consumers to
discover the appropriate `nsqd` node with. To get everything talking to each other,
`nsqd` needs to be configured to register with each instance of `nsqlookupd`
using the `--lookupd-tcp-address` flag.

One thing to note here: the `nsqlookupd` instances do not discover each other.
This means that each `nsqd` instance will need to register with all `nsqlookupd` instances
and if you need to replace an `nsqlookupd` instance and it gets a new address,
you will need to restart each `nsqd` instance with updated configuration.

<img src="/images/nsq-infra.png" />

_Example install: publishers publish to an instance of nsqd installed along side them & 
consumers leverage nsqlookupd to find the appropriate instance to consume from._


### Enough! let's get it running

First, create a docker-compose config named 
[docker-compose-nsq.yml](https://github.com/benschw/nsq-demo/blob/master/docker-compose-nsq.yml)
with the following content:

docker-compose-nsq.yml
{% highlight yaml %}
version: '3'
services:

  nsqlookupd:
    image: nsqio/nsq
    hostname: nsqlookupd
    ports:
      - "4160:4160"
      - "4161:4161"
    command: /nsqlookupd

  nsqd:
    image: nsqio/nsq
    hostname: nsqd
    ports:
      - "4150:4150"
      - "4151:4151"
    command: /nsqd -broadcast-address=nsqd --lookupd-tcp-address=nsqlookupd:4160

  nsqadmin:
    image: nsqio/nsq
    hostname: nsqadmin
    ports:
      - "4171:4171"
    command: /nsqadmin --lookupd-http-address=nsqlookupd:4161

{% endhighlight %}


And that's it! Now you can start the NSQ cluster:

	docker-compose -f docker-compose-nsq.yml up

If you want, you can navigate to the admin web app in your browser [http://localhost:4171/](http://localhost:4171/)
to poke around and confirm everything is connected right.

### So what's going on in that docker-compose config?

The first thing you might notice is all three containers leverage the same
`nsqio/nsq` docker image. Conveniently, the folks at NSQ have packaged all the NSQ apps
and utilities into one image so it's easy to keep track of things: just target the appropriate
app in your command.

Let's look at each service and see how it's joining the cluster:

#### nsqlookupd

`nsqlookupd` is the most straight forward because it's our discovery mechanism,
so it just needs to run at a known address. We run the app with no
args and expose the ports it's listening on: 4160 for low level TCP communication
with clients & 4161 for its REST api over http.

The `nsqd` nodes of the cluster communicate over the low level tcp port
to coordinate their membership in the cluster and the consumer app we will
create later will connect with the REST api to discover the rest of the cluster.

#### nsqd

`nsqd` also has a port open for low level TCP communication (4150) and one for
its REST api over http (4151). It additionally offers an option to listen to https traffic
on port 4152, but we aren't going into that here.

The `nsqd` service has to join the cluster to be useful. We can accomplish this with the
flag `--lookupd-tcp-address=nsqlookupd:4160` which configures a lookupd address
for `nsqd` to join the cluster through (this flag should be used multiple
times if you have multiple lookupd instances.)
In addition to joining, `nsqd` needs to declare how it can be reached and does so with
the flag `-broadcast-address=nsqd` (which defaults to hostname which in our case happens to be what we want,
but I included it anyway to be explicit)

_docker-compose sets up networking so that containers can be reached
via their hostname so we can use the container's hostname as its address and it will
resolve appropriately._

#### nsqadmin

`nsqadmin` isn't a part of the cluster's function, but still needs to discover it so
that the details can be inspected and exposed. We can configure that connection with our
lookupd's http address using the `--lookupd-http-address=nsqlookupd:4161` flag.

In addition, it needs to expose the http port that the web server is running on (4171)
so we can navigate to it in a web browser.


_see all the flags and options on NSQ's [documentation page](https://nsq.io/overview/design.html)_


## Sending & Receiving Messages

As for actually using NSQ, all you need to understand are *topics* and *channels*.
Each `nsqd` instance can have multiple *topics*, and each *topic* can have
one or more *channels*. Messages are published to a *topic* and each *channel* for that
*topic* receives a copy of the message. Messages can then be received by subscribing to
a channel. In other words, message producers publish messages to a *topic*
and message consumers consumer messages from a *channel* on a *topic*. You don't even
need to create these *topics* and *channels* as separate steps: they are established
when they are first published or subscribed to.

<img src="/images/nsq-message-flow.gif" />

_How messages are routed (shamelessly stolen from the [NSQ docs page](https://nsq.io/overview/design.html))_

### Producer

Lets start by sending some messages.


_Again, follow along here or clone the [demo repo](https://github.com/benschw/nsq-demo) off Github_

producer.go
{% highlight go %}
package main

import (
	"flag"
	"log"
	"os"

	"github.com/nsqio/go-nsq"
)

var (
	addr    = flag.String("addr", "localhost:4150", "NSQ lookupd addr")
	topic   = flag.String("topic", "", "NSQ topic")
	message = flag.String("message", "", "Message body")
)

func main() {

	// parse the cli options
	flag.Parse()
	if *topic == "" || *message == "" {
		flag.PrintDefaults()
		os.Exit(1)
	}

	// configure a new Producer
	config := nsq.NewConfig()
	producer, err := nsq.NewProducer(*addr, config)
	if err != nil {
		log.Fatal(err)
	}

	// publish a nessage to the producer
	err = producer.Publish(*topic, []byte(*message))
	if err != nil {
		log.Fatalf("Could not connect to %s", *addr)
	}

	// disconnect
	producer.Stop()
}
{% endhighlight %}

And send a message (even though nobody's listening yet)

	$ go run cmd/producer/producer.go -topic test -message "hello world"
	2020/09/17 09:35:43 INF    1 (localhost:4150) connecting to nsqd
	2020/09/17 09:35:43 INF    1 stopping
	2020/09/17 09:35:43 INF    1 (localhost:4150) beginning close
	2020/09/17 09:35:43 INF    1 (localhost:4150) readLoop exiting
	2020/09/17 09:35:43 INF    1 (localhost:4150) breaking out of writeLoop
	2020/09/17 09:35:43 INF    1 (localhost:4150) writeLoop exiting
	2020/09/17 09:35:43 INF    1 exiting router


### Consumer

OK! Now let's consume that message we just published to the "test" topic.

consumer.go
{% highlight go %}
package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/nsqio/go-nsq"
)

var (
	addr    = flag.String("addr", "localhost:4161", "NSQ lookupd addr")
	topic   = flag.String("topic", "", "NSQ topic")
	channel = flag.String("channel", "", "NSQ channel")
)

// MyHandler handles NSQ messages from the channel being subscribed to
type MyHandler struct {
}

func (h *MyHandler) HandleMessage(message *nsq.Message) error {
	log.Printf("Got a message: %s", string(message.Body))
	return nil
}

func main() {

	// parse the cli options
	flag.Parse()
	if *topic == "" || *channel == "" {
		flag.PrintDefaults()
		os.Exit(1)
	}

	// configure a new Consumer
	config := nsq.NewConfig()
	consumer, err := nsq.NewConsumer(*topic, *channel, config)
	if err != nil {
		log.Fatal(err)
	}

	// register our message handler with the consumer
	consumer.AddHandler(&MyHandler{})

	// connect to NSQ and start receiving messages
	//err = consumer.ConnectToNSQD("nsqd:4150")
	err = consumer.ConnectToNSQLookupd(*addr)
	if err != nil {
		log.Fatal(err)
		log.Fatalf("Could not connect to nsqlookupd %s", *addr)
	}

	// wait for signal to exit
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	<-sigChan

	// disconnect
	consumer.Stop()
}
{% endhighlight %}

We just ran the `producer` on our host machine, but since we set up our `nsqd` daemon
to broadcast on its `docker-compose` managed hostname, let's run the consumer with
`docker-compose` as well to make finding it easier.

First, build a docker image:
	
	docker build -t nsq-consumer -f Dockerfile-consumer .

And now create a docker-compose config

docker-compose-consumer.yml
{% highlight yaml %}
version: '3'
services:
  consumer:
    image: nsq-consumer
    command: /app/consumer -topic test -channel foo
{% endhighlight %}


	$ docker-compose -f docker-compose-consumer.yml up
	Starting nsq-demo_consumer_1 ... done
	Attaching to nsq-demo_consumer_1
	consumer_1  | 2020/09/17 14:44:49 INF    1 [test/foo] querying nsqlookupd http://nsqlookupd:4161/lookup?topic=test
	consumer_1  | 2020/09/17 14:44:49 INF    1 [test/foo] (nsqd:4150) connecting to nsqd
	consumer_1  | 2020/09/17 14:44:49 Got a message: hello world

Success! Publish a few more messages and our consumer should receive those too.


Let's walk through what happened:

* In our publisher, we published a message to the topic `test` which created the topic
  on the `nsqd` instance we have running and added the message to it
* When we started our consumer, it performed a lookup using `nsqlookupd` to find the
  instance of `nsqd` that had the topic we were looking for (`test`). This isn't particularly useful
  with only one instance of course, but pretend...
	* In the `consumer.go` code, you can see the commented out line that would have connected directly to
	  to the `nsqd` server without the intermediate `nsqlookupd` lookup. This would have been fine in our
	  simple example, but fails to illustrate how it would work in a distributed system.
* Having found the topic, the consumer created a channel named `foo` which will now receive
  a copy of every message sent to the `test` topic.
* Finally, we were delivered the message we sent earlier.


## Worker Pattern

## Pub/Sub Pattern
