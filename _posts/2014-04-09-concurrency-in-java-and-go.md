---
layout: post
title: Concurrency in Java and Go
---


Here is an attempt to discuss the differences between concurrency and parallelism in Java and Go. In the process I discuss the importance of (without weighing in on) concurrency to the design of your application.

<!--more-->

*_Disclamer:_* I'm no expert! if there are mistakes or omissions, please comment. Better yet, [submit a pull request](https://github.com/benschw/benschw.github.io); this is all on github.

## Concurrency vs Parallelism

To understand concurrency, it makes sense to first distinguish between concurrency and parallelism.
Parallelism is about leveraging the _simultaneous_ execution of work to _perform_ a bunch of things at once. Concurrency is about the _composition_ of work to _manage_ a bunch of things at once.

Parallelism is essentially capped to the number of cpus you have; so if you have a quad core i7 with multi-threading, you are limited to running 8 units of work in parallel. Since concurrency is just about the composition of your work, there are no technical limits, just what makes sense for your design.

## Concurrency in Java and Go

Four tools (by no means an exhaustive list) for managing concurrency are processes, threads, green threads, and goroutines.

- *Processes:* Processes are OS managed and each is allocated it's own address space (or context).
- *Threads:* Threads are OS managed but share an address space (or context) with other threads running in the same process.
- *Green Threads:* Green Threads are user-space managed (not OS managed) implementations of the "thread" concept.
- *Goroutines:* Goroutines are user-space managed and are multiplexed onto a pool of OS threads managed by the language's runtime.

Java uses OS threads to perform parallel executions of work while Go uses (you guessed it) goroutines. This means they are very similar when it comes to parallelization because both languages execute their units of work on OS threads. There are however drastic distinctions between their concurrency models.

If concurrency is the design or composition of simultaneous work, then we also need to talk about synchronization. By synchronization, i mean: how do the units of work running concurrently in your system synchronize with each other to communicate about their work?

- Java: Objects are shared between units of work. When a unit of work accesses this piece of shared data, it must first obtain a lock on it using the entity's _intrinsic lock_ (or _monitor lock_.)
- Go: Channels are shared between units of work. A channel is essentially a (optionally buffered) FIFO pipe. A unit of work may read or write to a channel.

Java has solved the problem of synchronizing between units of work by providing an mechanism to synchronize access to memory shared between the units of work. This is effective and allows for the use of many design patterns developers are already used to from non-concurrent programming. 

Go has solved the problem of synchronizing between units of work by re-framing the problem: Communicate over shared channels and synchronized access is not necessary.

In [Effective Go*](http://golang.org/doc/effective_go.html#sharing) this is concisely explained with: _"Do not communicate by sharing memory; instead, share memory by communicating."_


## Performance and Design

As I intimated earlier, since both goroutines and Java threads are executed as OS threads, they are similarly performant when executing parallel units of work. Their implementation differences however lead to much different performances when implementing a highly concurrent design.

Java's concurrency model necessitates worrying about performance when designing a concurrent application. You need to do things like allocate thread pools or divide your work load into a _reasonable_ number of threads to minimize the overhead of creating new threads. 

Go on the other hand tracks concurrent units of work in goroutines (a language level construct) and multiplexes them onto OS threads as it sees most efficient. Since virtually the only expense of spawning a new goroutine is the allocation of stack space, the developer can focus on an optimal concurrency design without worrying about the performance implications of the wrong number (too many or too few) of concurrent units. 


## Brain Candy
An example is worth a thousand words...

### Sieve of Eratosthenes (prime numbers)
I got this example [here](http://scienceblogs.com/goodmath/2009/11/13/the-go-i-forgot-concurrency-an/)

	package main

	import (
		"flag"
		"runtime"
	)

	/**
	 * Implementation of `Sieve of Eratosthenes` algorithm
	 * starting with first prime (2)...
	 * - eliminate its multiples
	 * - next un-eliminated number is the next prime
	 * - (repeat)
	 *
	 * http://en.wikipedia.org/wiki/Sieve_of_Eratosthenes
	 */
	func main() {
		nCPU := runtime.NumCPU()
		runtime.GOMAXPROCS(nCPU)

		var primes int

		flag.IntVar(&primes, "primes", 10, "prime numbers to output")
		flag.Parse()

		ch := make(chan int)
		defer close(ch)

		go Generate(ch)
		for i := 0; i < primes; i++ {
			prime := <-ch
			print(prime, "\n")
			ch1 := make(chan int)
			go Filter(ch, ch1, prime)
			ch = ch1
		}
	}

	func Generate(ch chan<- int) {
		for i := 2; ; i++ {
			ch <- i
		}
	}

	func Filter(in <-chan int, out chan<- int, prime int) {
		for {
			i := <-in
			if i%prime != 0 {
				out <- i
			}
		}
	}

### Gregory-Leibniz series (π)

	package main

	import (
		"flag"
		"fmt"
		"runtime"
	)

	/**
	 * launches n goroutines to compute an approximation of pi.
	 * 3 + 4/2*3*4 - 4/4*5*6 + 4/6*7*8 - 4/8*9*10 ...
	 */
	func main() {
		nCPU := runtime.NumCPU()
		runtime.GOMAXPROCS(nCPU)

		var terms int

		flag.IntVar(&terms, "terms", 10, "terms to calculate to approximate pi")
		flag.Parse()

		ch := make(chan float64)
		defer close(ch)
		go term(ch, 1, terms)

		pi := 3.0
		for i := 1; i <= terms; i++ {
			pi += <-ch
		}

		fmt.Print(pi, "\n")
	}

	func term(ch chan float64, termIdx int, terms int) {
		if termIdx != terms {
			go term(ch, termIdx+1, terms)
		}
		base := float64(termIdx*4 - 2)

		term := 4 / (base * (base + 1) * (base + 2))
		term += -4 / ((base + 2) * (base + 3) * (base + 4))
		ch <- term
	}

### Fibonacci Series

	package main

	import (
		"flag"
		"runtime"
	)

	/**
	 * 1, 1, 2, 3, 5, 8, ...
	 */
	func main() {
		nCPU := runtime.NumCPU()
		runtime.GOMAXPROCS(nCPU)

		var terms int

		flag.IntVar(&terms, "terms", 10, "sequence terms to output")
		flag.Parse()

		c := make(chan int64)
		defer close(c)

		go fib(c, 1, 1)

		for i := 0; i < terms; i++ {
			x := <-c
			print(x, "\n")
		}
	}

	func fib(c chan int64, a int64, b int64) {
		c <- a
		go fib(c, b, a+b)
	}
