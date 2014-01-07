---
layout: post
status: publish
published: true
title: Orchestrating docker with Go
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
wordpress_id: 302
wordpress_url: http://txt.fliglio.com/?p=302
date: 2013-12-18 06:22:05.000000000 -06:00
categories:
- Uncategorized
tags: []
comments: []
---
<h2>dockit</h2>

<p>I hacked together an app named <a href="https://github.com/benschw/dockit" target="_blank">dockit</a> using <a href="http://golang.org/" target="_blank">Go</a> in order to manage a simple environment; one with webapps and a reverse proxy to route traffic to them.</p>
<p>This is not supposed to be a general-purpose tool, but rather an example of how wiring up Docker environments using Go is...</p>

<ul>
<li>Testable: a testing framework is built in</li>
<li>Easy to read: idiomatic style that is almost universally followed, making for a terse, highly readable ecosystem</li>
<li>Easy to maintain: I'm assuming you were doing this work in bash before</li>
<li>Portable: really, we're only talking about Linux with Docker, so a single statically linked binary is as portable as you can get</li>
</ul>

<p>So get some ideas here (or use this as a starting point) and go build your own toolkit to codify (no pun intended) the conventions, opinions, and nuances of your environment in a format that you can maintain and test.</p>

<p>All of this info is repeated on the project page, so if you want to dive right in, <a href="https://github.com/benschw/dockit" target="_blank">go there now.</a>

<h3>Usage</h3>

<p>By default, <em>dockit</em> looks for a config.json file in your current directory, connects using unix:///var/run/docker.sock, and keeps track of running containers with "pid" files in /var/run/dockit-containers.</p>

<p>You can define services for your environment in the config file, and specify ports, environment variables, and dependency services (which are translated into links.)</p>

<h4>Example Environment</h4>

<p>Included in this repo, is an example config to build an environment with a webapp (the included <a href="https://github.com/benschw/dockit/tree/master/webapp-ex" target="_blank">webapp-ex/</a>) fronted by a reverse proxy (<a href="https://github.com/dotcloud/hipache" target="_blank">Hipache</a>.)</p>

<p>The config specifies:</p>

<ul>
<li>the webapp ("WebApp" service) container should link in the hipache/redis ("Hipache" service) container</li>
<li>which ports to expose (in the link and externally)</li>
<li>an environment variable for the webapp to use as a host name when registering with Hipache</li>
</ul>

<p>The webapp entry point script (<a href="https://github.com/benschw/dockit/blob/master/webapp-ex/start.sh" target="_blank">webapp-ex/start.sh</a>) uses the link and host env var to register the webapp with Hipache and to deregister on shutdown.</p>

<p>Here is a copy of `config.json` from our example environment:</p>

{% highlight json %}
{"Hipache" : {
    "Image" : "stackbrew/hipache",
    "Ports" : {
        "80" : "80",
        "6379" : ""
    }
}, "WebApp" : {
    "Image" : "benschw/go-webapp",
    "Deps" : [
        "Hipache"
    ],
    "Env" : {
        "HOST" : "webapp.local"
    }
}}{% endhighlight %}

<p>(the image <em>benschw/go-webapp</em> was built from the contents of the <a href="https://github.com/benschw/dockit/tree/master/webapp-ex" target="_blank">webapp-ex directory</a>)</p>

<h4>Run the example</h4>
<p>Pull the example containers:</p>

{% highlight bash %}
sudo docker pull stackbrew/hipache
sudo docker pull benschw/go-webapp
{% endhighlight %}
<p>Start the Services:</p>
{% highlight bash %}
sudo ./dockit -service Hipache -start
sudo ./dockit -service WebApp -start{% endhighlight %}

<p>This will start up the <em>Hipache</em> service and then the <em>WebApp</em> service, and it will register the private ip:port of  the <em>WebApp</em> container with Hipache (see <a href="https://github.com/benschw/dockit/blob/master/webapp-ex/start.sh" target="_blank">webapp-ex/start.sh</a>) under the name <em>webapp.local</em>.</p>

<p>add "127.0.0.1  webapp.local" to your "/etc/hosts" file, and the example webapp should be available at <a href="http://webapp.local" target="_blank">http://webapp.local</a></p>


<h4>Stop the example</h4>

{% highlight bash %}
sudo ./dockit -service WebApp -stop{% endhighlight %}

<p>This will only stop the <em>WebApp</em> container (and deregister from Hipache); Hipache is still running. To stop it too, run:</p>

{% highlight bash %}
sudo ./dockit -service Hipache -stop{% endhighlight %}

<p>Note the containers are still there in a "stopped" state, and a subsequent <em>-start</em> will run new instances.</p>


<h2>Thoughts</h2>

<p>I can't stress enough that dockit is not supposed to be a useful app, but rather something to get you thinking about how you can add testability and maintainability to your environment (and maybe to help you figure out how to make use of <a href="https://github.com/fsouza/go-dockerclient" target="_blank">fsouza's Go client for Docker</a>.)</p> 

<p>Hopefully it can help you add some stability to your environment's wiring.</p>

<h2>Final Thoughts</h2>

<p>If (like me) this is your first foray into Go, here's <a href="https://gist.github.com/benschw/7873555" target="_blank">a gist</a> to help you build the examples.</p>
