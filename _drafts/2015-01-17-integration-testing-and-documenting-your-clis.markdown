---
layout: post
status: publish
published: true
title: Free Docs when you Integration Test Your CLI; and Vice Versa
author_login: benschwartz
author_email: benschw@gmail.com
categories:
- Post
tags: []
---

An area that often gets neglected in testing is the command line interface. I found myself in the past testing the internals, keeping the flag processing light, and just hoping for the best. Additionally, there's the difficult chore of keeping the docs on your project page up to date as you add and even rename flags.

This post will walk through how to knock out both these problems with one stone: [cli-unit](http://txt.fliglio.com/cli-unit/), a testing framework that runs off of "example usage" friendly markdown you can include right in your `README`.

<!--more-->

_Full disclosure, this post shamelessly promotes a couple of projects I just finished working on: [jsonfilter](http://txt.fliglio.com/jsonfilter/) and [cli-unit](http://txt.fliglio.com/cli-unit/). ([figlet](http://www.figlet.org/) isn't mine, despite the resemblances between its name and my domain)_

## Getting Started

Before getting into it, let me show you a couple simple tests for the program [figlet](http://www.figlet.org/) (a cli app for making ascii art text) to illustrate how cli-unit works:

### Figlet Example

First off, create a test file (`figlet-examples.md`) with some tests, each with a "when" and "then" block specified. Inside the "when" is the command line we want to test in a code block and under the "then" is the expected output of said command, also in a code block.

	### test: figlet makes ascii art out of text
	#### when:
		figlet hello world

	#### then:
		 _          _ _                            _     _ 
		| |__   ___| | | ___   __      _____  _ __| | __| |
		| '_ \ / _ \ | |/ _ \  \ \ /\ / / _ \| '__| |/ _` |
		| | | |  __/ | | (_) |  \ V  V / (_) | |  | | (_| |
		|_| |_|\___|_|_|\___/    \_/\_/ \___/|_|  |_|\__,_|


	### test: The "-f script" option makes your output cursive
	#### when:
		figlet -f script hello world

	#### then:
		 _          _   _                             _        
		| |        | | | |                           | |    |  
		| |     _  | | | |  __             __   ,_   | |  __|  
		|/ \   |/  |/  |/  /  \_  |  |  |_/  \_/  |  |/  /  |  
		|   |_/|__/|__/|__/\__/    \/ \/  \__/    |_/|__/\_/|_/
	                                                       

To run these tests, just point [cli-unit](http://txt.fliglio.com/cli-unit/) to your markdown files with tests in them:

	$ cli-unit figlet-examples.md 
	Pass (2/2 tests successful)

And since every modern source control system renders markdown, if you navigate to `figlet-examples.md` (for example, in github) it renders as:

### test: figlet makes ascii art out of text
#### when:
	figlet hello world

#### then:
	 _          _ _                            _     _ 
	| |__   ___| | | ___   __      _____  _ __| | __| |
	| '_ \ / _ \ | |/ _ \  \ \ /\ / / _ \| '__| |/ _` |
	| | | |  __/ | | (_) |  \ V  V / (_) | |  | | (_| |
	|_| |_|\___|_|_|\___/    \_/\_/ \___/|_|  |_|\__,_|


### test: The "-f script" option makes your output cursive
#### when:
	figlet -f script hello world

#### then:
	 _          _   _                             _        
	| |        | | | |                           | |    |  
	| |     _  | | | |  __             __   ,_   | |  __|  
	|/ \   |/  |/  |/  /  \_  |  |  |_/  \_/  |  |/  /  |  
	|   |_/|__/|__/|__/\__/    \/ \/  \__/    |_/|__/\_/|_/


Not particularly useful to test someone else's interface, but figlet seemed particularly suited for a "hello world" example.

## Beyond Vanilla

Before walking through adding this to your latest command line app, let me go into what _cli-unit_ is and isn't good at.

It's meant to be easy to read and not have a lot of syntactic sugar. Most of the work is placed on _bash_, so you don't have to learn a lot of _cli-unit_ syntax, just what the significance of the "test", "when", and "then" blocks are.

For example, any test with a non-zero exit code will fail, so if you want to test an error case, you have to do something like 

	### test: not found exits !0
	#### when:
		ls dne || echo not found
	#### then:
		not found

The same goes for testing stderr: 

	### test: error message to std err when not found
	#### when:
		ls dne 2>&1 || true
	#### then:
		ls: cannot access dne: No such file or directory

Since anything in the "when" block is interpreted with _bash_, this also means you can even write a short script to exercise your app

	### test: more involved example
	#### when:

        VALS=$(echo -e "foo\nbar\nbaz")

        while read -r THING; do
            echo Hello $THING
        done <<< "$VALS"


	#### then:
        Hello foo
        Hello bar
        Hello baz

The syntax doesn't care about any markdown in your test files that isn't part of your tests (including non-code block text inside your tests). This means you can include additional explanation for your tests, or supplement individual sections in your README with their own examples/tests.
	
	# echo
	## some history

	Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam eu tellus efficitur, vulputate odio a, sagittis dui. Donec vestibulum nibh efficitur hendrerit tincidunt. 
	
	## examples	
	### test: echo should output its arguments
	#### when:
	Vivamus tellus nibh, vestibulum vitae eros eget, condimentum pretium leo.

		echo hello world

	#### then:

		hello world

	- condimentum 
	- pretium 
	- leo


And there you have it. It's a very simple interface by design, but one that still allows for flexible usage and clean integration with other docs.

## Testing your app

Now we know what _cli-unit_ does and what it doesn't do; what does that mean in practice? I'll explain how I used _cli-unit_ to test the cli for [jsonfilter](https://github.com/benschw/jsonfilter), an app I wrote in golang to pull values out of json content.

### TDD
When I was designing the jsonfilter, I found it useful to write down example cli uses and what I want the output to look like (use cases). By taking those notes one step further and adding markdown headings, I was able to have acceptance criteria that I could evaluate my application against from the command line. Of course I unit tested the internals too, but the _cli-unit_ tests provide an extra layer of test and gave me documentation for free. (Actually, a more accurate description is _cli-unit_ provides a style guide for my documentation and integration tests for free.)

When I was finished, I pulled out a few tests to put in the project [README](https://github.com/benschw/jsonfilter) to serve as high level documentation and left the remainder in [int_test.md](https://github.com/benschw/jsonfilter/blob/master/int_test.md) to continue protecting my interface from regressions and provide a documentation deep dive for those whom are so inclined.

### CI

You probably don't want to have to install any dependencies in your build environment (ci servers or even local dev), so we still need an easy way to get a copy of cli-unit.

That's what [cli-unitw.sh](https://github.com/benschw/cli-unit/blob/master/cli-unitw.sh) (cli-unit wrapper) is for. It's a simple bash script which downloads a copy of cli-unit and proxies any arguments to it (i.e. it works just like _cli-unit_ but is light enough to commit to your project.) It stores the real program in `.cli-unit` so make sure to add that to your `.gitignore` file.

_N.b., the copy linked to above pulls the latest stable build of cli-unit from Drone.io. If that feels risky (it probably should), you can use the [release copy](https://github.com/benschw/cli-unit/releases) to pull from the project's github release page)_

The last step was to wire it all into my ci ([drone.io]()) which I did in a _Makefile_:


	build:
        mkdir -p build/output
        go build -o build/output/jsonfilter

	test: build
        go test
        /bin/bash ./cli-unitw.sh -v README.md *_test.md

	clean:
        rm -rf ./.cli-unit


And now jsonfilter's interface is under test and its docs are always up to date!

## you can even test your blog!
One last example...

Since I'm using Jekyl and my blog is written in markdown, I can even use cli-unit to spell check this post!

### test: this post should not have spelling errors
#### when:
	aspell -c _drafts/2015-01-17-integration-testing-and-documenting-your-clis.markdown && echo success!
#### then:
	success!


_n.b. this test would only pass if I added a bunch of file extensions and tech words to my library..._