∅MQD – a ∅MQ wrapper for the D programming language
===================================================

∅MQD is a [D](http://dlang.org) library that wraps the low-level C API of
the [∅MQ](http://zeromq.org) messaging framework (also known as ZeroMQ).
It is a rather thin wrapper that maps closely to the C API, while making it
safer, easier and more pleasant to use.  Here's how:

  * Errors are signalled by means of exceptions rather than return codes.
  * Functions are appropriately marked with `@safe`/`@trusted`/`@system`,
    `pure` and `nothrow`.
  * Memory and resources (i.e. contexts, sockets and messages) are
    automatically managed, thus preventing leaks.
  * Context, socket and message options are implemented as properties.

The names of functions and types in ∅MQD are very similar to those in ∅MQ,
but they follow the D naming conventions.  Thus, the library should feel
both familiar to ∅MQ users and natural to D users.

The API documentation may be browsed online at
http://kyllingstad.github.io/zmqd/.

## Support and contributions ##

If you have questions, enhancement requests or bug reports, please submit
them as [issues](https://github.com/kyllingstad/zmqd/issues) on GitHub.
Bug fixes in the form of [pull requests](https://github.com/kyllingstad/zmqd/pulls)
are very welcome.

## Requirements ##

What you need is:

  * A somewhat up-to-date [D compiler](http://wiki.dlang.org/Compilers)
  * The [∅MQ libraries](http://zeromq.org/intro:get-the-software)
  * The [∅MQ bindings](https://github.com/D-Programming-Deimos/ZeroMQ) from
    Deimos (the correct version is automatically fetched if you use
    [Dub](http://code.dlang.org/)).

Tell the compiler where to find the libraries and the import files, and
you're good to go.

## Example: Hello World server ##

The C implementation of the "Hello World server" from the
[∅MQ Guide](http://zguide.zeromq.org/page:all) looks like this:

    // Hello World server

    #include <zmq.h>
    #include <stdio.h>
    #include <unistd.h>
    #include <string.h>
    #include <assert.h>

    int main (void)
    {
        // Socket to talk to clients
        void *context = zmq_ctx_new ();
        void *responder = zmq_socket (context, ZMQ_REP);
        int rc = zmq_bind (responder, "tcp://*:5555");
        assert (rc == 0);

        while (1) {
            char buffer [10];
            zmq_recv (responder, buffer, 10, 0);
            printf ("Received Hello\n");
            sleep (1); // Do some 'work'
            zmq_send (responder, "World", 5, 0);
        }
        return 0;
    }

The equivalent ∅MQD program looks like this:

	import core.thread, core.time;
	import std.stdio;
	import zmqd;

	void main()
	{
	    // Socket to talk to clients
	    auto responder = Socket(SocketType.rep);
	    responder.bind("tcp://*:5555");

	    while (true) {
	        ubyte[10] buffer;
	        responder.receive(buffer);
	        writeln("Received Hello");
	        Thread.sleep(1.seconds);
	        responder.send("World");
	    }
	}

Note how `Socket` does not need a context, because the library creates a global
"default context", since this is what the majority of programs will do anyway.
Of course, if we wanted to, we could replace the first line of `main()` with
the following:

    auto context = Context();
    auto responder = Socket(context, SocketType.rep);

More examples may be found in the `examples` subdirectory.
