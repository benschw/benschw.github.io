---
layout: post
title: Provisioning in Openstack with Heat and Puppet
---

I apologize in advance, because this is more _stream of consciousness in a terminal_ then how to use either Puppet or Openstack's Heat. But there is a noticeable void in terms of documentation, so I figure putting something out there is better then nothing... and hopefully people will comment and tell me how I _should_ be doing things.

That said, here's an incredibly opinionated way to use puppet in conjunction with heat to provision a server to serve a Jekyll site (or anything else you can find a puppet module for.)

<!--more-->

## Get a Base Image Ready

First things first: get a base image ready to work from. I'm going to work from Ubuntu's cloud images, which you can find [here](http://cloud-images.ubuntu.com/).

	glance image-create \
		--name ubuntu-precise \
		--disk-format ami \
		--container-format bare \
		--is-public True \
		--copy-from \
		http://cloud-images.ubuntu.com/precise/20140116/precise-server-cloudimg-amd64-disk1.img

It will probably take a few minutes to load; make sure it's "ACTIVE" before continuing (you can check the status with `nova image-list`)

## Adding some Heat

At this point, we can start playing with [Heat](https://wiki.openstack.org/wiki/Heat). Take a look at [some templates](https://github.com/openstack/heat-templates) to get an idea of how this works, or just keep reading. 

If you're like me, the idea of wrestling with user data formats and using bash scripts to build your box causes anxiety. So let's build up our box with [Puppet](http://puppetlabs.com/) instead.

Going forward, I'll be updating a [hot template](https://github.com/openstack/heat-templates/blob/master/hot/servers_in_existing_neutron_net.yaml) I found in Openstack's [heat templates](https://github.com/openstack/heat-templates) github repo which I pared down to only launch a single server ("Server1").

### Making Puppet Hot

There are a number of ways to run puppet and even more ways to get puppet modules / dependencies in place. I will walk you through one (very) opinionated way using [r10k](https://github.com/adrienthebo/r10k) to fetch dependencies and using `user_data` to provide a generic install script to run.

I've hosted a git repo ([puppet-txt.fliglio.com](https://github.com/benschw/puppet-txt.fliglio.com)) to serve as our example controller repo. It contains a `Puppetfile` to provide `r10k` with a deps list, and a `default.pp` manifest to drive setting up the vm. We will invoke this driver using a bootstrap script contained in `user_data`. Specifically, it will:

- Update puppet since Precise comes with a 2.x version
- install r10k and git
- clone the example controller repo (notice I've parameterized the repo address so you could use this same template to provision any number of things)
- grab deps with r10k
- run puppet apply

The puppet code we will be applying to our vm will:

- install [Jekyll](http://jekyllrb.com/)
- clone a copy of [txt.fliglio.com](https://github.com/benschw/txt.fliglio.com.git) from github (this is specified in the controller repo's `default.pp`)
- install an `upstart` config which configures a service to serve the site.
- start the newly configured service (and start serving the site)

excerpt from the modified heat template:

{% highlight yaml %}

...
parameters:
  ...
  puppet_repo:
    type: string
    description: Git repo with puppet Puppetfile and manifests
resources:
  server1:
    type: OS::Nova::Server
    properties:
      name: Server1
      image: { get\_param: image }
      flavor: { get\_param: flavor }
      key\_name: { get\_param: key\_name }
      # admin\_user: { get\_param: admin\_user }
      networks:
        - port: { get\_resource: server1\_port }
      user_data: 
        str_replace:
          template: |
            #!/bin/bash

            apt-key adv --recv-key --keyserver pool.sks-keyservers.net 4BD6EC30
            echo "deb http://apt.puppetlabs.com precise main" > /etc/apt/sources.list.d/puppetlabs.list
            echo "deb http://apt.puppetlabs.com precise dependencies" >> /etc/apt/sources.list.d/puppetlabs.list
            apt-get update
            apt-get -y install puppet ruby1.9.1-full git

            gem install r10k

            TMP_PATH=`mktemp -d`

            git clone $PUPPET_REPO $TMP_PATH
            cp $TMP_PATH/puppet/Puppetfile /etc/puppet/Puppetfile # r10k gets cranky if the Puppetfile isn't here
            cd /etc/puppet
            r10k puppetfile install ./Puppetfile

            puppet apply $TMP_PATH/puppet/Manifests/default.pp

          params:
            $PUPPET_REPO: { get_param: puppet_repo }

...	
{% endhighlight %}

### Getting ready to launch...

The last steps before we can provision our stack are...

Add in an ssh key (only if you need to shell into the box):

	nova keypair-add --pub_key ~/.ssh/id_rsa.pub bens

Identify the public and private net_id values. You can get this with `neutron`:

	$ neutron net-list
	+--------------------------------------+-----------+----------------------------------------------------+
	| id                                   | name      | subnets                                            |
	+--------------------------------------+-----------+----------------------------------------------------+
	| 1152a93b-d221-41a7-b5be-3428ed991eb2 | net04     | 552ca915-8bb6-46bf-b29c-3e0eceeef064 10.6.40.0/22  |
	| d98bc495-ac30-4136-9690-6545a8436468 | net04_ext | 4590955a-f4ac-42fa-81bf-5c730efb62b9 10.6.148.0/22 |
	+--------------------------------------+-----------+----------------------------------------------------+

Identify the private\_subnet\_id:

	$ neutron subnet-list
	+--------------------------------------+-------------------+---------------+------------------------------------------------+
	| id                                   | name              | cidr          | allocation_pools                               |
	+--------------------------------------+-------------------+---------------+------------------------------------------------+
	| 4590955a-f4ac-42fa-81bf-5c730efb62b9 | net04_ext__subnet | 10.6.148.0/22 | {"start": "10.6.150.2", "end": "10.6.151.254"} |
	| 552ca915-8bb6-46bf-b29c-3e0eceeef064 | net04__subnet     | 10.6.40.0/22  | {"start": "10.6.40.2", "end": "10.6.43.254"}   |
	+--------------------------------------+-------------------+---------------+------------------------------------------------+


And make sure we have our heat template ready (download my copy [here](https://raw.github.com/benschw/puppet-txt.fliglio.com/master/demo.yml))

### That's all? you mean we're ready?

Let's launch a stack:

	heat stack-create teststack \
		-f ./demo.yml \
		-P "key_name=bens;image=ubuntu-precise;flavor=m1.small;public_net_id=d98bc495-ac30-4136-9690-6545a8436468;private_net_id=1152a93b-d221-41a7-b5be-3428ed991eb2;private_subnet_id=552ca915-8bb6-46bf-b29c-3e0eceeef064;puppet_repo=https://github.com/benschw/puppet-txt.fliglio.com.git"


Now you can figure out the public ip and navigate to it in your browser:

	$ nova list
	+--------------------------------------+------------+---------+------------+-------------+-------------------------------+
	| ID                                   | Name       | Status  | Task State | Power State | Networks                      |
	+--------------------------------------+------------+---------+------------+-------------+-------------------------------+
	| 773ba7bf-8aae-428b-a19c-2bce35d63db7 | Server1    | ACTIVE  | None       | Running     | net04=10.6.40.15, 10.6.150.16 |
	| 2e9e994c-d2f9-4232-82bd-752ccdff346c | ubuntuinst | SHUTOFF | None       | Shutdown    | net04=10.6.40.13              |
	+--------------------------------------+------------+---------+------------+-------------+-------------------------------+

	$ chromium-browser 10.6.150.16


Some notes...

- When I ran through this example, there was no way to specify an admin_user with heat, so your ssh key will always be installed to `ec2-user`. This option seems to be available now, so if you're using a more recent version of Havana you may have better luck. 
- It takes a while to apply the user_data, so don't expect everything to be ready yet. Shelling in and running `ps -ef` should give you some idea of how far along things are.

## Final Thoughts

Heat is pretty cool (and pretty rough around the edges) and I've only scratched the surface. Everything done here could basically be accomplished with `nova`; heat's real power isn't revealed until you start configuring multiple nodes with complex relationships. Maybe I'll get into that another time.

