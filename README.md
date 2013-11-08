∅MQD – a ∅MQ wrapper for the D programming language
===================================================

∅MQD is a [D](http://dlang.org) library that wraps the low-level C API of
the [∅MQ](http://zeromq.org) messaging framework.  It is a rather thin
wrapper that maps closely to the C API, while making it safer, easier and
more pleasant to use.  Here's how:

  * Errors are signalled by means of exceptions rather than return codes.
  * Functions are appropriately marked with `@safe`/`@trusted`/`@system`,
    `pure` and `nothrow`.
  * Memory and resources (i.e. contexts, sockets and messages) are
    automatically managed, thus preventing leaks.
  * Context, socket and message options are implemented as properties.

The names of functions and types in ∅MQD are very similar to those in ∅MQ,
but they follow the D naming conventions.  For example, `zmq_msg_send()`
becomes `zmqd.Message.send()` and so on.  Thus, the library should feel
both familiar to ∅MQ users and natural to D users.

## Requirements ##

What you need is:

  * An up-to-date [D compiler](http://wiki.dlang.org/Compilers) (last
    tested with DMD 2.063)
  * The [∅MQ libraries](http://zeromq.org/intro:get-the-software)
  * The [∅MQ bindings](https://github.com/D-Programming-Deimos/ZeroMQ)
    from Deimos

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

    import core.thread, core.time, std.stdio;
    import zmqd;

    void main()
    {
        auto responder = Socket(SocketType.rep);
        responder.bind("tcp://*:5555");

        while (true) {
            char[10] buffer;
            responder.receive(buffer[]);
            writeln("Received Hello");
            Thread.sleep(seconds(1)); // Do some 'work'
            responder.send("World");
        }
    }

Note how `Socket` does not need a context, because the library creates a global
"default context", since this is what the majority of programs will do anyway.
Of course, if we wanted to, we could replace the first line of `main()` with
the following:

    auto context = Context();
    auto responder = Socket(context, SocketType.rep);

