---
layout: post
status: publish
published: true
title: Protyping web stuff with Docker
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
wordpress_id: 158
wordpress_url: http://txt.fliglio.com/?p=158
date: 2013-09-18 01:23:09.000000000 -05:00
categories:
- Post
tags: []
---

This is "post 1" in a series of tutorials designed to stand up an Amazon ec2 instance which will provide the automated hosting of applications using docker. This first post starts with some base line provisioning and ends with a manual walk through of what we will automate in later posts.

If asked to characterize Docker (I know, no one has), I'd say that it's a pattern/software that revolutionizes application and service deployment by reducing artifacts to a lowest common denominator, while at the same time making orchestration and discovery a pain in the ass. In this post (and others in the series if I get around to it) I'm going to attempt to play to docker's strengths while automating the "pain in the ass" parts, to create a platform which will make hosting prototypes dirt simple. Why prototypes and not production applications? Because (right now at least) I don't plan on addressing data persistence, scalability (beyond a single EC2 instance), or different environments like dev and uat. Don't get me wrong, docker (and Hipache, which I'll introduce later) is actually quite good at handling these concerns, but again... I don't plan on addressing them.

<!--more-->

<h2>Build a free Amazon EC2 instance for this tutorial</h2>

I find it painful to describe how to use a gui (and acknowledge this to be irrational), and I'm sure you can figure out how to use Amazon, but in the interest of completeness and not assuming anything, I'm going to burn through this real quick.

<ul>
<li>Launch a new EC2 instance</li>
<li>Choose the classic wizard</li>
<li>Select "ubuntu server 12.04 LTS 64bit, t1 micro"</li>
<li>Choose an existing key or create one</li>
<li>Set up security groups (we want ports 22 and 80 for this tutorial, but since its apparently impossible to change this later, go ahead and open up 5000, 8080, and 8081 too -- for subsequent installments to this series of posts)</li>
<li>launch</li>
<li>We also want to generate an elastic IP and associate it with our new instance so we can set up DNS; so do that</li>
</ul>

You can now shell into your vm with something like the following:

{% highlight bash %}
ssh -i ~/.ssh/aws-key-benschw.pem ubuntu@54.244.120.37
{% endhighlight %}

I like to create myself an account separate from the ubuntu one too (so I don't have to look up ssh's `-i` flag mostly). Just make sure to install your own ssh-key and add yourself to the sudoers group.

{% highlight bash %}
sudo su
adduser ben
usermod -G sudo ben
su ben
# paste your key into ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
{% endhighlight %}

<h2>Install docker</h2>

I can't improve upon Docker's own install docs, so I won't try. Follow their instructions (I copy pasted every line and hit "y" or "enter" a couple of times) from inside your EC2 instance.

<a href="http://docs.docker.io/en/latest/installation/ubuntulinux/" title="Docker install for Ubuntu" target="_blank">Docker install for Ubuntu</a>


<h2>test stuff out</h2>
Now lets install a copy of wordpress on port 80 just to confirm everything is right so far. Normally, we'd just let docker assign us a port, but for now lets ask for 80 since we've only punched a limited number of holes in our EC2 instance

{% highlight bash %}
sudo docker pull jbfink/wordpress
sudo docker run -d -p 80:80 jbfink/wordpress:latest
{% endhighlight %}

Navigate to your elastic IP and confirm the install screen comes up. Since it did, we're all good to go and now it's time to tear it down and reclaim our precious port 80.

{% highlight bash %}
sudo docker stop f26d90158382
{% endhighlight %}

If you forgot your id, `sudo docker ps -a` should give you what you're looking for.

(<a href="https://index.docker.io" target="_blank">https://index.docker.io</a> lists public containers if wordpress doesn't get your motor going...)

<h2>Hipache</h2>

Now it's time to address our port problem. Lets face it, keeping track of them is a big part of the "pain in the ass" thing, and they don't make for a very friendly user experience. If I was my dad (and if my dad was a sysadmin) I'd host everything on port 80 and assign ips to each docker container, but I'm not so I won't.

Enter <a href="https://github.com/dotcloud/docker/wiki/Public-docker-images#hipache" target="_blank">Hipache</a>.

Hipache is a distributed proxy designed to route high volumes of http and websocket traffic to unusually large numbers of... take a look at the <a href="https://github.com/dotcloud/hipache" target="_blank">readme</a> if you want a definition, but suffice it to say, it's distributed, scalable, and solves our port problem.

Since we're building a prototyping box, persistence isn't too important. In fact, to keep things simple, let me just warn you now, that restarting your host machine is going to nuke (most of) everything we're about to do. 

That said, lets pull down a Hipache container from the Docker index and get 'er running:


{% highlight bash %}
sudo docker pull samalba/hipache

sudo docker run -d -p 6379:6379 -p 80:80 samalba/hipache supervisord -n
# this spits out our Hipache container ID, in my case it's `e40c90158472`

sudo docker inspect e40c90158472 | grep Bridge | cut -d":" -f2 | cut -d'"' -f2
# probably better ways to parse JSON, but this will serve to get us our 
# bridge interface; in my case it's `docker0`

/sbin/ifconfig  docker0 | sed -n '2 p' | awk '{print $2}' | cut -d":" -f2
# more black magic to get our bridge's ip (which doubles as our redis 
# host): for me it's 172.17.42.1
{% endhighlight %}

Recap: Hipache is running and we know some stuff about it. Since we specified port 80 & 6379, we also know Hipache is running on port 80 and redis is running on port 6379. (By the way, redis is a database and provides configuration for Hipache.)

Now we need somehow to find our containers since we want Hipache to get rid of ports; DNS should do the trick. In the interest of progressing towards our prototyping platform, I'm going to set up a wildcard record that points to our host IP. For me, I used `*.io A 54.212.254.136` in my fliglio.com dns. (This way *.io.fliglio.com will point to my EC2 host machine.)

The last piece of prep work is to get a redis client installed on the host machine so we can configure Hipache.

{% highlight bash %}
sudo apt-get install redis-server
{% endhighlight %}

The downside of this, is we just installed the client and the server, and Ubuntu has started up a redis server on our host machine... go ahead and kill it: 

{% highlight bash %}
sudo /etc/init.d/redis-server stop
{% endhighlight %}

Thats all there is to it, we're ready to roll! ...or maybe you're thinking that was a lot of work and you're ready to go back to ips...

<h2>Lets host something</h2>

Back to the ol' wordpress standby. This time we aren't going to specify a port, but are instead going to let Docker assign it an obnoxious random one.

{% highlight bash %}
sudo docker run -d -p 80 jbfink/wordpress:latest
{% endhighlight %}

`sudo docker ps -a` will tell us the port mapping, or we can use the container id to find what got mapped to port 80.

{% highlight bash %}
sudo docker port d6077ac8b6e8 80
# 49154
{% endhighlight %}

The last step is to configure Hipache to route traffic sent to the domain we decided on (I'm using wp.io.fliglio.com) to the bridge ip our wordpress container is running on (the same as the one we figured out earlier for Hipache in this single host scenario) with the port docker is exposing the wordpress container's port 80 through (49154)

{% highlight bash %}
redis-cli -h 172.17.42.1 -p 6379 rpush frontend:wp.io.fliglio.com wpdemo
redis-cli -h 172.17.42.1 -p 6379 rpush frontend:wp.io.fliglio.com http://172.17.42.1:49154
{% endhighlight %}

Thats it! `wp.io.fliglio.com` should take you to a fresh wordpress installer that will generate even less traffic than this blog!

In Part 2, we'll dive into automating some of this and leveraging it as a sandbox for prototyping. Granted most blogs end up being ephemeral anyway (without the help of Docker or this tutorial), but maybe we can squeeze a little more than wordpress installer hosting out of this setup just the same.


<h2>Extra Credit</h2>

Spin up a second wordpress container, add a corresponding config entry to Hipache, and see how easy it is to get load balanced applications with Docker:

{% highlight bash %}
ID=$(sudo docker run -d -p 80 jbfink/wordpress:latest)
PORT=$(sudo docker port $ID 80)
redis-cli -h 172.17.42.1 -p 6379 rpush frontend:wp.io.fliglio.com http://172.17.42.1:$PORT
{% endhighlight %}
since i'm not providing a good way to test that that worked, just look at your config and trust me:

{% highlight bash %}
redis-cli -h 172.17.42.1 -p 6379 lrange frontend:wp.io.fliglio.com 0 -1
1) "wpdemo"
2) "http://172.17.42.1:49154"
3) "http://172.17.42.1:49156"
{% endhighlight %}
