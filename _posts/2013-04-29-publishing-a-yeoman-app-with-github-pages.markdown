---
layout: post
status: publish
published: true
title: Publishing a Yeoman app with GitHub Pages
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
wordpress_id: 23
wordpress_url: http://txt.fliglio.com/?p=23
date: 2013-04-29 22:10:53.000000000 -05:00
categories:
---

There comes a time in every Github user's life, when they begin to assume that other people might give a damn about the code they have written. While this assumption is by and large wrong, every so often someone produces something worth wrapping a marketing homepage around. Or they might want to dress up their GitHub page enough that their coworkers are willing to treat their reinvention of the wheel as a first class framework.

For the rest of this doc I'll be writing to the latter group (since that's the category I fall into) but the steps should be the same in either case.
<h2>Getting Started</h2>
We're going to need to get a few things going before we get started:
<ul>
	<li>a <a title="GitHub" href="https://github.com/">github account</a></li>
	<li><a title="Yeoman" href="http://yeoman.io/">yeoman</a></li>
	<li><a title="GruntJS" href="http://gruntjs.com/">grunt</a></li>
	<li>a git client with the subtree (more on this later)</li>
</ul>
<h3> Setting up a github repo for  your site</h3>
Follow along here, or get more details on setting up your user pages on github from their docs: <a href="https://help.github.com/articles/user-organization-and-project-pages">https://help.github.com/articles/user-organization-and-project-pages</a>
<ul>
	<li>Create a new repository using the convention:
{% highlight bash %}
github.com/username/username.github.io
{% endhighlight %}

</li>
</ul>
so if your github username is bobloblaw, you're be creating a new repo called "bobloblaw.github.io"
<h3>Creating a "src" branch to maintain your javascript app in</h3>
If i leave something out, yeoman talks a little about this step here: <a href="http://bit.ly/13GXzmz">http://bit.ly/13GXzmz</a>

Basically, the trick here, is GitHub wants to host the root of your "master" branch as your doc root, and yeoman wants your docroot to be hosted out of the "dist/" folder. So what we're going to do it set up a "src" branch to hold our yeoman development environment, and publish (git subtree push) the contents of dist/ to the root of our master branch.
<ul>
	<li>Clone your new repo &amp; create a "src" branch so we can add in some Yeoman!
{% highlight bash %}

$ git clone git@github.com:bobloblaw/bobloblaw.github.io.git
$ git branch src
$ git checkout src
$ echo "#github pages src branch" &gt; README.md
$ git commit -am "adding a readme so i can add this branch to my repo on github"
$ git push -u origin src

{% endhighlight %}

</li>
</ul>
<h3>Yeoman</h3>
At this point,  we need to get our Yeoman on so we have something to publish. Even though the possibilities are virtually endless and yeoman could be the topic of several tutorials, let's just assume you're into AngularJS:
<ul>
	<li><span style="line-height: 13px;">from your checkout of the src branch, scaffold out your application with Yeoman</span>

{% highlight bash %}
$ npm install generator-angular generator-karma
$ yo angular
{% endhighlight %}

</li>
</ul>
Now you've got  a brand spankin new angular app thats just itching to be built and deployed to GitHub
<ul>
	<li><span style="line-height: 13px;">build your project</span>
{% highlight bash %}
$ grunt build
{% endhighlight %}
</li>
	<li>tweak your .gitignore file to allow committing the dist folder we just built (remove "dist" from the file)
{% highlight bash %}
$ nano .gitignore
{% endhighlight %}

</li>
	<li>commit stuff and push!
{% highlight bash %}
$ git commit -am "bob loblaw's github account is about to get snazzy"
$ git push origin src
{% endhighlight %}
</li>
</ul>
<h3>Get it in the interwebs!</h3>
Now that we've got our app built and you've sorted out how to acquire npm which i pretended you just had, you'd think we would be pretty close to seeing something on your github page. But first we have to install a shiny new tool for your git client. Or maybe you're lucky and running "git subtree" doesn't spit back:
<pre><code>"git: 'subtree' is not a git command. See 'git --help'."</code></pre>
If you're running Ubuntu or HomeBrew on OS X,  this should help you: <a href="http://bit.ly/ZYfJgB">http://bit.ly/ZYfJgB</a>
If you're running port on OS x,  give this a try:

{% highlight bash %}
$ git clone https://github.com/git/git.git
$ cd git/contrib/subtree/
$ make
$ sudo cp git-subtree /opt/local/libexec/git-core/
{% endhighlight %}
<h3>No Really, Get it in the interwebs!</h3>
Ok ok, now it really is just a command away:
<ul>
	<li><span style="line-height: 13px;"><span style="line-height: 13px;">push your dist folder to the master branch
</span></span>
<pre><code>$ git subtree push --prefix dist origin master</code></pre>
</li>
</ul>
<h3>Bask in the glory</h3>
Did it work? http://bobloblaw.github.io should be hosting your angular app now... but there's always a chance it isn't.

If it is, then that means that your open source gem is at last being properly represented. With a crisp looking page declaring "'Allo!" to anyone who will listen, it's only a matter of time before the forks come rolling in and you start gaining notoriety as not just a hacker, but someone who can see the role marketing plays in programming.

Added bonus: at the next dinner party you attend you can stop sheepishly replying "I'm just so busy!" when your fans implore you to start publishing your code.
