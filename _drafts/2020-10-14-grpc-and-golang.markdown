---
layout: post
status: publish
published: true
title: gRPC with Golang
categories:
- Post
tags: []
---


This post will walk through using Protocol Buffers & gRPC to create a service & client for managing books using Go.

<!--more-->


## Basic Project scaffolding for our Books Service
_code for bootstrapping your project can be found in the `bootstrap` branch of the [demo repo](https://github.com/benschw/books-grpc-poc/tree/bootstrap)_

Let's look at the directory structure we will create to bootstrap our project.
Notice that there is a separate entry point for our client and server in the `cmd` directory,
and that I'm keeping my `.proto` file and generated code (`book.pb.go`) in `/pkg/pb/books`.

{% highlight bash %}
├── Makefile
├── README.md
├── cmd
│   ├── client
│   │   └── main.go
│   └── server
│       └── main.go
├── go.mod
├── go.sum
└── pkg
    └── pb
        └── books
            ├── book.pb.go
            └── book.proto
{% endhighlight %}



### Create the project & initialize it as a go module

First things first: create the project directory & initialize it as a go module.

{% highlight go %}
$ mkdir books-grpc-poc
$ cd books-grpc-poc
$ go mod init github.com/benschw/books-grpc-poc
go: creating new go.mod: module github.com/benschw/books-grpc-poc
$ cat go.mod
module github.com/benschw/books-grpc-poc

go 1.15
{% endhighlight %}


### Create and build a minimal Protocol Buffer src file

Before we do anything interesting, let's make sure everything is connected correctly. So let's start off with a bare minimum proto file that we can expand on in the coming sections.

`pkg/pb/books/book.proto`
{% highlight proto %}
syntax = "proto3";
package books;

option go_package = ".;books";

{% endhighlight %}

All we're doing is declaring the package we're in & giving the `protoc` compiler a hint as to what go package we want to generate.

Now, to generate code with `book.proto` you will need to install `protoc`, the "Protocol Buffer Compiler".
You can [download protoc here](https://grpc.io/docs/protoc-installation/) or just run `brew install protoc` if you use HomeBrew.

Once you've installed `protoc`, Take it for a spin:

{% highlight bash %}
$ protoc pkg/pb/books/*.proto --go_out=plugins=grpc:pkg/pb/books
{% endhighlight %}

_(note that we've targeted where our .proto src files are, loaded in the grpc plugin so we can leverage protoc to
generate our grpc code as well as our protobuf messages, and then targeted our output directory)_

### Create entrypoints for our server & client

Next, let's create a couple of entrypoints for our server: `cmd/server/main.go` and client: `cmd/client/main.go` (again, we'll worry about them doing something interesting after we get our project structure squared away.)

`cmd/server/main.go` & `cmd/client/main.go`
{% highlight go %}
package main

import "fmt"

func main() {
	fmt.Println("Hello World")
}
	
{% endhighlight %}


### Leverage Make for build consistency

We haven't done anything too crazy here, but between our custom server and client locations & the `protoc` command,
getting our build steps down in a `Makefile` will make this more repeatable. Additionally, now other devs can jump
right in and don't need to learn how to build your project or worse: reverse engineer your build steps.

Bonus, now you can now just run `make` to nuke any old generated code, run tests,
and the build the project's server & client.


`Makefile`
{% highlight make %}
default: all

clean:
	rm -rf pkg/pb/books/*.pb.go

pb:
	protoc pkg/pb/books/*.proto --go_out=plugins=grpc:pkg/pb/books

go:
	go build -o ./books-grpc-poc-server ./cmd/server/main.go
	go build -o ./books-grpc-poc-client ./cmd/client/main.go


test: pb
	go test ./...

build: pb go

all: clean test build

{% endhighlight %}

try building the project & running the resulting artifacts:

{% highlight bash %}
$ make
rm -rf pkg/pb/books/*.pb.go
protoc pkg/pb/books/*.proto --go_out=plugins=grpc:pkg/pb/books
go test ./...
?       github.com/benschw/books-grpc-poc/cmd/client    [no test files]
?       github.com/benschw/books-grpc-poc/cmd/server    [no test files]
?       github.com/benschw/books-grpc-poc/pkg/pb/books  [no test files]
?       github.com/benschw/books-grpc-poc/pkg/pb/books/pkg/pb/books     [no test files]
go build -o ./books-grpc-poc-server ./cmd/server/main.go
go build -o ./books-grpc-poc-client ./cmd/client/main.go

$ ./books-grpc-poc-server
Hello World
$ ./books-grpc-poc-client
Hello World
{% endhighlight %}


Not very exciting, but with all the groundwork laid out we can iterate fast now..


## Unary RPC: AddBook

Since this is a "book" service, maybe the best place to start is to support adding books.



{% highlight go %}
{% endhighlight %}


