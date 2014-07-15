---
layout: post
status: publish
published: true
title: AngularJS State Management with ui-router
author: benschwartz
author_login: benschwartz
author_email: benschw@gmail.com
wordpress_id: 67
wordpress_url: http://txt.fliglio.com/?p=67
date: 2013-05-03 13:45:54.000000000 -05:00
categories:
- Post
tags: []
---

Managing state with AngularJS's ui-router (<a href="https://github.com/angular-ui/ui-router">https://github.com/angular-ui/ui-router</a>) is down right elegant. How is it different from a traditional router you might ask? Well I'll tell you, but first...

<!--more-->

<h2>A little history about routers</h2>
Routers provide an abstraction between a url and a request that an application knows how to satisfy. With traditional web service applications, this is straight forward:
<ul>
	<li>A url is routed to a request.</li>
	<li>A request is used to look up some driver code that knows how to build a response.</li>
</ul>
When a service is rendering a page or retrieving data, this separation of responsibilities makes sense.

<strong>But what happens when the concept of a "page" becomes more ambiguous?</strong> What happens when only parts of a page need to be updated, or the end user is given the option to perform their own curation of a page? <strong>What happens when modularity is needed in a request?</strong>

If page composition is fluid, but we still need urls to discretely (for the most part) represent the various permutations of content, how do we effectively route requests? No matter how much we decouple our page components, we're still left with convoluted logic evaluating how to organize them into a specific page.

Sure something like a router is necessary to translate between a url and a request, but how can you include modularity in a request when you are declaratively mapping it to a url?
<h2>AngularJS State Manager</h2>
You Don't!

The most interesting thing about AngularJS's new router, isn't the router itself, but the state manager that comes with it. Instead of targeting a controller/view to render for a given url, you target a state. States are managed in a heirarchy providing inheritance of parent states and complex composition of page components, all the while remaining declarative in nature.

Without further ado, start fiddling: <a title="angular state demo" href="http://jsfiddle.net/benschwartz/LhydD/">http://jsfiddle.net/benschwartz/LhydD/</a>

or digging into angular's own docs: <a title="ui-router wiki" href="https://github.com/angular-ui/ui-router/wiki">https://github.com/angular-ui/ui-router/wiki</a>

... or stick around for an explanation.
<h2> What can State do for me?</h2>
Lets start with a simple example:

index.html
{% highlight html linenos %}{% raw %}
<body ng-app="myApp">
    <div ui-view></div>
    <script src="app.js"></script>
</body>
{% endraw %}{% endhighlight %}

app.js 

{% highlight javascript linenos %}{% raw %}
angular.module('myApp', ['ui.state'])
    .config(['$stateProvider', function ($stateProvider) {

        var home = {
            name: 'home',
            url: '/',
            template: 'Hello {{name}}',
            controller: ['$scope', function ($scope) {
                $scope.name = "World";
            }]
        };

        $stateProvider.state(home);
    }])
{% endraw %}{% endhighlight %}

Not much is going on here, but basically this is how you'd implement a conventional route with the state manager. 

Lets build a simplified version of the settings section from the  <a href="http://jsfiddle.net/benschwartz/LhydD/">JSFiddle example</a>.
</a>
<h2>Settings</h2>
<a href="/images/settings-comp2.png"><img src="/images/settings-comp2.png" alt="settings-comp2" width="523" height="266" class="alignnone size-full wp-image-107" /></a>

So how do we build it?
Lets start by decomposing our pages (edit details and edit quotes) into states. To represent these two pages, we need three states: an abstract base state (settings) and two concrete child states (details and quotes.)

{% highlight javascript linenos %}{% raw %}
var settings = {
    name: 'settings',
    abstract: true,
    url: '/settings'
};

var details = {
    name: 'settings.details',
    parent: settings,
    url: ''
};

var quotes = {
    name: 'settings.quotes',
    parent: settings,
    url: '/quotes'
};
{% endraw %}{% endhighlight %}

Though incomplete, this is the gist of how you define states with ui-router. Right off the bat, you can see that urls are built through state inheritance: to edit quotes, we'll navigate to "settings/quotes" since the quotes state declares settings as its parent and thus inherits its url among other things.

Next lets fill in the gaps and wire this up into an Angular module.

<h3>accountSettings Module</h3>
app.js
{% highlight javascript linenos %}{% raw %}
angular.module('accountSettings', ['ui.state'])
    .config(['$stateProvider', function ($stateProvider) {

        var settings = {
            name: 'settings',
            url: '/settings',
            abstract: true,
            templateUrl: 'settings.html', 
            controller: 'SettingsController'
        };

        var details = {
            name: 'settings.details',
            parent: settings,
            url: '',
            templateUrl: 'settings.details.html'
        };

        var quotes = {
            name: 'settings.quotes',
            parent: settings,
            url: '/quotes',
            templateUrl: 'settings.quotes.html'
        };

        $stateProvider
            .state(settings)
            .state(details)
            .state(quotes);

    }])
    .controller('SettingsController', ['$scope', function ($scope) {
        $scope.user = {
            name: "Bob Loblaw",
            email: "bobloblaw@lawblog.com",
            password: 'semi-secret',
            quotes: "Lorem ipsum dolor sic amet"
        };
    }])
{% endraw %}{% endhighlight %}

index.html
{% highlight html linenos %}{% raw %}
<body ng-app="accountSettings">
    <div class="container" ui-view></div>
    <script src="app.js"></script>
</body>
{% endraw %}{% endhighlight %}

settings.html
{% highlight html linenos %}{% raw %}
<div class="row">
  <div class="span3">
    <div class="pa-sidebar well well-small">
      <ul class="nav nav-list">
        <li class="nav-header">Settings</li>
        <li ng-class="{ active: $state.includes(\'settings.user.default\')}"><a href="#/settings" >User Details</a></li>
        <li ng-class="{ active: $state.includes(\'settings.quotes\')}"><a href="#/settings/quotes" >User Quotes</a></li>
      </ul>
      <hr>
    </div>
  </div>
  <div class="span9" ui-view></div>
</div>
{% endraw %}{% endhighlight %}

settings.details.html
{% highlight html linenos %}{% raw %}
<h3>{{user.name}}\'s Details</h3>
<hr>
<div><label>Name</label><input type="text" ng-model="user.name" /></div>
<div><label>Email</label><input type="text" ng-model="user.email" /></div>

<button class="btn" ng-click="done()">Save</button>
{% endraw %}{% endhighlight %}

settings.quotes.html
{% highlight html linenos %}{% raw %}
<h3>{{user.name}}\'s Quotes</h3>
<hr>
<div><label>Quotes</label><textarea type="text" ng-model="user.quotes"></textarea></div>

<button class="btn" ng-click="done()">Save</button>
{% endraw %}{% endhighlight %}

We're Done!

<h3>Wait, what happened?</h3>

Ok ok, we can take a look at the code before we call it done.

The first thing you might notice, is that settings has a url but details doesn't. Since it doesn't make sense to go to the settings state (if for no other reason then that it's abstract) we have assigned the concrete state "details" to have a url of '' so that traffic to '/settings' will route to it. We could have done this the other way around, but as we add new pages to our accountSettings module (and children to our settings state) it makes sense for the parent state to declare the url namespace.

The other interesting thing (and this is where we really start realizing the power of states) is that there is only one controller and it's only wired up against the settings state! How are the 'details' and 'quotes' states getting populated with data only accessible by 'settings' state you ask? Controller inheritance! Sorry if I'm getting excited here, but think about what we just did: without any convoluted registry/cache scheme, we were able to remove the one-to-one relationship that is typical between server requests and building a page. All of a sudden, we can start thinking about what data we need for a feature and how to present that data to the user as not intrinsically linked!

<h3>Scope Creep!</h3>
No, not $scope creep. Scope creep like what Marketing throws at you after you're 90% done with their initial request.

Now we're being asked to create a status bar in the settings section that will always display a description of what the user is supposed to be doing. (Don't ask me why marketing would want this... but it does help to illustrate another feature of ui-router)

<a href="/images/settings-comp3.png"><img src="/images/settings-comp3.png" alt="settings-comp3" width="528" height="387" class="alignnone size-full wp-image-145" /></a>

<h3>Multiple (named) Views</h3>
We've already seen multiple views per page in the form of hierarchical states, each with their own view, but what about a single state that needs to display multiple views? Our new requirement, displaying a description of what the user is supposed to be doing, relies on just that.

So maybe you've guessed by now that ui-router supports declaring multiple named views per state. If so, you're right; and here's an update to our hello world example illustrating how:

index.html
{% highlight html linenos %}{% raw %}
<body ng-app="myApp">
    <div ui-view></div>
    static nonsense
    <div ui-view="foo"></div>
    <script src="app.js"></script>
</body>
{% endraw %}{% endhighlight %}

app.js 
{% highlight javascript linenos %}{% raw %}
angular.module('myApp', ['ui.state'])
    .config(['$stateProvider', function ($stateProvider) {

        var home = {
            name: 'home',
            url: '/',
            views: {
                '': {
                    template: 'Hello {{name}}',
                    controller: ['$scope', function ($scope) {
                        $scope.name = "World";
                    }]
                },
                'foo': {
                    template: 'bar'
                }
        };

        $stateProvider.state(home);
    }])
{% endraw %}{% endhighlight %}

There you have it. One state updating two views. The default view (represented by '') and the 'foo' view.

<h3>accountSettings Module Updates</h3>

Since this is such an easy feature to add on, we'll let marketing slide it in (even though we were already done.) All we need to do is add a named view to the settings.html partial and convert our 'details' and 'quotes' states to update both views.

settings.html
{% highlight html linenos %}{% raw %}
<div class="alert" ui-view="hint"></div>
<div class="row">
  <div class="span3">
    <div class="pa-sidebar well well-small">
      <ul class="nav nav-list">
        <li class="nav-header">Settings</li>
        <li ng-class="{ active: $state.includes(\'settings.user.default\')}"><a href="#/settings" >User Details</a></li>
        <li ng-class="{ active: $state.includes(\'settings.quotes\')}"><a href="#/settings/quotes" >User Quotes</a></li>
      </ul>
      <hr>
    </div>
  </div>
  <div class="span9" ui-view></div>
</div>
{% endraw %}{% endhighlight %}

state definitions from app.js
{% highlight javascript linenos %}{% raw %}
        var details = {
            name: 'settings.details',
            parent: settings,
            url: '',
            views: {
                '': {
                    templateUrl: 'settings.details.html'
                },
                'hint': {
                    template: 'edit your details!'
                }
        };

        var quotes = {
            name: 'settings.quotes',
            parent: settings,
            url: '/quotes',
            views: {
                '': {
                    templateUrl: 'settings.quotes.html'
                },
                'hint': {
                    template: 'edit your quotes!'
                }
        };
{% endraw %}{% endhighlight %}

<h2>Conclusion</h2>
In a perfect world, the <a href="http://en.wikipedia.org/wiki/Design_Patterns" title="Design Patterns">GOF</a> would come along and explain in simple terms the "right" way to route urls to requests in single page Javascript applications, and this way would soon become ubiquitous.

In lieu of this, we'll just have to keep trying things out and seeing what works. Maybe one day we'll be back to that comfort zone which Routing provided for web service application architecture.

Since I only scratched the surface, go check out <a href="https://github.com/angular-ui/ui-router" title="ui-router">ui-router on GitHub</a>. There's a more complete example there as well as some documentation on the wiki. 
