---
layout: post
status: publish
published: true
title: Swiss Army Docker Container for PHP
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

This post is a tutorial for building your own Swiss Army Docker Container to support
local dev for PHP. The examples I'll give are intentionally opinionated, but hopefully
they'll be useful in portraying some concepts you can walk away with and apply to your
own local dev and test environment.


<!--more-->

_(For a full example of these ideas in use, see 
[Testing PHP Fliglio Microservices with Docker](/2015/12/testing-php-fliglio-microservices-with-docker/).)_

### What is a Swiss Army Docker Container?

What I'm hoping to show you, is how to build a container to support local dev only;
this is not even close to a production grade solution! The goal is to be able to
run your app locally for exploratory testing with live updates and automated testing.
Additionally, it will take care of automation tasks like database migrations and
facilitate testing strategies like allowing you to mock components.

## Getting Started

### The Dockerfile

Let's start with the `Dockerfile` (or [on github](https://github.com/fliglio/docker-local-dev)).


	FROM ubuntu:14.04

	# Ensure UTF-8
	RUN locale-gen en_US.UTF-8
	ENV LANG       en_US.UTF-8
	ENV LC_ALL     en_US.UTF-8


	ENV DEBIAN_FRONTEND noninteractive

	RUN apt-get update
	RUN apt-get install -y \
		php5-cli php5-fpm php5-mysql php5-pgsql php5-sqlite php5-curl \
		php5-gd php5-mcrypt php5-intl php5-imap php5-tidy php5-memcache
	RUN apt-get install -y \
		nginx \
		mysql-server mysql-client \
		supervisor


	RUN mkdir -p /var/log/supervisor
	RUN mkdir -p /var/www

	RUN echo "daemon off;" >> /etc/nginx/nginx.conf
	RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
	RUN sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
	 
	ADD nginx-site   /etc/nginx/sites-available/default

	# forward request and error logs to docker log collector
	RUN ln -sf /dev/stdout /var/log/nginx/access.log
	RUN ln -sf /dev/stdout /var/log/nginx/error.log


	RUN /usr/sbin/mysqld & \
		sleep 10s &&\
		echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'changeme' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql
	RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

	ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf

	ADD phinx.php /etc/phinx.php
	ADD migrate.sh /usr/local/bin/migrate.sh
	ADD run.sh /usr/local/bin/run.sh

	EXPOSE 80

	CMD ["/usr/local/bin/run.sh"]


There's a bunch happening there, but essentially I'm installing
[Nginx](https://www.nginx.com), [PHP](http://php.net/), and [MySQL](https://www.mysql.com/)
along with [Supervisord](http://supervisord.org/) to maintain running them all and a few
scripts to manage utility tasks.

So let's take a look at those utility scripts!

### run.sh

Run this to get `supervisord` to run all your services. By default it doesn't do
anything extra and nginx will serve your php app up from the default root: `/var/www/httpdocs`.
If you set the environment variable `DOC_ROOT` however, this script will take care of updating
your nginx config to apply that change.

{% highlight bash %}
#!/bin/bash

if test "$DOC_ROOT" != ""; then
	echo using doc-root: $DOC_ROOT
	sed -i "s+/var/www/httpdocs+$DOC_ROOT+" /etc/nginx/sites-available/default
fi

/usr/bin/supervisord
{% endhighlight %}

So now we can run it:

{% highlight bash %}
docker run -p 8080:80 -v `pwd`:/var/www/ --name local-dev fliglio/local-dev
{% endhighlight %}

Our current directory will get mounted to `/var/www/` inside the container and nginx
will serve up whatever's in `httpdocs` (we're assuming your project keeps it's index.php in a folder named "httpdocs").


### migrate.sh
I promised you database migrations before, and here they are! rather than try to accomplish this
inside our first container, we will run a second container and just link in the first container
so our script knows where to apply the migrations.

This script uses the mysql cli client to create our database (the name of which we
will pass in with an environment variable) and [Phinx](https://phinx.org/) to apply our migrations.
This script discovers the address of the mysql server through the environment variables
that are set by linking our local dev container to this one when we start it.

{% highlight bash %}
#!/bin/bash

DB_USER=admin
DB_PASS=changeme


MYSQL_IP=$LOCALDEV_PORT_3306_TCP_ADDR
MYSQL_PORT=3306


echo creating database $DB_NAME
mysql -h $MYSQL_IP -P $MYSQL_PORT -u admin -pchangeme -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"

DB_HOST=$MYSQL_IP DB_NAME=$DB_NAME DB_USER=$DB_USER DB_PASS=$DB_PASS DB_PORT=$MYSQL_PORT /usr/bin/php /var/www/vendor/bin/phinx migrate -c /etc/phinx.php -e dev
{% endhighlight %}

And we run our migrations (against the local dev container we talked about in the last section) with:

{% highlight bash %}
docker run -v `pwd`/:/var/www/ -e "DB_NAME=my_database_name" --link local-dev:localdev fliglio/local-dev /usr/local/bin/migrate.sh
{% endhighlight %}

This command will run a new container and apply the phinx migrations from ./db/migrations to your local-dev container.


### Mocking Components for test

Docker doesn't really help with mocking, but we can use it to specify how to configure
our service. So with some clever organization we can make it so that when we're running
automated tests our application is configured with mocks instead of real libraries.


For instance, lets say your `index.php` looks like this:


{% highlight php %}
<?php

$auth = new OAuth2();
$app = new Application($auth);

$app->run();

{% endhighlight %}


If we wanted to be able to test a resource in our app that requires a login, we would
have to mock the `OAuth2` library. What we can do is create an alternate `index.php` (and keep
it in e.g. `src/test/httpdocs`) that bootstraps our app exactly the same as the normal
`index.php`, but with a mocked oauth lib.


{% highlight php %}
<?php

$fac = new OAuth2MockFactory()
$auth = $fac->create()
$app = new Application($auth);

$app->run();

{% endhighlight %}
{% highlight php %}
<?php
class OAuth2MockFactory extends PHPUnit_Framework_TestCase {
	public function create() {
		$stub = $this->getMockBuilder('OAuth2')
			->disableOriginalConstructor()
			->getMock();
		
		$stub->method('isAuthorized')
			->will($this->returnCallback(function($user) {
				return true;
			}));
	
		return $stub;
	}
}
{% endhighlight %}


Now we can set the `DOC_ROOT` env var used in the `run.sh` script and run our
application with the auth lib mocked out.
	
	docker run -p 8080:80 -v `pwd`:/var/www/ -e "DOC_ROOT=/var/www/src/test/httpdocs/" --name local-dev fliglio/local-dev


### Docker & Make

To fully automate some of these strategies, you need a build tool.

You can use whatever build tools you like, but I like [make](https://www.gnu.org/software/make/).
It's close to straight bash scripting and simplifies maintaining all of the various
ways we've been running our container.

Take a look at the [Makefile](https://github.com/fliglio/rest-gs/blob/master/Makefile) used
by the service [rest-gs](https://github.com/fliglio/rest-gs) (More on this project in my previous posts:
[Microservices in PHP with Fliglio](/2015/12/microservices-in-php-with-fliglio/) and
[Testing PHP Fliglio Microservices with Docker](/2015/12/testing-php-fliglio-microservices-with-docker/))



{% highlight bash %}
NAME=rest-gs
DB_NAME=todo

LOCAL_DEV_PORT=8000
LOCAL_DEV_IMAGE=fliglio/local-dev

run:
	docker run -p $(LOCAL_DEV_PORT):80 -p 3306 -v $(CURDIR)/:/var/www/ --name $(NAME) $(LOCAL_DEV_IMAGE) 

migrate:
	docker run -v $(CURDIR)/:/var/www/ -e "DB_NAME=$(DB_NAME)" \
		--link $(NAME):localdev $(LOCAL_DEV_IMAGE) \
		/usr/local/bin/migrate.sh

test:
	@mkdir -p build/test/log
	@docker run -t -d -p 80 -p 3306 -v $(CURDIR)/:/var/www/ \
		-v $(CURDIR)/build/test/log/:/var/log/nginx/ \
		-e "DOC_ROOT=/var/www/src/test/httpdocs/" \
		--name $(NAME)-test $(LOCAL_DEV_IMAGE)
	@echo "Bootstrapping component tests..."
	@sleep 3
	docker run -v $(CURDIR)/:/var/www/ \
		-e "DB_NAME=$(DB_NAME)" --link $(NAME)-test:localdev \
		$(LOCAL_DEV_IMAGE) /usr/local/bin/migrate.sh
	docker run -v $(CURDIR)/:/var/www/ \
		--link $(NAME)-test:localdev $(LOCAL_DEV_IMAGE) \
		/var/www/vendor/bin/phpunit -c /var/www/phpunit.xml --testsuite component

{% endhighlight %}

_(I've removed the tasks for cleaning up after our containers to make this easier to follow,
but you can see the whole thing [here](https://github.com/fliglio/rest-gs/blob/master/Makefile).)_

And there you have it!

	# start up local-dev for exploratory testing.
	# logs go to stdout and type `CTRL+C` to stop it
	make run
	
	# apply database migrations to the database
	# on your running local-dev container
	make migrate

	# run testsuite "component" against your service
	# running mocked versions of external deps
	make test


## Docker all the things!

I hope this has been useful and I hope you aren't ever tempted to leave a HTTP api untested ever again!
