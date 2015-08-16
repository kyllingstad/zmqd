∅MQD – a ∅MQ wrapper for the D programming language
===================================================

∅MQD is a [D](http://dlang.org) library that wraps the low-level C API of
the [∅MQ](http://zeromq.org) messaging framework (also known as ZeroMQ).
It is a rather thin wrapper that maps closely to the C API, while making it
safer, easier and more pleasant to use.  Here's how:

  * Errors are signalled by means of exceptions rather than return codes.
  * Functions are appropriately marked with `@safe`, `pure` and `nothrow`,
    thus facilitating their use in high-level D code.
  * Memory and resources (i.e. contexts, sockets and messages) are
    automatically managed, thus preventing leaks.
  * Context, socket and message options are implemented as properties.

The names of functions and types in ∅MQD are very similar to those in ∅MQ,
but they follow the D naming conventions.  Thus, the library should feel
both familiar to ∅MQ users and natural to D users.

The API documentation may be browsed online at
http://kyllingstad.github.io/zmqd/.

## Terms of use ##

∅MQD is free and open-source software, released under the terms of the
[Mozilla Public License v. 2.0](http://mozilla.org/MPL/2.0/).  This allows
you to mix it with other files under a different, even proprietary licence.
However, the source code files of ∅MQD itself, and any modifications you make
to them,  must remain under the MPL and freely available in source form.  For
more information, see Mozilla's MPL [FAQ](http://www.mozilla.org/MPL/2.0/FAQ.html).

## Support and contributions ##

If you have questions, enhancement requests or bug reports, please submit
them as [issues](https://github.com/kyllingstad/zmqd/issues) on GitHub.
Bug fixes in the form of [pull requests](https://github.com/kyllingstad/zmqd/pulls)
are very welcome.

## Requirements ##

What you need is:

  * A somewhat up-to-date [D compiler](http://wiki.dlang.org/Compilers)
  * The [∅MQ libraries](http://zeromq.org/intro:get-the-software) v4.x
  * The [∅MQ C library bindings](https://github.com/D-Programming-Deimos/ZeroMQ)
    from Deimos.

Tell the compiler where to find the libraries and the import files, and
you're good to go.

It is of course also possible to use [Dub](http://code.dlang.org/) to install
[the zmqd package](http://code.dlang.org/packages/zmqd) and its dependencies,
or to use it to build ∅MQD from source.

### A word of caution about the C library bindings ###

As mentioned, you need the
[∅MQ C bindings](https://github.com/D-Programming-Deimos/ZeroMQ) to be able
to build and use ∅MQD.  If you use Dub, a compatible version of the C
library bindings will automatically be fetched.  However, this is
not not necessarily compatible with the ∅MQ *library* version you have
installed.  There are known ABI incompatibilities between different versions
of ∅MQ (different minor versions, even) so it is a good idea to make sure
these match.  With Dub, the appropriate version of the ∅MQ bindings can be
selected by modifying the file `dub.selections.json` (package `zeromq`).
If you build manually, make sure to check out the correct version from
[the repository](https://github.com/D-Programming-Deimos/ZeroMQ) (it has
version number tags).

To help detect incompatibilities, the ∅MQD unittests include a simple
compatibility check which warns about possible problems.  The simplest way
to run the tests is to use Dub, as follows:

    dub test zmqd

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
