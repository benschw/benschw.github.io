---
layout: post
status: publish
published: true
title: Creating a MySQL Docker Container
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
wordpress_id: 222
wordpress_url: http://txt.fliglio.com/?p=222
date: 2013-11-10 00:31:25.000000000 -06:00
categories:
- Post
tags: []
---


On the surface, creating a MySQL container for Docker is pretty easy, but if you want to connect in (not sure what a mysql server that didn't allow that would be good for) and decouple your databases from your container (I'm assuming you don't want those to go away with your container) then there are a few problems to sort out.

I'm going to start with that simplistic example (with ephemeral database storage and no way to connect) and build on the example until we have something useful. Still not production ready, but good enough for hacking ;)

<!--more-->

Oh, and you can jump to the <a href="https://gist.github.com/benschw/7391723" target="_blank">gist</a> (which has the files for building the container as well as some scripts to build and run it) if things get too boring or convoluted.

<h2>Getting Started</h2>

create the `Dockerfile`:

{% highlight bash %}
FROM ubuntu

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get -y install mysql-server

EXPOSE 3306

CMD ["/usr/bin/mysqld_safe"]
{% endhighlight %}


then build and tag it:

{% highlight bash %}
docker build -t mysql .
{% endhighlight %}

Now we have a fully functioning container that we can run like so:

{% highlight bash %}
docker run -d -p 3306:3306 mysql
{% endhighlight %}

This would work, but it wouldn't be very useful.
<ul>
  <li>mysql is listening on 127.0.0.1 so we can only connect from inside the container</li>
  <li>we only have a root user, and the root user is only allowed to log in from inside the container</li>
  <li>since our data is getting written inside the container, if we lose the container or need to change something about it (like apply a security update), we lose our data.</li>
</ul>
 
<h3>Updating bind-address</h3>
First step is to make our mysql server listen to more than localhost so that we can connect from outside of our container.

To do this, we need to update the bind-address in `/etc/mysql/my.cnf` from `127.0.0.1` to `0.0.0.0` (have mysqld bind to every available network instead of just localhost.)

We could just start maintaining the `/etc/mysql/my.cnf` file and add it to our container with our Dockerfile: 

{% highlight bash %}
ADD ./my.cnf /etc/mysql/my.cnf
{% endhighlight %}

Or we could update that one property. I prefer this way so that I know that I am getting the most up to date config from my install, and just updating what I need to. We can add the appropriate `sed` command to our Dockerfile after we've installed mysql-server.

{% highlight bash %}
RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
{% endhighlight %}

(Technically we could just delete the line for the same effect, but this is more explicit.)

Even though mysqld is listening everywhere now, we still can't log in because the root user only has access from localhost.

<h3>Admin user</h3>
We need to add an admin account to administer things from outside of the container. In order to add an account, we need our mysql server to be running. Since separate lines in a Dockerfile create different commits, and commits only retain filesystem state (not memory state), we need to cram both commands into one commit:
    
{% highlight bash %}
RUN /usr/sbin/mysqld & \
    sleep 10s &&\
    echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'changeme' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql
    
EXPOSE 3306
    
CMD ["/usr/bin/mysqld_safe"]
{% endhighlight %}

Let's build and run it!

{% highlight bash %}
docker build -t mysql .
docker run -d -p 3306:3306 mysql
{% endhighlight %}

And now to try connecting. In order to do this, we need to figure out the container's ip, and to find that, we need our container's id. This is easy enough to do by hand with `docker ps` and `docker inspect`, but you could also script it:
   

{% highlight bash %}
CONTAINER_ID=$(docker ps | grep mysql | awk '{print $1}')
IP=$(docker inspect $CONTAINER_ID | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["NetworkSettings"]["IPAddress"]')
mysql -u admin -p -h $IP
{% endhighlight %}

Now we have a fully functional mysql container! That's great and all, but we're putting a lot of trust into this container by relying on it to keep track of our databases, not to mention we're screwed if we ever want to upgrade or update anything.


<h3>Persisting data</h3>
We need to remove our reliance on this specific container and to do this we need to externalize our data directory. This is easy, but causes problems. When running our container, we just throw in a `-v /host/path:/container/path` and the supplied directory on our host machine is used in the container wherever we specify.

So to persist databases from our container in `/data/mysql` on our host machine, we update our run command to be:

{% highlight bash %}
docker run -d -p 3306:3306 -v /data/mysql:/var/lib/mysql mysql
{% endhighlight %}

The problem is, we just nuked our system tables when we replaced `/var/lib/mysql` with our empty directory. This also means we lost our admin user. This is tricky to account for because we can't initialize the directory (or add our admin user) until the data directory is visible to the container (at run time) but we don't want to initialize the directory every time we start up either. The whole point of externalizing the data directory is so that the container can come and go without loss of data.

To solve this, let's create a `startup.sh` script to replace simply invoking `/usr/bin/mysqld_safe`.

First, let's write our `startup.sh` script to do the initialization only if our data directory isn't already populated.

{% highlight bash %}
#/bin/bash

if [ ! -f /var/lib/mysql/ibdata1 ]; then
    mysql_install_db
fi

/usr/bin/mysqld_safe
{% endhighlight %}

This will look for the file "ibdata1" in our data dir as a cheap way to determine if we need to initialize the directory or not. After the data directory has been initialized (or determined already initialized) we can continue on to start up the server.

And now we will update the Dockerfile to add `startup.sh` to the container and to call it instead of `mysqld_safe`:

{% highlight bash %}
ADD ./startup.sh /opt/startup.sh
CMD ["/bin/bash", "/opt/startup.sh"]
{% endhighlight %}

We can also add in our admin user with the `startup.sh` script:

{% highlight bash %}
#/bin/bash

if [ ! -f /var/lib/mysql/ibdata1 ]; then
	mysql_install_db

	/usr/bin/mysqld_safe &
	sleep 10s

	echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'changeme' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql

	killall mysqld
	sleep 10s
fi

/usr/bin/mysqld_safe
{% endhighlight %}

And of course we should also remove the `RUN` line from the Dockerfile that was doing the same thing but getting undone as soon as we externalized the data directory.


<h2>Put it all together</h2>
Don't want to follow all the incremental directions to get your files right? Here's the finished product (plus some helper scripts to build, run your server, and connect with the cli client.)

These files are also available as a <a href="https://gist.github.com/benschw/7391723" target="_blank">gist</a>.

<h4> Dockerfile</h4>

{% highlight bash %}
FROM ubuntu

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get -y install mysql-client mysql-server

RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

ADD ./startup.sh /opt/startup.sh

EXPOSE 3306

CMD ["/bin/bash", "/opt/startup.sh"]
{% endhighlight %}

<h4>startup.sh</h4>

{% highlight bash %}
#/bin/bash

if [ ! -f /var/lib/mysql/ibdata1 ]; then

	mysql_install_db

	/usr/bin/mysqld_safe &
	sleep 10s

	echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'changeme' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql

	killall mysqld
	sleep 10s
fi

/usr/bin/mysqld_safe
{% endhighlight %}

<h3>and some helpful scripts to do all our tasks</h3>

<h4>build.sh</h4>
{% highlight bash %}
#!/bin/sh

docker build -t mysql .
{% endhighlight %}

<h4>run-server.sh</h4>
{% highlight bash %}
#!/bin/sh

docker run -d -p 3306:3306 -v /data/mysql:/var/lib/mysql mysql
{% endhighlight %}

<h4>run-client.sh</h4>
{% highlight bash %}
#!/bin/sh

TAG="mysql"

CONTAINER_ID=$(docker ps | grep $TAG | awk '{print $1}')

IP=$(docker inspect $CONTAINER_ID | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["NetworkSettings"]["IPAddress"]')

mysql -u admin -p -h $IP
{% endhighlight %}
