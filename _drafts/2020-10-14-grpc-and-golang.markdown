---
layout: post
status: publish
published: true
title: gRPC with Golang
categories:
- Post
tags: []
---


This post will walk through using [Protocol Buffers](https://developers.google.com/protocol-buffers)
& [gRPC](https://grpc.io/) to create a microservice (and a cli client that interacts with it)
for managing books using [Go](https://golang.org/).

<!--more-->

We will walk through:

* Setting up a basic "books" microservice project leveraging gRPC for communication
* Adding an Unary RPC call to our service (`AddBook`)
* Adding a Server Side Streaming RPC call (`FindBooks`)
* Adding a Client Side Streaming RPC call (`BulkAddBooks`)
* Refactoring the Client Site Streaming RPC call to be Bidirectional (Update to the `BulkAddBooks` call)

Along the way, we will be building a cli client to communicate with out service as well as writing automated
tests for it.

The final demo project can be found [on github here](https://github.com/benschw/books-grpc-poc), and
I will link to branches that show the progress as we layer on functionality along the way.

* TOC
{:toc}

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
_You can browse to the `basic` branch of the [demo repo](https://github.com/benschw/books-grpc-poc/tree/basic) to
view the books service with the full implementation of the `AddBook` call. The snippets below are abbreviated for clarity._

Since this is a "book" service, maybe the best place to start is to support adding books.

### Protobuf src
`pkg/pb/books/book.proto` [(src)](https://github.com/benschw/books-grpc-poc/blob/basic/pkg/pb/books/book.proto)
{% highlight proto %}
syntax = "proto3";
package books;

option go_package = ".;books";

message Book {
  uint64 id = 1;
  string title = 2;
  string author = 3;
}

service BookService {
  rpc AddBook(Book) returns (Book) {}
}
{% endhighlight %}

### Server Entrypoint: main.go

`cmd/server/main.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/basic/cmd/server/main.go)
{% highlight go %}

func main() {

	repo := fakes.NewRepo()

	lis, err := net.Listen("tcp", "localhost:9000")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}
	s := app.NewServer(repo)

	grpcServer := grpc.NewServer()

	books.RegisterBookServiceServer(grpcServer, s)

	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %s", err)
	}

}
{% endhighlight %}

### gRPC Server Implementation for AddBook

`internal/app/server.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/basic/internal/app/server.go)
{% highlight go %}

type Server struct {
	repo internal.Repo
}

func NewServer(repo internal.Repo) *Server {
	return &Server{repo: repo}
}

func (s *Server) AddBook(ctx context.Context, new *books.Book) (*books.Book, error) {
	return s.repo.Create(new)
}
{% endhighlight %}

_see also: [internal.Repo](https://github.com/benschw/books-grpc-poc/blob/basic/internal/types.go) and  [fakes.Repo](https://github.com/benschw/books-grpc-poc/blob/basic/internal/fakes/repo.go) in the demo repo_


### Client Entrypoint: main.go

`cmd/client/main.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/basic/cmd/client/main.go)
{% highlight go %}

var (
	cmd = flag.String("cmd", "", "The client command to run (add)")
	author = flag.String("author", "", "author value for adding a book")
	title = flag.String("title", "", "title value for adding a book")
)

func main() {

	flag.Parse()

	var conn *grpc.ClientConn
	conn, err := grpc.Dial("localhost:9000", grpc.WithInsecure())
	if err != nil {
		log.Fatalf("did not connect: %s", err)
	}
	defer conn.Close()

	c := books.NewBookServiceClient(conn)

	switch *cmd {
	case "add":
		if err := Add(c, *author, *title); err != nil {
			log.Fatalf("add - error adding book: %s", err)
		}
		break;
	default:
		log.Fatalf("unknown command: %s", *cmd)
	}
}

func Add(c books.BookServiceClient, author string, title string) error {
	newBook := &books.Book{Author: author, Title: title}
	book, err := c.AddBook(context.Background(), newBook)
	if err != nil {
		return err
	}
	fmt.Printf("Book Added: %v\n", book)
	return nil
}

{% endhighlight %}

### Testing AddBook

`internal/app/server_test.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/basic/internal/app/server_test.go)
{% highlight go %}
func dialer() func(context.Context, string) (net.Conn, error) {
	lis := bufconn.Listen(1024 * 1024)

	s := grpc.NewServer()

	repo := fakes.NewRepo()

	books.RegisterBookServiceServer(s, NewServer(repo))

	go func() {
		if err := s.Serve(lis); err != nil {
			log.Fatal(err)
		}
	}()

	return func(context.Context, string) (net.Conn, error) {
		return lis.Dial()
	}
}

func getConn(ctx context.Context) *grpc.ClientConn {
	conn, err := grpc.DialContext(ctx, "", grpc.WithInsecure(), grpc.WithContextDialer(dialer()))
	if err != nil {
		log.Fatal(err)
	}
	return conn
}

func TestServer_AddBook(t *testing.T) {
	// given
	ctx := context.Background()
	conn := getConn(ctx)
	defer conn.Close()

	client := books.NewBookServiceClient(conn)

	newBook := &books.Book{Author: "Bob Loblaw", Title: "Law Blog"}

	// when
	createdBook, err := client.AddBook(ctx, newBook)

	// then
	assert.Nil(t, err)

	er, _ := status.FromError(err);
	assert.Equal(t, codes.OK, er.Code())

	assert.Equal(t, newBook.GetAuthor(), createdBook.GetAuthor())
	assert.Equal(t, newBook.GetTitle(), createdBook.GetTitle())
}
{% endhighlight %}

### Try it out
{% highlight bash %}

{% endhighlight %}

## Server Side Streaming: FindAllBooks

### Protobuf src

`pkg/pb/books/book.proto` [(src)](https://github.com/benschw/books-grpc-poc/blob/server-streaming/pkg/pb/books/book.proto)
{% highlight proto %}
syntax = "proto3";
package books;

option go_package = ".;books";

message Book {
  uint64 id = 1;
  string title = 2;
  string author = 3;
}

message BookQuery {
  string author = 2;
}

service BookService {
  rpc AddBook(Book) returns (Book) {}
  rpc FindAllBooks(BookQuery) returns (stream Book) {}
}
{% endhighlight %}

No changes are neaded for `cmd/server/main.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/server-streaming/cmd/server/main.go)

### gRPC Server Implementation for FindAllBooks

`internal/app/server.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/server-streaming/internal/app/server.go)
{% highlight go %}
func (s *Server) FindAllBooks(query *books.BookQuery, stream books.BookService_FindAllBooksServer) error {
	books, err := s.repo.FindAll(query)
	if err != nil {
		return err
	}
	for _, book := range books {
		stream.Send(book)
	}
	return nil
}
{% endhighlight %}


### Client support for `-cmd list`

`cmd/client/main.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/server-streaming/cmd/client/main.go)
{% highlight go %}
func main() {
	// ...

	switch *cmd {
	// ...
	case "list":
		if err := List(c, *author); err != nil {
			log.Fatalf("list - error listing books: %s", err)
		}
		break;
	default:
		log.Fatalf("unknown command: %s", *cmd)
	}
}

func Add(c books.BookServiceClient, author string, title string) error {
	//...
}

func List(c books.BookServiceClient, author string) error {
	bookStream, err := c.FindAllBooks(context.Background(), &books.BookQuery{Author: author})
	if err != nil {
		return err
	}
	for {
		book, err := bookStream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		fmt.Printf("%v\n", book)
	}
	return nil
}

{% endhighlight %}

### Testing FindAllBooks

`internal/app/server_test.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/server-streaming/internal/app/server_test.go)
{% highlight go %}
// ...
func TestServer_FindAllBook(t *testing.T) {
	// given
	ctx := context.Background()
	conn := getConn(ctx)
	defer conn.Close()

	client := books.NewBookServiceClient(conn)

	book1, err := client.AddBook(ctx, &books.Book{Author: "Bob Loblaw", Title: "Law Blog"})
	book2, err := client.AddBook(ctx, &books.Book{Author: "Bob Loblaw", Title: "Law Blog"})

	// when
	found, err := client.FindAllBooks(ctx, &books.BookQuery{})
	found1, err1 := found.Recv()
	found2, err2 := found.Recv()
	_, err3 := found.Recv()

	// then
	assert.Nil(t, err)
	assert.Nil(t, err1)
	assert.Nil(t, err2)
	assert.Equal(t, io.EOF, err3)

	er, _ := status.FromError(err);
	assert.Equal(t, codes.OK, er.Code())

	assert.Equal(t, book1.GetId(), found1.GetId())
	assert.Equal(t, book1.GetAuthor(), found1.GetAuthor())
	assert.Equal(t, book1.GetTitle(), found1.GetTitle())

	assert.Equal(t, book2.GetId(), found2.GetId())
	assert.Equal(t, book2.GetAuthor(), found2.GetAuthor())
	assert.Equal(t, book2.GetTitle(), found2.GetTitle())
}
{% endhighlight %}

### Try it out
{% highlight bash %}

{% endhighlight %}

## Client Side Streaming: BulkAddBooks

### Protobuf src

`pkg/pb/books/book.proto` [(src)](https://github.com/benschw/books-grpc-poc/blob/client-streaming/pkg/pb/books/book.proto)
{% highlight proto %}
syntax = "proto3";
package books;

option go_package = ".;books";

message Book {
  uint64 id = 1;
  string title = 2;
  string author = 3;
}

message BookQuery {
  string author = 2;
}

message BulkResponse {
  string reply = 1;
}

service BookService {
  rpc AddBook(Book) returns (Book) {}
  rpc FindAllBooks(BookQuery) returns (stream Book) {}
  rpc BulkAddBooks(stream Book) returns (BulkResponse) {}
}
{% endhighlight %}

### gRPC Server Implementation for BulkAddBooks (client side streaming)

`internal/app/server.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/client-streaming/internal/app/server.go)
{% highlight go %}
// ...

func (s *Server) BulkAddBooks(in books.BookService_BulkAddBooksServer) error {
	added := 0
	for {
		book, err := in.Recv()
		if err == io.EOF {
			return in.SendAndClose(&books.BulkResponse{
				Reply: fmt.Sprintf("added %d books", added),
			})
		}
		if err != nil {
			return err
		}
		_, err = s.repo.Create(book)
		if err != nil {
			return err
		}
		added++
	}
}
{% endhighlight %}

### Testing BulkAddBooks
Since in the next section we're going to refactor BulkAddBooks to use bidirectional streaming, I didn't bother
with the client cli implementation - so refer to the below test code to see how it would be implemented.

`internal/app/server_test.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/client-streaming/internal/app/server_test.go)
{% highlight go %}
// ...
func TestServer_BulkAddBooks(t *testing.T) {
	// given
	ctx := context.Background()
	conn := getConn(ctx)
	defer conn.Close()

	client := books.NewBookServiceClient(conn)

	input := []*books.Book{
		&books.Book{Author: "Bob Loblaw1", Title: "Law Blog1"},
		&books.Book{Author: "Bob Loblaw2", Title: "Law Blog2"},
		&books.Book{Author: "Bob Loblaw3", Title: "Law Blog3"},
		&books.Book{Author: "Bob Loblaw4", Title: "Law Blog4"},
		&books.Book{Author: "Bob Loblaw5", Title: "Law Blog5"},
	}
	// when
	stream, err := client.BulkAddBooks(ctx)
	assert.Nil(t, err)

	for _, in := range(input) {
		err = stream.Send(in)
		assert.Nil(t, err)
	}

	reply, err := stream.CloseAndRecv()
	assert.Nil(t, err)

	// then
	found, _ := client.FindAllBooks(ctx, &books.BookQuery{})
	foundBooks := []*books.Book{}
	for {
		fb, err := found.Recv()
		if err == io.EOF {
			break
		}
		foundBooks = append(foundBooks, fb)
	}

	assert.Equal(t, "added 5 books", reply.GetReply())
	assert.Equal(t, len(input), len(foundBooks))

	for i, in := range(input) {
		assert.Equal(t, in.GetAuthor(), foundBooks[i].GetAuthor())
		assert.Equal(t, in.GetTitle(), foundBooks[i].GetTitle())
	}
}
{% endhighlight %}

### Try it out
{% highlight bash %}

{% endhighlight %}

## Bidirectional Streaming: BulkAddBooks (refactored)

### Protobuf src

`pkg/pb/books/book.proto` [(src)](https://github.com/benschw/books-grpc-poc/blob/bidirectional-streaming/pkg/pb/books/book.proto)
{% highlight proto %}
syntax = "proto3";
package books;

option go_package = ".;books";

message Book {
  uint64 id = 1;
  string title = 2;
  string author = 3;
}

message BookQuery {
  string author = 2;
}

service BookService {
  rpc AddBook(Book) returns (Book) {}
  rpc FindAllBooks(BookQuery) returns (stream Book) {}
  rpc BulkAddBooks(stream Book) returns (stream Book) {}
}{% endhighlight %}

### gRPC Server Implementation for BulkAddBooks (bidirectional streaming)

`internal/app/server.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/bidirectional-streaming/internal/app/server.go)
{% highlight go %}
// ...
func (s *Server) BulkAddBooks(stream books.BookService_BulkAddBooksServer) error {
	for {
		in, err := stream.Recv()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		book, err := s.repo.Create(in)
		if err := stream.Send(book); err != nil {
			return err
		}
	}
}

{% endhighlight %}

### Client support for bulk loading books
This implementation got a little involved, so I decided to make a standalone client rather than packing it into our existing cli.
The [full client code](https://github.com/benschw/books-grpc-poc/blob/bidirectional-streaming/cmd/bulk_load_client/main.go) takes
the path to an RDF catalog (like the ones provided on [Project Gutenberg](https://www.gutenberg.org/ebooks/offline_catalogs.html)),
parses it, and then feeds all the books into our server. Below, I've only included the gRPC client code.


`cmd/bulk_load_client/main.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/bidirectional-streaming/cmd/bulk_load_client/main.go)
{% highlight go %}
func BulkLoad(client books.BookServiceClient, entries RDF) error {

	stream, err := client.BulkAddBooks(context.Background())
	if err != nil {
		return err
	}

	done := make(chan bool)

	go func() {
		m := make(map[string]int)
		for {
			c, err := stream.Recv()
			if err == io.EOF {
				for k,v := range m {
					fmt.Printf("%d books by %s\n", v, k)
				}
				close(done)
				return
			}
			if err != nil {
				log.Fatalf("can not receive %v", err)
				continue
			}
			if _, ok := m[c.Author]; !ok {
				m[c.Author] = 0;
			}
			m[c.Author]++
		}
	}()

	for _, entry := range(entries.EText) {
		if err := stream.Send(&books.Book{Author: entry.Creator, Title: entry.Title}); err != nil {
			log.Fatalf("can not send %v", err)
		}
	}

	err = stream.CloseSend()
	<-done
	return err
}

{% endhighlight %}


### Testing BulkAddBooks

`internal/app/server_test.go` [(src)](https://github.com/benschw/books-grpc-poc/blob/bidirectional-streaming/internal/app/server_test.go)
{% highlight go %}
// ...
func TestServer_BulkAddBooks(t *testing.T) {
	// given
	ctx := context.Background()
	conn := getConn(ctx)
	defer conn.Close()

	client := books.NewBookServiceClient(conn)

	input := []*books.Book{
		&books.Book{Author: "Bob Loblaw1", Title: "Law Blog1"},
		&books.Book{Author: "Bob Loblaw2", Title: "Law Blog2"},
		&books.Book{Author: "Bob Loblaw3", Title: "Law Blog3"},
		&books.Book{Author: "Bob Loblaw4", Title: "Law Blog4"},
		&books.Book{Author: "Bob Loblaw5", Title: "Law Blog5"},
	}
	// when
	stream, err := client.BulkAddBooks(ctx)
	assert.Nil(t, err)

	ch := make(chan *books.Book, 2)

	go func() {
		for {
			c, err := stream.Recv()
			if err == io.EOF {
				close(ch)
				return
			}
			assert.Nil(t, err)
			ch <- c
		}
	}()

	for _, in := range(input) {
		err = stream.Send(in)
		assert.Nil(t, err)
	}

	err = stream.CloseSend()

	// then

	assert.Nil(t, err)
	i := 0
	for in := range ch {
		assert.Equal(t, input[i].GetAuthor(), in.GetAuthor())
		assert.Equal(t, input[i].GetTitle(), in.GetTitle())
		i++
	}
	assert.Equal(t, len(input), i)
}

{% endhighlight %}

### Try it out
first download `catalog.rdf`
{% highlight bash %}
wget -qO- "https://www.gutenberg.org/cache/epub/feeds/catalog.rdf.zip" | tar xOvz -
{% endhighlight %}

now we can bulk-add all books found in Project Gutenburg (and see the summary of how many books by author were included):
{% highlight bash %}
go run cmd/bulk_load_client/main.go -input ./catalog.rdf
#...
1 books by Association, American Railway
1 books by Deignan, H. G.
5 books by Haydn, Joseph, 1732-1809
1 books by Showerman, Grant, 1870-1935
1 books by Hoyt, Deristhe L. (Deristhe Levinte)
1 books by Clemens, William Alvin
{% endhighlight %}
