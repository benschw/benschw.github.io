---
layout: post
title: Concurrent Protractor Tests with Selenium Grid in Docker
categories:
- Post
tags: []
---

Have you ever wished your front end testing could be sped up? Has it ever seemed like Selenium was a royal pain in the ass? Though I agree, this isn't the post that will relieve those problems. What it is, is a way to make testing your Angular app _slightly_ less painful by providing light weight [Selenium grid](https://code.google.com/p/selenium/wiki/Grid2) node parallelization with [Protractor](https://github.com/angular/protractor) and [Docker](https://www.docker.io/).

Specifically, this post will... 

- Show you how to run a tunable and scalable Selenium grid cluster in a single [Vagrant](http://www.vagrantup.com/) vm with [Docker](https://www.docker.io/)
- Introduce [Protractor](https://github.com/angular/protractor) (and [grunt-protractor-runner](https://github.com/teerapap/grunt-protractor-runner)) 
  into a stock [Yeoman](http://http://yeoman.io/) generated Angular app
- And configure the [Grunt](http://http://gruntjs.com/) build to run some example tests concurrently using the cluster

<!--more-->

Interested in skipping to the end?

- [docker-selenium-grid](https://github.com/benschw/docker-selenium-grid) - Docker containers and a simple orchestration script to run your grid cluster
- [vagrant-selenium-grid](https://github.com/benschw/vagrant-selenium-grid) - Provisioning package to turn selenium grid setup into `vagrant up`
- [protractor-demo](https://github.com/benschw/protractor-demo) - The demo angular app with all the crap I'm going to add in this post

One last note before I get started... [Francisco Martinez](https://github.com/FMartinez4) deserves all of the credit for figuring out how to integrate Protractor and concurrency in Grunt; I'm just writing up his work and cramming [another Docker prototype](http://txt.fliglio.com/2013/09/protyping-web-stuff-with-docker/) into a blog bost. Thanks Francisco.



## Get started with Selenium Grid <small>(in a single vagrant vm)</small>
I've put together two projects to supply the Selenium Grid functionality. The [docker-selenium-grid](https://github.com/benschw/docker-selenium-grid) project supplies Dockerfiles for two Docker containers: a hub and a Firefox node; and comes with a script to help you add start and stop the cluster or new nodes. The [vagrant-selenium-grid](https://github.com/benschw/vagrant-selenium-grid) project is a Vagrant wrapper for the first project which further simplifies starting a cluster to simply running `vagrant up`.

To boot your cluster, simply run the following commands

	git clone https://github.com/benschw/vagrant-selenium-grid
	cd vagrant-selenium-grid
	vagrant up

This VM defaults to using 2gb of ram, but this can easily be tuned by tweaking the `Vagrantfile` before running `vagrant up`. It will run three firefox nodes by default, but you can tweak this by shelling into the Vagrant vm and interacting with the cluster via `~/docker-selenium-grid/grid.sh`

_If you want to make sure it works, install [protractor](https://github.com/angular/protractor) and run `./test.sh`_
 
	npm install -g protractor
	./test.sh

#### Why Docker?
Docker provide's lighweight virtualization. In other words, your laptop is probably capable of driving a handfull of browsers at once, but not a handfull of VMs. Docker gives you to encapsulation of a VM with (almost) none of the overhead. It does require a Linux kernel however, which is why i've recommended running your grid inside a Vagrant vm.

Running Linux? Skip the VM and run [docker-selenium-grid](https://github.com/benschw/docker-selenium-grid) on your host (you'll just have to [install Docker](http://docs.docker.io/en/latest/installation/ubuntulinux/) first.)

## Concurrent Protractor Testing

### Yo Angular!
I'll assume you've used Yeoman before, but just in case - here's how to get it:

	sudo npm install -g yo
	sudo npm install -g grunt-cli
	sudo npm install -g bower

Now that you have the basics, lets use our new tools to generate an angular app:

	mkdir protractor-demo
	cd protractor-demo

	npm install generator-angular

	yo angular # go ahead and "Y" everything

This sets up [Yeoman's](http://http://yeoman.io/) opinionated default angular app. Deps are installed with [bower](http://bower.io/) and a build script is provided that can be run with [grunt](http://gruntjs.com/).



### Introducing Protractor
Now lets start adding in Protractor.

Install the npm deps:

	sudo npm install -g protractor
	npm install protractor --save-dev
	npm install grunt-protractor-runner --save-dev

#### Add some tests and Update your build
At this point you can decide if you want to follow along and patch your `Gruntfile.js` by hand, or just grab a copy from the [protractor-demo](https://github.com/benschw/protractor-demo) project. Additionally, I've included [scenario.tar.bz2](https://github.com/benschw/protractor-demo/raw/master/scenario.tar.bz2) which holds the example tests we will be wiring up.

The quick way:

	wget -N https://raw.github.com/benschw/protractor-demo/master/Gruntfile.js
	wget -qO- https://github.com/benschw/protractor-demo/raw/master/scenario.tar.bz2 | tar -C ./test/ -xjvf -

#### What are the changes?

Add in your Protractor test wiring after the "karma" section:

{% highlight javascript %}

    protractor: {
      options: {
        //configFile: 'node_modules/protractor/referenceConf.js', // Default config file
        keepAlive: true, // If false, the grunt process stops when the test fails.
        noColor: false, // If true, protractor will not use colors in its output.
        args: {
          baseUrl: 'http://'+getIpAddress()+':'+ '<%= connect.dist.options.port %>' //config for all protractor tasks
        }
      },
      feature1: {
        options: {
          configFile:'test/scenario/conf/featureList1.js', // Target-specific config file
        }
      },
      feature2: {
        options: {
          configFile:'test/scenario/conf/featureList2.js', // Target-specific config file
        }
      }
    }
{% endhighlight %}

Provide the `getIpAddress()` function at the top of your file. Since your grid is running in a VM, we need to give it more than `localhost` to target:

{% highlight javascript %}

	var os = require('os');

	function getIpAddress() {
	  var ipAddress = null;
	  var ifaces = os.networkInterfaces();

	  function processDetails(details) {
	    if (details.family === 'IPv4' && details.address !== '127.0.0.1' && !ipAddress) {
	      ipAddress = details.address;
	    }
	  }

	  for (var dev in ifaces) {
	    ifaces[dev].forEach(processDetails);
	  }
	  return ipAddress;
	}
{% endhighlight %}


Reference our two test features in the "concurrent" section:

{% highlight javascript %}

      protractor: [
        'protractor:feature1',
        'protractor:feature2'
      ],
{% endhighlight %}



In the "connect" section, update "connect.options" to use `hostname: '0.0.0.0'`, and "connect.dist" to use `port: 9002` 

{% highlight javascript %}

    connect: {
      options: {
        port: 9000,
        // Change this to '0.0.0.0' to access the server from outside.
        hostname: '0.0.0.0',
        livereload: 35729
      },
      ...
      dist: {
        options: {
          port: 9002,
          base: '<%= yeoman.dist %>'
        }
      }
      ...
    }
{% endhighlight %}

And last but not least, add a new task at the bottom of the file so we can run these bad boys:

{% highlight javascript %}

	grunt.registerTask('ptr', [
		'clean:server',
		'connect:dist',
		'concurrent:protractor'
	]);
{% endhighlight %}


#### Run the tests... Fast!

Assuming all our updates made it in and Yeoman's Angular generator hasn't changed, we should now be able to run tests for our two test features concurrently:

	grunt ptr

I hope it worked for you, and I hope this helped.
