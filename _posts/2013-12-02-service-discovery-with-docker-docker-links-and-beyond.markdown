---
layout: post
status: publish
published: true
title: ! 'Service Discovery with Docker: Docker links and beyond'
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
wordpress_id: 261
wordpress_url: http://txt.fliglio.com/?p=261
date: 2013-12-02 16:59:16.000000000 -06:00
---

To get a feel for wiring up an environment with Docker containers, I looked into a couple of options for service discovery - <a href="http://docs.docker.io/en/latest/use/working_with_links_names/" target="_blank">Docker Names and Links</a>, and <a href="https://github.com/coreos/etcd" target="_blank">Etcd</a> - and put together a couple of prototypes. In this article, I will talk a little about what service discovery is, how Docker containers fit in, and how (a couple) different techniques for wiring together your containers stack up.
<h2>What is service discovery?</h2>
Service Discovery is an umbrella term for the many aspects of managing the knowledge of where your application's services can be found and how they should communicate. Some of these aspects are:
<ul>
	<li>Providing a way for your application's services to locate and communicate with each other.</li>
	<li>Providing a way for your application's services to come and go (e.g. when new versions are deployed), without disrupting the system as a whole.</li>
	<li>Providing a way for your application's services to know which other services are actually (not just expected to be) available.</li>
	<li>When there is more than one instance of a particular service, providing a way for clients of that service to decide which to use.</li>
	<li>Providing a way for an end user to locate and communicate with your application.</li>
	<li>Providing a way to keep the details of how your environment is wired and distributed decoupled from your application.</li>
</ul>
<h2>Vis-à-vis Docker</h2>
A few characteristics of Docker containers make some aspects of service discovery especially important.
<ul>
	<li>Docker containers are designed to be portable across environments. For this reason, decoupling the knowledge of your services' communication details from your application (and putting it in the care of the environment itself) is especially necessary with Docker.</li>
	<li>A container doesn't really know anything about its host machine, so it doesn't know what IP or port through which it is exposed to the outside world. If you are content with one host, this doesn't matter because the containers can all see each other just fine. If, however you want more than one physical machine to facilitate a highly available application, you must manage the location of your service outside of the container which contains it.</li>
	<li>Containers are ephemeral. This means that when you need to release an update to your software, you are going to release a new container (with a new IP and port) and not just update your software in place.</li>
</ul>
<h2>Trying things out</h2>
To put <a href="http://docs.docker.io/en/latest/use/working_with_links_names/" target="_blank">Docker links</a> and <a href="https://github.com/coreos/etcd" target="_blank">Etcd</a> to the test, I created a simple set of services that need to be located for communication in three different ways:
<ol>
	<li>An end user with a browser needs to navigate to a Java app running inside a container.</li>
	<li>The Java app running inside a container needs to talk to another Java app running in a different container.</li>
	<li>The second Java app needs to talk to a Memcached service running in its own container.</li>
</ol>
<a href="/images/svc-discovery-poc2.png"><img class="alignnone size-full wp-image-264" alt="svc-discovery-poc2" src="/images/svc-discovery-poc2.png" width="736" height="137" /></a>

To keep the implementation of these scenarios simple, I've written a single Java app with two resources to simulate two services. By running the app in two separate containers, we can treat them as separate applications. For each, I expose my application to the end user using <a href="https://github.com/dotcloud/hipache" target="_blank">Hipache</a>.
<h3>Docker Names and Links</h3>
Jump over to the <a href="http://docs.docker.io/en/latest/use/working_with_links_names/" target="_blank">Docker Docs</a> if you'd like to hear more about names and links, or jump in and try out my prototype.

Get the <a href="https://github.com/benschw/docker-service-discovery-with-links" target="_blank">poc on GitHub</a>.
{% highlight bash %}
git clone https://github.com/benschw/docker-service-discovery-with-links.git{% endhighlight %}
To run the test, add a name to your `/etc/hosts` file
{% highlight bash %}
127.0.0.1 client.local{% endhighlight %}
Build the project
{% highlight bash %}
cd docker-service-discovery-with-links
./gradlew shadow{% endhighlight %}
Build the container image
{% highlight bash %}
sudo docker build -t app .{% endhighlight %}
Deploy the test environment
{% highlight bash %}
sudo ./run.sh{% endhighlight %}
Now we can exercise the test environment from end to end by navigating your browser to "http://client.local/demo." (Click refresh a few times to see the list of random numbers grow.)

Below is an outline of the flow of control, but it might be easier to just take a peak at <a href="https://github.com/benschw/docker-service-discovery-with-links/blob/master/src/main/java/com/benschw/example/resources/ExampleResource.java" target="_blank">the resources being used</a> (fyi, the Java service is implemented using <a href="http://dropwizard.codahale.com/" target="_blank">DropWizard</a>.)
<ul>
	<li>The host client.local is routed to port 80 on your local machine.</li>
	<li>Our Hipache container is listening to port 80, so it gets your traffic.</li>
	<li>Hipache proxies the request to the instance of our Java app serving the "client role" and ends up getting handled by the "/demo" resource.</li>
	<li>The "/demo" resource finds the instance of our Java app serving the "service role" in its environment variables (where we put them by linking the containers.)</li>
	<li>It uses this address to `POST` a random number to the "/entry" resource found in the "service role" container.</li>
	<li>The "/entry" resource in the "service role" container handles the request, and uses its own link to the memcached container to locate that service.</li>
	<li>After appending the random number to a list stored in the memcached container, the full list of random numbers is returned first to the client container, and finally to the browser.</li>
</ul>
If you take a look at <a href="https://github.com/benschw/docker-service-discovery-with-links/blob/master/run.sh" target="_blank">run.sh</a>, you can see the mechanics of how the containers are all run, linked together, and how the client container is added to Hipache.
<h3>Using Etcd to Discover Docker Containers</h3>
Using links for discovery leaves a couple things to be desired. First of all, links only work on one host and only expose private IPs and ports, so if you want to make your application HA, you'll need something else. Second, the address info is only good for as long as your linked container is around, so if you want to release an update, you have to restart all containers that rely on the update - not just the container being updated.

My Etcd prototype works much the same as my links prototype. Before you judge me too harshly (or worse, start thinking about using any of this code in a real environment :) ), remember this is just a prototype- no part of it (including the components published to the Docker Index) is fit for developing against. 

Give it a go, and don't forget to stop the previous setup if you haven't already:
{% highlight bash %}
sudo docker ps | xargs sudo docker stop{% endhighlight %}
Make sure you still have the name (`127.0.0.1 client.local`) in your `/etc/hosts` file, and...
{% highlight bash %}
git clone https://github.com/benschw/docker-service-discovery-with-etcd.git
cd docker-service-discovery-with-links
./gradlew shadow
sudo docker build -t app .
sudo ./run.sh{% endhighlight %}
and finally, the demo address ("http://client.local/demo") is the same here.

There are a few differences you'll notice if you take a peak at <a href="https://github.com/benschw/docker-service-discovery-with-etcd/blob/master/run.sh" target="_blank">run.sh</a>. First of all you'll notice a few new containers:
<ul>
	<li><strong>benschw/etcd</strong> is the Etcd service: a key value store to which we will publish all of our containers' addresses.</li>
	<li><strong>benschw/etcdedge</strong> runs a python script which keeps Hipache's config synchronized with etcd (so we can write once to etcd and expect our proxy to also get configured.)</li>
	<li><strong>benschw/etcdbridge</strong> publishes my application addresses to etcd. One instance is run for each application container, and it is in charge of keeping its container's address registered in etcd until it fails a health check or disappears.</li>
</ul>
(A complete explanation of <a href="https://github.com/benschw/etcdedge" target="_blank">etcdedge</a> and <a href="https://github.com/benschw/etcdbridge" target="_blank">etcdbridge</a> is out of scope for this article, but take a look at the source if you're interested.)

A second difference is that there are two instances of both the "client" and "service" containers. Despite the fact that this is a single host example, this is an attempt to show how having multiple copies on different hardware could interact in this example environment.

A final difference is that since the Etcd store is decoupled from the running of the application containers, we can stop and start individual components of the system without the cascading restart requirement necessitated by using Docker links for discovery.
<h2>Sorry this took so long</h2>
Despite a desire to go into this deeper and relay more of my thoughts on service discovery with Docker, I find it hard to imagine that anybody is left reading so I'm just going to wrap it up.

The best TLDR I can supply is the prototype source itself (remember, all the orchestration is in "run.sh")

<ul>
<li><a href="https://github.com/benschw/docker-service-discovery-with-links" target="_blank">Discovery with Docker Links poc</a></li>
<li><a href="https://github.com/benschw/docker-service-discovery-with-etcd" target="_blank">Discovery with Etcd poc</a></li>
</ul>

And the additional components used in the Etcd prototype:

<ul>
<li><a href="https://github.com/benschw/etcdbridge" target="_blank">etcdbridge</a></li>
<li><a href="https://github.com/benschw/etcdedge" target="_blank">etcdedge</a></li>
</ul>
