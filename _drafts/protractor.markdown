---
layout: post
title: Concurrent Protractor Tests with Selenium Grid in Docker
---

Have you ever wished your front end testing could be sped up? Has it ever seemed like Selenium was a royal pain in the ass? Though I agree, this isn't the post that will relieve those problems. What it is, is a way to make testing your Angular app _slightly_ less painful by providing light weight [Selenium grid](https://code.google.com/p/selenium/wiki/Grid2) node parallelization with [Protractor](https://github.com/angular/protractor) and [Docker](https://www.docker.io/).

Specifically, this post will... 

- Start with a stock [Yeoman](http://http://yeoman.io/) generated Angular app
- Introduce [Protractor](https://github.com/angular/protractor) (and [grunt-protractor-runner](https://github.com/teerapap/grunt-protractor-runner))
- (add in some demo tests)
- Show you how to run a tunable and scalable Selenium grid cluster in a single [Vagrant](http://www.vagrantup.com/) vm with [Docker](https://www.docker.io/)
- Configure the [Grunt](http://http://gruntjs.com/) build to run the tests concurrently using the cluster

<!--more-->

Interested in skipping to the end?

- [docker-selenium-grid](https://github.com/benschw/docker-selenium-grid) - Docker containers and a simple orchestration script to run your grid cluster
- [vagrant-selenium-grid](https://github.com/benschw/vagrant-selenium-grid) - Provisioning package to turn selenium grid setup into `vagrant up`
- [protractor-demo](https://github.com/benschw/protractor-demo) - The demo angular app with all the crap I'm going to add in this post

One last note before I get started... [Francisco Martinez](https://github.com/FMartinez4) deserves all of the credit for figuring out how to integrate Protractor and concurrency in Grunt; I'm just writing up his work and cramming [another Docker prototype](http://txt.fliglio.com/2013/09/protyping-web-stuff-with-docker/) into a blog bost. Thanks Francisco.



## Get started with Selenium Grid <small>(in a single vagrant vm)</small>

	vagrant up

thats it: this will boot a selenium grid cluster with 3 firefox nodes running.

Tweak the settings by shelling in and working with the 
[docker-selenium-grid](https://github.com/benschw/docker-selenium-grid) repo:

	vagrant ssh
	cd docker-selenium-grid
	./grid.sh

## test your install

If you want to make sure it works, install 
[protractor](https://github.com/angular/protractor) and run `./test.sh`
 

	npm install -g protractor
	./test.sh




# protractor concurrency demo

	sudo npm install -g yo
	sudo npm install -g protractor
	sudo npm install -g grunt-cli
	sudo npm install -g bower

	mkdir protractor-demo
	cd protractor-demo

	npm install generator-angular

	yo angular # go ahead and "Y" everything
	# bower install

## protractor

	npm install protractor --save-dev
	npm install grunt-protractor-runner --save-dev

	# add in protractor test scenarios
	cp -r ../protractor-demo-bak/test/scenario/ test/scenario
	


### Gruntfile Updates
after "karma" section

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

at top

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


in "concurrent" section

{% highlight javascript %}

      protractor: [
        'protractor:feature1',
        'protractor:feature2'
      ],
{% endhighlight %}



update "connect.options" to use `hostname: '0.0.0.0'`, and "connect.dist" to use `port: 9002` 

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

register task

{% highlight javascript %}

	grunt.registerTask('ptr', [
		'clean:server',
		'connect:dist',
		'concurrent:protractor'
	]);
{% endhighlight %}


