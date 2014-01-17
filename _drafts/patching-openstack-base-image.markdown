### Import Ubuntu Cloud Image
First things first: import one of Ubuntu's cloud image into OpenStack. You can find some [here](http://cloud-images.ubuntu.com/) or just use the same [January 2014 Precise build](http://cloud-images.ubuntu.com/precise/20140116/precise-server-cloudimg-amd64-disk1.img) I'm using.

	glance image-create \
		--name ubuntu-precise \
		--disk-format ami \
		--container-format bare \
		--is-public True \
		--copy-from \
		http://cloud-images.ubuntu.com/precise/20140116/precise-server-cloudimg-amd64-disk1.img

It will probably take a few minutes to load; make sure it's "ACTIVE" before continuing (you can check the status with `nova image-list`)

### heat-cfntools
Why does Heat use [heat-cfntools](https://github.com/openstack/heat-cfntools) instead of [CloutInit](https://help.ubuntu.com/community/CloudInit) to apply [user-data](http://docs.openstack.org/user-guide/content/user-data.html)? I couldn't tell you. But it does, and it doesn't come with Ubuntu's cloud images, so we need to add it. There are different tools for building your own base images (which you could use to include `heat-cfntools`) but for this tutorial I'm going to go take the quick and dirty route: install them with CloudInit and take a snapshot to use as my base for my Heat stack.

So how do we install heat-cfntools with CloudInit? With [nova.](http://docs.openstack.org/developer/nova/)

To boot our instance, we first need to figure out a network to boot it into. You can get this with `neutron`:

	neutron net-list

	+--------------------------------------+-----------+----------------------------------------------------+
	| id                                   | name      | subnets                                            |
	+--------------------------------------+-----------+----------------------------------------------------+
	| 1152a93b-d221-41a7-b5be-3428ed991eb2 | net04     | 552ca915-8bb6-46bf-b29c-3e0eceeef064 10.6.40.0/22  |
	| d98bc495-ac30-4136-9690-6545a8436468 | net04_ext | 4590955a-f4ac-42fa-81bf-5c730efb62b9 10.6.148.0/22 |
	+--------------------------------------+-----------+----------------------------------------------------+

We want the internal network, so we'll use the id which corresponds to "net04."
	
Next we need to supply the `heat-cfntools` install instructions to CloudInit via user data. There are a few different [user data input formats](https://help.ubuntu.com/community/CloudInit) available, but I'm going to use the "Cloud Config Data" format, which is specified by beginning your user-data with `#cloud-config`. Here's the file I made to pass to `nova boot` later:


cfntools-cloud-config.txt

{% highlight yaml %}
#cloud-config
ssh_import_id: [steve-stevebaker]
apt_sources:
 - source: "ppa:steve-stevebaker/heat-cfntools"
packages:
 - heat-cfntools
{% endhighlight %}

Armed with our net id and cloud config, we can now add `heat-cfntools` to our base image:

	nova boot --flavor m1.tiny --image ubuntu-precise --user-data ./cfntools-cloud-config.txt --nic net-id=1152a93b-d221-41a7-b5be-3428ed991eb2 ubuntuinst

After waiting a sufficient amount of time that we are sure the instance is provisioned, we can shut it down and take a [snapshot](http://docs.openstack.org/user-guide/content/nova_manage_images.html) to use as our Heat base image:

	nova stop ubuntuinst
	nova image-create ubuntuinst ubuntu-heat
