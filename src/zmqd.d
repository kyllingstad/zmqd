/**
A thin wrapper around the low-level C API of the $(LINK2 http://zeromq.org,$(ZMQ))
messaging framework, for the $(LINK2 http://dlang.org,D programming language).

Most functions in this module have a one-to-one relationship with functions
in the underlying C API.  Some adaptations have been made to make the API
safer, easier and more pleasant to use, namely:
$(UL
    $(LI
        Errors are signalled by means of exceptions rather than return
        codes.  In particular, the $(REF ZmqException) class provides
        a standard textual message for any error condition, but it also
        provides access to the $(D errno) code set by the C function
        that reported the error.)
    $(LI
        Functions are appropriately marked with $(D @safe), $(D pure)
        and $(D nothrow), thus easing their use in high-level D code.)
    $(LI
        Memory and resources (i.e. contexts, sockets and messages) are
        automatically managed, thus preventing leaks.)
    $(LI
        Context, socket and message options are implemented as properties.)
)
The names of functions and types in $(ZMQD) are very similar to those in
$(ZMQ), but they follow the D naming conventions.  For example,
$(D zmq_msg_send()) becomes $(D zmqd.Message.send()) and so on.  Thus,
the library should feel both familiar to $(ZMQ) users and natural to D
users.

Due to the close correspondence with the C API, this documentation has
intentionally been kept sparse. There is really no reason to repeat the
contents of the $(ZMQAPI __start,$(ZMQ) reference manual) here.
Instead, the documentation for each function contains a "Corresponds to"
section that links to the appropriate page in the $(ZMQ) reference.  Any
details given in the present documentation mostly concern the D-specific
adaptations that have been made.

Also note that the examples only use the INPROC and IPC transports.  The
reason for this is that the examples double as unittests, and we want to
avoid firewall troubles and other issues that could arise with the use of
network protocols such as TCP, PGM, etc.  Anyway, they are only short
snippets that demonstrate the syntax; for more comprehensive and realistic
examples, please refer to the $(LINK2 http://zguide.zeromq.org/page:all,
$(ZMQ) Guide).

Version:
    0.4 ($(ZMQ) 3.2 compatible)
Authors:
    $(LINK2 http://github.com/kyllingstad,Lars T. Kyllingstad)
Copyright:
    Copyright (c) 2013–2014, Lars T. Kyllingstad. All rights reserved.
License:
    $(ZMQD) is released under a BSD licence (see LICENCE.txt for details).$(BR)
    Please refer to the $(LINK2 http://zeromq.org/area:licensing,$(ZMQ) site)
    for details about $(ZMQ) licensing.
Macros:
    D      = <code>$0</code>
    EM     = <em>$0</em>
    LDOTS  = &hellip;
    QUOTE  = <blockquote>$0</blockquote>
    FREF   = $(D $(LINK2 #$1,$1()))
    REF    = $(D $(LINK2 #$1,$1))
    COREF  = $(D $(LINK2 http://dlang.org/phobos/core_$1.html#.$2,core.$1.$2))
    STDREF = $(D $(LINK2 http://dlang.org/phobos/std_$1.html#.$2,std.$1.$2))
    ZMQ    = &#x2205;MQ
    ZMQAPI = $(LINK2 http://api.zeromq.org/3-2:$1,$+)
    ZMQD   = $(ZMQ)D
    ZMQREF = $(D $(ZMQAPI $1,$1))
*/
module zmqd;

import core.time;
import std.typecons;
import deimos.zmq.zmq;


version(Windows) {
    import std.c.windows.winsock: SOCKET;
}


@safe:


/**
Reports the $(ZMQ) library version.

Returns:
    A $(STDREF typecons,Tuple) with three integer fields that represent the
    three versioning levels: $(D major), $(D minor) and $(D patch).
Corresponds_to:
    $(ZMQREF zmq_version())
*/
Tuple!(int, "major", int, "minor", int, "patch") zmqVersion() nothrow
{
    typeof(return) v;
    trusted!zmq_version(&v.major, &v.minor, &v.patch);
    return v;
}


/**
An object that encapsulates a $(ZMQ) context.

In most programs, it is not necessary to use this type directly,
as $(REF Socket) will use a default global context if not explicitly
provided with one.  See $(FREF defaultContext) for details.

A default-initialized $(D Context) is not a valid $(ZMQ) context; it
must always be explicitly initialized with $(FREF _Context.opCall):
---
Context ctx;        // Not a valid context yet
ctx = Context();    // ...but now it is.
---
$(D Context) objects can be passed around by value, and two copies will
refer to the same context.  The underlying context is managed using
reference counting, so that when the last copy of a $(D Context) goes
out of scope, the context is automatically destroyed.

See_also:
    $(FREF defaultContext)
*/
struct Context
{
@safe:
    /**
    Creates a new $(ZMQ) context.

    Returns:
        A $(REF Context) object that encapsulates the new context.
    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_ctx_new())
    */
    static Context opCall()
    {
        if (auto c = trusted!zmq_ctx_new()) {
            Context ctx;
            ctx.m_resource = Resource(c, &zmq_ctx_destroy);
            return ctx;
        } else {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        auto ctx = Context();
        assert (ctx.initialized);
    }

    /**
    Destroys the $(ZMQ) context.

    It is normally not necessary to do this manually, as the context will
    be destroyed automatically when the last reference to it goes out of
    scope.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_ctx_destroy())
    */
    void destroy()
    {
        m_resource.free();
    }

    ///
    unittest
    {
        auto ctx = Context();
        assert (ctx.initialized);
        ctx.destroy();
        assert (!ctx.initialized);
    }

    /**
    The number of I/O threads.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_ctx_get()) and $(ZMQREF zmq_ctx_set()) with
        $(D ZMQ_IO_THREADS).
    */
    @property int ioThreads()
    {
        return getOption(ZMQ_IO_THREADS);
    }

    /// ditto
    @property void ioThreads(int value)
    {
        setOption(ZMQ_IO_THREADS, value);
    }

    ///
    unittest
    {
        auto ctx = Context();
        ctx.ioThreads = 3;
        assert (ctx.ioThreads == 3);
    }

    /**
    The maximum number of sockets.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_ctx_get()) and $(ZMQREF zmq_ctx_set()) with
        $(D ZMQ_MAX_SOCKETS).
    */
    @property int maxSockets()
    {
        return getOption(ZMQ_MAX_SOCKETS);
    }

    /// ditto
    @property void maxSockets(int value)
    {
        setOption(ZMQ_MAX_SOCKETS, value);
    }

    ///
    unittest
    {
        auto ctx = Context();
        ctx.maxSockets = 512;
        assert (ctx.maxSockets == 512);
    }

    /**
    The $(D void*) pointer used by the underlying C API to refer to the context.

    If the object has not been initialized, this function returns $(D null).
    */
    @property inout(void)* handle() inout pure nothrow
    {
        return m_resource.handle;
    }

    /**
    Whether this $(REF Context) object has been _initialized, i.e. whether it
    refers to a valid $(ZMQ) context.
    */
    @property bool initialized() const pure nothrow
    {
        return m_resource.initialized;
    }

    ///
    unittest
    {
        Context ctx;
        assert (!ctx.initialized);
        ctx = Context();
        assert (ctx.initialized);
        ctx.destroy();
        assert (!ctx.initialized);
    }

private:
    int getOption(int option)
    {
        immutable value = trusted!zmq_ctx_get(m_resource.handle, option);
        if (value < 0) {
            throw new ZmqException;
        }
        return value;
    }

    void setOption(int option, int value)
    {
        if (trusted!zmq_ctx_set(m_resource.handle, option, value) != 0) {
            throw new ZmqException;
        }
    }

    Resource m_resource;
}


/**
A global context which is used by default by all sockets, unless they are
explicitly constructed with a different context.

The $(ZMQ) Guide $(LINK2 http://zguide.zeromq.org/page:all#Getting-the-Context-Right,
has the following to say) about context creation:
$(QUOTE
    You should create and use exactly one context in your process.
    [$(LDOTS)] If at runtime a process has two contexts, these are
    like separate $(ZMQ) instances. If that's explicitly what you
    want, OK, but otherwise remember: $(EM Do one $(D zmq_ctx_new())
    at the start of your main line code, and one $(D zmq_ctx_destroy())
    at the end.)
)
By using $(D defaultContext()), this is exactly what you achieve.  The
context is created the first time the function is called, and is
automatically destroyed when the program ends.

This function is thread safe.

Throws:
    $(REF ZmqException) if $(ZMQ) reports an error.
See_also:
    $(REF Context)
*/
Context defaultContext() @trusted
{
    // For future reference: This is the low-lock singleton pattern. See:
    // http://davesdprogramming.wordpress.com/2013/05/06/low-lock-singletons/
    static bool instantiated;
    __gshared Context ctx;
    if (!instantiated) {
        synchronized {
            if (!ctx.initialized) {
                ctx = Context();
            }
            instantiated = true;
        }
    }
    return ctx;
}

unittest
{
    auto c1 = defaultContext();
    auto c2 = defaultContext();
    assert(c1.handle !is null);
    assert(c1.handle == c2.handle);
}


/**
The various socket types.

These are described in the $(ZMQREF zmq_socket()) reference.
*/
enum SocketType
{
    req     = ZMQ_REQ,      /// Corresponds to $(D ZMQ_REQ)
    rep     = ZMQ_REP,      /// Corresponds to $(D ZMQ_REP)
    dealer  = ZMQ_DEALER,   /// Corresponds to $(D ZMQ_DEALER)
    router  = ZMQ_ROUTER,   /// Corresponds to $(D ZMQ_ROUTER)
    pub     = ZMQ_PUB,      /// Corresponds to $(D ZMQ_PUB)
    sub     = ZMQ_SUB,      /// Corresponds to $(D ZMQ_SUB)
    xpub    = ZMQ_XPUB,     /// Corresponds to $(D ZMQ_XPUB)
    xsub    = ZMQ_XSUB,     /// Corresponds to $(D ZMQ_XSUB)
    push    = ZMQ_PUSH,     /// Corresponds to $(D ZMQ_PUSH)
    pull    = ZMQ_PULL,     /// Corresponds to $(D ZMQ_PULL)
    pair    = ZMQ_PAIR,     /// Corresponds to $(D ZMQ_PAIR)
}


/**
An object that encapsulates a $(ZMQ) socket.

A default-initialized $(D Socket) is not a valid $(ZMQ) socket; it
must always be explicitly initialized with a constructor (see
$(FREF _Socket.this)):
---
Socket s;                     // Not a valid socket yet
s = Socket(SocketType.push);  // ...but now it is.
---
$(D Socket) objects can be passed around by value, and two copies will
refer to the same socket.  The underlying socket is managed using
reference counting, so that when the last copy of a $(D Socket) goes
out of scope, the socket is automatically closed.
*/
struct Socket
{
@safe:
    /**
    Creates a new $(ZMQ) socket.

    If $(D context) is not specified, the default context (as returned
    by $(FREF defaultContext)) is used.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_socket())
    */
    this(SocketType type)
    {
        this(defaultContext(), type);
    }

    /// ditto
    this(Context context, SocketType type)
    {
        if (auto s = trusted!zmq_socket(context.handle, type)) {
            m_context = context;
            m_type = type;
            m_socket = Resource(s, &zmq_close);
        } else {
            throw new ZmqException;
        }
    }

    /// With default context:
    unittest
    {
        auto sck = Socket(SocketType.push);
        assert (sck.initialized);
    }
    /// With explicit context:
    unittest
    {
        auto ctx = Context();
        auto sck = Socket(ctx, SocketType.push);
        assert (sck.initialized);
    }

    /**
    Closes the $(ZMQ) socket.

    Note that the socket will be automatically closed when the last reference
    to it goes out of scope, so it is often not necessary to call this
    method manually.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_close())
    */
    void close()
    {
        m_socket.free();
    }

    ///
    unittest
    {
        auto s = Socket(SocketType.pair);
        assert (s.initialized);
        s.close();
        assert (!s.initialized);
    }

    /**
    Starts accepting incoming connections on $(D endpoint).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_bind())
    */
    void bind(const char[] endpoint)
    {
        if (trusted!zmq_bind(m_socket.handle, zeroTermString(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        auto s = Socket(SocketType.pub);
        s.bind("inproc://zmqd_bind_example");
    }

    /**
    Stops accepting incoming connections on $(D endpoint).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_unbind())
    */
    void unbind(const char[] endpoint)
    {
        if (trusted!zmq_unbind(m_socket.handle, zeroTermString(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        auto s = Socket(SocketType.pub);
        s.bind("ipc://zmqd_unbind_example");
        // Do some work...
        s.unbind("ipc://zmqd_unbind_example");
    }

    /**
    Creates an outgoing connection to $(D endpoint).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_connect())
    */
    void connect(const char[] endpoint)
    {
        if (trusted!zmq_connect(m_socket.handle, zeroTermString(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        auto s = Socket(SocketType.sub);
        s.connect("ipc://zmqd_connect_example");
    }

    /**
    Disconnects the socket from $(D endpoint).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_disconnect())
    */
    void disconnect(const char[] endpoint)
    {
        if (trusted!zmq_disconnect(m_socket.handle, zeroTermString(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        auto s = Socket(SocketType.sub);
        s.connect("ipc://zmqd_disconnect_example");
        // Do some work...
        s.disconnect("ipc://zmqd_disconnect_example");
    }

    /**
    Sends a message part.

    $(D _send) blocks until the message has been queued on the socket.
    $(D trySend) performs the operation in non-blocking mode, and returns
    a $(D bool) value that signifies whether the message was queued on the
    socket.

    The $(D char[]) overload is a convenience function that simply casts
    the string argument to $(D ubyte[]).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_send()) (with the $(D ZMQ_DONTWAIT) flag, in the case
        of $(D trySend)).
    */
    void send(const ubyte[] data, bool more = false)
    {
        immutable flags = more ? ZMQ_SNDMORE : 0;
        if (trusted!zmq_send(m_socket.handle, data.ptr, data.length, flags) < 0) {
            throw new ZmqException;
        }
    }

    /// ditto
    void send(const char[] data, bool more = false) @trusted
    {
        send(cast(ubyte[]) data, more);
    }

    /// ditto
    bool trySend(const ubyte[] data, bool more = false)
    {
        immutable flags = ZMQ_DONTWAIT | (more ? ZMQ_SNDMORE : 0);
        if (trusted!zmq_send(m_socket.handle, data.ptr, data.length, flags) < 0) {
            import core.stdc.errno;
            if (errno == EAGAIN) return false;
            else throw new ZmqException;
        }
        return true;
    }

    /// ditto
    bool trySend(const char[] data, bool more = false) @trusted
    {
        return trySend(cast(ubyte[]) data, more);
    }

    ///
    unittest
    {
        auto sck = Socket(SocketType.pub);
        sck.send(cast(ubyte[]) [11, 226, 92]);
        sck.send("Hello World!");
    }

    /**
    Sends a message part.

    $(D _send) blocks until the message has been queued on the socket.
    $(D trySend) performs the operation in non-blocking mode, and returns
    a $(D bool) value that signifies whether the message was queued on the
    socket.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_send()) (with the $(D ZMQ_DONTWAIT) flag, in the case
        of $(D trySend)).
    */
    void send(ref Message msg, bool more = false)
    {
        immutable flags = more ? ZMQ_SNDMORE : 0;
        if (trusted!zmq_msg_send(msg.handle, m_socket.handle, flags) < 0) {
            throw new ZmqException;
        }
    }

    /// ditto
    bool trySend(ref Message msg, bool more = false)
    {
        immutable flags = ZMQ_DONTWAIT | (more ? ZMQ_SNDMORE : 0);
        if (trusted!zmq_msg_send(msg.handle, m_socket.handle, flags) < 0) {
            import core.stdc.errno;
            if (errno == EAGAIN) return false;
            else throw new ZmqException;
        }
        return true;
    }

    ///
    unittest
    {
        auto sck = Socket(SocketType.pub);
        auto msg = Message(12);
        msg.data.asString()[] = "Hello World!";
        sck.send(msg);
    }

    /**
    Receives a message part.

    $(D _receive) blocks until the request can be satisfied, and returns the
    number of bytes in the message.
    $(D tryReceive) performs the operation in non-blocking mode, and returns
    a $(STDREF typecons,Tuple) which contains the size of the message along
    with a $(D bool) value that signifies whether a message was received.
    (If the latter is $(D false), the former is always set to zero.)

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_recv()) (with the $(D ZMQ_DONTWAIT) flag, in the case
        of $(D tryReceive)).

    */
    size_t receive(ubyte[] data)
    {
        immutable len = trusted!zmq_recv(m_socket.handle, data.ptr, data.length, 0);
        if (len >= 0) {
            import std.conv;
            return to!size_t(len);
        } else {
            throw new ZmqException;
        }
    }

    /// ditto
    Tuple!(size_t, bool) tryReceive(ubyte[] data)
    {
        immutable len = trusted!zmq_recv(m_socket.handle, data.ptr, data.length, ZMQ_DONTWAIT);
        if (len >= 0) {
            import std.conv;
            return typeof(return)(to!size_t(len), true);
        } else {
            import core.stdc.errno;
            if (errno == EAGAIN) {
                return typeof(return)(0, false);
            } else {
                throw new ZmqException;
            }
        }
    }

    ///
    unittest
    {
        // Sender
        auto snd = Socket(SocketType.req);
        snd.connect("ipc://zmqd_receive_example");
        snd.send("Hello World!");

        // Receiver
        import std.string: representation;
        auto rcv = Socket(SocketType.rep);
        rcv.bind("ipc://zmqd_receive_example");
        char[256] buf;
        immutable len  = rcv.receive(buf.representation);
        assert (buf[0 .. len] == "Hello World!");
    }

    @system unittest
    {
        auto snd = Socket(SocketType.pair);
        snd.bind("ipc://zmqd_tryReceive_example");
        auto rcv = Socket(SocketType.pair);
        rcv.connect("ipc://zmqd_tryReceive_example");

        ubyte[256] buf;
        auto r1 = rcv.tryReceive(buf);
        assert (!r1[1]);

        import core.thread, core.time, std.string;
        snd.send("Hello World!");
        Thread.sleep(100.msecs); // Wait for message to be transferred...
        auto r2 = rcv.tryReceive(buf);
        assert (r2[1] && buf[0 .. r2[0]] == "Hello World!".representation);
    }

    /**
    Receives a message part.

    $(D _receive) blocks until the request can be satisfied, and returns the
    number of bytes in the message.
    $(D tryReceive) performs the operation in non-blocking mode, and returns
    a $(STDREF typecons,Tuple) which contains the size of the message along
    with a $(D bool) value that signifies whether a message was received.
    (If the latter is $(D false), the former is always set to zero.)

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_recv()) (with the $(D ZMQ_DONTWAIT) flag, in the case
        of $(D tryReceive)).

    */
    size_t receive(ref Message msg)
    {
        immutable len = trusted!zmq_msg_recv(msg.handle, m_socket.handle, 0);
        if (len >= 0) {
            import std.conv;
            return to!size_t(len);
        } else {
            throw new ZmqException;
        }
    }

    /// ditto
    Tuple!(size_t, bool) tryReceive(ref Message msg)
    {
        immutable len = trusted!zmq_msg_recv(msg.handle, m_socket.handle, ZMQ_DONTWAIT);
        if (len >= 0) {
            import std.conv;
            return typeof(return)(to!size_t(len), true);
        } else {
            import core.stdc.errno;
            if (errno == EAGAIN) {
                return typeof(return)(0, false);
            } else {
                throw new ZmqException;
            }
        }
    }

    ///
    unittest
    {
        // Sender
        auto snd = Socket(SocketType.req);
        snd.connect("ipc://zmqd_msg_receive_example");
        snd.send("Hello World!");

        // Receiver
        import std.string: representation;
        auto rcv = Socket(SocketType.rep);
        rcv.bind("ipc://zmqd_msg_receive_example");
        auto msg = Message();
        rcv.receive(msg);
        assert (msg.data.asString() == "Hello World!");
    }

    @system unittest
    {
        auto snd = Socket(SocketType.pair);
        snd.bind("ipc://zmqd_msg_tryReceive_example");
        auto rcv = Socket(SocketType.pair);
        rcv.connect("ipc://zmqd_msg_tryReceive_example");

        auto msg = Message();
        auto r1 = rcv.tryReceive(msg);
        assert (!r1[1]);

        import core.thread, core.time, std.string;
        snd.send("Hello World!");
        Thread.sleep(100.msecs); // Wait for message to be transferred...
        auto r2 = rcv.tryReceive(msg);
        assert (r2[1] && msg.data[0 .. r2[0]] == "Hello World!".representation);
    }

    /**
    The socket _type.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_getsockopt()) with $(D ZMQ_TYPE).
    */
    @property SocketType type() { return getOption!SocketType(ZMQ_TYPE); }

    ///
    unittest
    {
        auto sck = Socket(SocketType.xpub);
        assert (sck.type == SocketType.xpub);
    }

    /**
    Whether there are _more message data parts to follow.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_getsockopt()) with $(D ZMQ_RCVMORE).
    */
    @property bool more() { return !!getOption!int(ZMQ_RCVMORE); }

    // TODO: Better unittest/example
    unittest
    {
        auto sck = Socket(SocketType.req);
        assert (!sck.more);
    }

    /**
    Misc. socket properties.

    Each of these has a one-to-one correspondence with an option passed to
    $(ZMQREF zmq_getsockopt()) and $(ZMQREF zmq_setsockopt()). For
    example, $(D identity) corresponds to $(D ZMQ_IDENTITY),
    $(D receiveBufferSize) corresponds to $(D ZMQ_RCVBUF), etc.

    Notes:
    $(UL
        $(LI For convenience, the setter for the $(D identity) property
            accepts strings.  To retrieve a string with the getter, use
            the $(FREF asString) function.
            ---
            sck.identity = "foobar";
            assert (sck.identity.asString() == "foobar");
            ---
            )
        $(LI The $(D linger), $(D receiveTimeout) and $(D sendTimeout)
            properties may have the special value $(COREF time,Duration.max),
            which in this context specifies an infinite duration.  This  is
            translated to an option value of -1 in the C API (and it is also
            the default value for all of them).)
        $(LI The $(D ZMQ_SUBSCRIBE) and $(D ZMQ_UNSUBSCRIBE) options are
            treated differently from the others; see $(FREF Socket.subscribe)
            and $(FREF Socket.unsubscribe))
    )

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.$(BR)
        $(STDREF conv,ConvOverflowException) if a given $(D Duration) is
        longer than the number of milliseconds that will fit in an $(D int)
        (only applies to properties of $(COREF time,Duration) type).
    Corresponds_to:
        $(ZMQREF zmq_getsockopt()) and $(ZMQREF zmq_setsockopt()).
    */
    @property int sendHWM() { return getOption!int(ZMQ_SNDHWM); }
    /// ditto
    @property void sendHWM(int value) { setOption(ZMQ_SNDHWM, value); }

    /// ditto
    @property int receiveHWM() { return getOption!int(ZMQ_RCVHWM); }
    /// ditto
    @property void receiveHWM(int value) { setOption(ZMQ_RCVHWM, value); }

    /// ditto
    @property ulong threadAffinity() { return getOption!ulong(ZMQ_AFFINITY); }
    /// ditto
    @property void threadAffinity(ulong value) { setOption(ZMQ_AFFINITY, value); }

    /// ditto
    @property ubyte[] identity() @trusted
    {
        // This function is not @safe because it calls a @system function
        // (zmq_getsockopt) and takes the address of a local (len).
        auto buf = new ubyte[255];
        size_t len = buf.length;
        if (zmq_getsockopt(m_socket.handle, ZMQ_IDENTITY, buf.ptr, &len) != 0) {
            throw new ZmqException;
        }
        return buf[0 .. len];
    }
    /// ditto
    @property void identity(const ubyte[] value) { setOption(ZMQ_IDENTITY, value); }
    /// ditto
    @property void identity(const  char[] value) { setOption(ZMQ_IDENTITY, value); }

    /// ditto
    @property int rate() { return getOption!int(ZMQ_RATE); }
    /// ditto
    @property void rate(int value) { setOption(ZMQ_RATE, value); }

    /// ditto
    @property Duration recoveryInterval()
    {
        return msecs(getOption!int(ZMQ_RECOVERY_IVL));
    }
    /// ditto
    @property void recoveryInterval(Duration value)
    {
        import std.conv: to;
        setOption(ZMQ_RECOVERY_IVL, to!int(value.total!"msecs"()));
    }

    /// ditto
    @property int sendBufferSize() { return getOption!int(ZMQ_SNDBUF); }
    /// ditto
    @property void sendBufferSize(int value) { setOption(ZMQ_SNDBUF, value); }

    /// ditto
    @property int receiveBufferSize() { return getOption!int(ZMQ_RCVBUF); }
    /// ditto
    @property void receiveBufferSize(int value) { setOption(ZMQ_RCVBUF, value); }

    /// ditto
    @property Duration linger()
    {
        const auto value = getOption!int(ZMQ_LINGER);
        return value == -1 ? Duration.max : value.msecs;
    }
    /// ditto
    @property void linger(Duration value)
    {
        import std.conv: to;
        setOption(ZMQ_LINGER,
                  value == Duration.max ? -1 : to!int(value.total!"msecs"()));
    }

    /// ditto
    @property Duration reconnectionInterval()
    {
        return getOption!int(ZMQ_RECONNECT_IVL).msecs;
    }
    /// ditto
    @property void reconnectionInterval(Duration value)
    {
        import std.conv: to;
        setOption(ZMQ_RECONNECT_IVL, to!int(value.total!"msecs"()));
    }

    /// ditto
    @property Duration maxReconnectionInterval()
    {
        return getOption!int(ZMQ_RECONNECT_IVL_MAX).msecs;
    }
    /// ditto
    @property void maxReconnectionInterval(Duration value)
    {
        import std.conv: to;
        setOption(ZMQ_RECONNECT_IVL_MAX, to!int(value.total!"msecs"()));
    }

    /// ditto
    @property int backlog() { return getOption!int(ZMQ_BACKLOG); }
    /// ditto
    @property void backlog(int value) { setOption(ZMQ_BACKLOG, value); }

    /// ditto
    @property long maxMsgSize() { return getOption!long(ZMQ_MAXMSGSIZE); }
    /// ditto
    @property void maxMsgSize(long value) { setOption(ZMQ_MAXMSGSIZE, value); }

    /// ditto
    @property int multicastHops() { return getOption!int(ZMQ_MULTICAST_HOPS); }
    /// ditto
    @property void multicastHops(int value) { setOption(ZMQ_MULTICAST_HOPS, value); }

    /// ditto
    @property Duration receiveTimeout()
    {
        const value = getOption!int(ZMQ_RCVTIMEO);
        return value == -1 ? Duration.max : value.msecs;
    }
    /// ditto
    @property void receiveTimeout(Duration value)
    {
        import std.conv: to;
        setOption(ZMQ_RCVTIMEO,
                  value == Duration.max ? -1 : to!int(value.total!"msecs"()));
    }

    /// ditto
    @property Duration sendTimeout()
    {
        const value = getOption!int(ZMQ_SNDTIMEO);
        return value == -1 ? Duration.max : value.msecs;
    }
    /// ditto
    @property void sendTimeout(Duration value)
    {
        import std.conv: to;
        setOption(ZMQ_SNDTIMEO,
                  value == Duration.max ? -1 : to!int(value.total!"msecs"()));
    }

    /// ditto
    @property bool ipv4Only() { return !!getOption!int(ZMQ_IPV4ONLY); }
    /// ditto
    @property void ipv4Only(bool value) { setOption(ZMQ_IPV4ONLY, value ? 1 : 0); }

    /// ditto
    @property bool delayAttachOnConnect() { return !!getOption!int(ZMQ_DELAY_ATTACH_ON_CONNECT); }
    /// ditto
    @property void delayAttachOnConnect(bool value) { setOption(ZMQ_DELAY_ATTACH_ON_CONNECT, value ? 1 : 0); }

    /// ditto
    @property FD fd() { return getOption!FD(ZMQ_FD); }

    /// ditto
    @property int events() { return getOption!int(ZMQ_EVENTS); }

    /// ditto
    @property char[] lastEndpoint() @trusted
    {
        // This function is not @safe because it calls a @system function
        // (zmq_getsockopt) and takes the address of a local (len).
        auto buf = new char[1024];
        size_t len = buf.length;
        if (zmq_getsockopt(m_socket.handle, ZMQ_LAST_ENDPOINT, buf.ptr, &len) != 0) {
            throw new ZmqException;
        }
        return buf[0 .. len-1];
    }

    // TODO: Some low-level options are missing still, plus setters for
    // ZMQ_ROUTER_MANDATORY and ZMQ_XPUB_VERBOSE.

    unittest
    {
        // We test all the socket options by checking that they have their default value.
        auto s = Socket(SocketType.xpub);
        const e = "inproc://unittest2";
        s.bind(e);
        import core.time;
        assert(s.type == SocketType.xpub);
        assert(s.sendHWM == 1000);
        assert(s.receiveHWM == 1000);
        assert(s.threadAffinity == 0);
        assert(s.identity == null);
        assert(s.rate == 100);
        assert(s.recoveryInterval == 10.seconds);
        assert(s.sendBufferSize == 0);
        assert(s.receiveBufferSize == 0);
        assert(s.linger == Duration.max);
        assert(s.reconnectionInterval == 100.msecs);
        assert(s.maxReconnectionInterval == Duration.zero);
        assert(s.backlog == 100);
        assert(s.maxMsgSize == -1);
        assert(s.multicastHops == 1);
        assert(s.receiveTimeout == Duration.max);
        assert(s.sendTimeout == Duration.max);
        assert(s.ipv4Only);
        assert(!s.delayAttachOnConnect);
        version(Posix) {
            assert(s.fd > 2); // 0, 1 and 2 are the standard streams
        }
        assert(s.lastEndpoint == e);

        // Test setters and getters together
        s.sendHWM = 500;
        assert(s.sendHWM == 500);
        s.receiveHWM = 600;
        assert(s.receiveHWM == 600);
        s.threadAffinity = 1;
        assert(s.threadAffinity == 1);
        s.identity = cast(ubyte[]) [ 65, 66, 67 ];
        assert(s.identity == [65, 66, 67]);
        s.identity = "foo";
        assert(s.identity == [102, 111, 111]);
        s.rate = 200;
        assert(s.rate == 200);
        s.recoveryInterval = 5.seconds;
        assert(s.recoveryInterval == 5_000.msecs);
        s.sendBufferSize = 500;
        assert(s.sendBufferSize == 500);
        s.receiveBufferSize = 600;
        assert(s.receiveBufferSize == 600);
        s.linger = Duration.zero;
        assert(s.linger == Duration.zero);
        s.linger = 100_000.usecs;
        assert(s.linger == 100.msecs);
        s.linger = Duration.max;
        assert(s.linger == Duration.max);
        s.reconnectionInterval = 200_000.usecs;
        assert(s.reconnectionInterval == 200.msecs);
        s.maxReconnectionInterval = 300_000.usecs;
        assert(s.maxReconnectionInterval == 300.msecs);
        s.backlog = 50;
        assert(s.backlog == 50);
        s.maxMsgSize = 1000;
        assert(s.maxMsgSize == 1000);
        s.multicastHops = 2;
        assert(s.multicastHops == 2);
        s.receiveTimeout = 3.seconds;
        assert(s.receiveTimeout == 3_000_000.usecs);
        s.receiveTimeout = Duration.max;
        assert(s.receiveTimeout == Duration.max);
        s.sendTimeout = 2_000_000.usecs;
        assert(s.sendTimeout == 2.seconds);
        s.sendTimeout = Duration.max;
        assert(s.sendTimeout == Duration.max);
        s.ipv4Only = false;
        assert(!s.ipv4Only);
        s.delayAttachOnConnect = true;
        assert(s.delayAttachOnConnect);
    }

    /**
    Establishes a message filter.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_setsockopt()) with $(D ZMQ_SUBSCRIBE).
    */
    void subscribe(const ubyte[] filterPrefix) { setOption(ZMQ_SUBSCRIBE, filterPrefix); }
    /// ditto
    void subscribe(const  char[] filterPrefix) { setOption(ZMQ_SUBSCRIBE, filterPrefix); }

    ///
    unittest
    {
        // Create a subscriber that accepts all messages that start with
        // the prefixes "foo" or "bar".
        auto sck = Socket(SocketType.sub);
        sck.subscribe("foo");
        sck.subscribe("bar");
    }

    @system unittest
    {
        void sleep(int ms) {
            import core.thread, core.time;
            Thread.sleep(dur!"msecs"(ms));
        }
        auto pub = Socket(SocketType.pub);
        pub.bind("inproc://zmqd_subscribe_unittest");
        auto sub = Socket(SocketType.sub);
        sub.connect("inproc://zmqd_subscribe_unittest");

        pub.send("Hello");
        sleep(100);
        sub.subscribe("He");
        sub.subscribe(cast(ubyte[])['W', 'o']);
        sleep(100);
        pub.send("Heeee");
        pub.send("World");
        sleep(100);
        ubyte[5] buf;
        sub.receive(buf);
        assert(buf.asString() == "Heeee");
        sub.receive(buf);
        assert(buf.asString() == "World");
    }

    /**
    Removes a message filter.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_setsockopt()) with $(D ZMQ_SUBSCRIBE).
    */
    void unsubscribe(const ubyte[] filterPrefix) { setOption(ZMQ_UNSUBSCRIBE, filterPrefix); }
    /// ditto
    void unsubscribe(const  char[] filterPrefix) { setOption(ZMQ_UNSUBSCRIBE, filterPrefix); }

    ///
    unittest
    {
        // Subscribe to messages that start with "foo" or "bar".
        auto sck = Socket(SocketType.sub);
        sck.subscribe("foo");
        sck.subscribe("bar");
        // ...
        // From now on, only accept messages that start with "bar"
        sck.unsubscribe("foo");
    }

    /**
    Spawns a PAIR socket that publishes socket state changes (events) over
    the INPROC transport to the given endpoint.

    Which event types should be published may be selected by bitwise-ORing
    together different $(REF EventType) flags in the $(D event) parameter.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_socket_monitor())
    See_also:
        $(FREF receiveEvent), which receives and parses event messages.
    */
    void monitor(const char[] endpoint, EventType events = EventType.all)
    {
        if (trusted!zmq_socket_monitor(m_socket.handle, zeroTermString(endpoint), events) < 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        auto sck = Socket(SocketType.pub);
        sck.monitor("inproc://zmqd_monitor_unittest",
                    EventType.accepted | EventType.closed);
    }

    /**
    The $(D void*) pointer used by the underlying C API to refer to the socket.

    If the object has not been initialized, this function returns $(D null).
    */
    @property inout(void)* handle() inout pure nothrow
    {
        return m_socket.handle;
    }

    /**
    Whether this $(REF Socket) object has been _initialized, i.e. whether it
    refers to a valid $(ZMQ) socket.
    */
    @property bool initialized() const pure nothrow
    {
        return m_socket.initialized;
    }

    ///
    unittest
    {
        Socket sck;
        assert (!sck.initialized);
        sck = Socket(SocketType.sub);
        assert (sck.initialized);
        sck.close();
        assert (!sck.initialized);
    }

private:
    T getOption(T)(int option) @trusted
    {
        T buf;
        auto len = T.sizeof;
        if (zmq_getsockopt(m_socket.handle, option, &buf, &len) != 0) {
            throw new ZmqException;
        }
        assert(len == T.sizeof);
        return buf;
    }
    void setOption()(int option, const void[] value)
    {
        if (trusted!zmq_setsockopt(m_socket.handle, option, value.ptr, value.length) != 0) {
            throw new ZmqException;
        }
    }

    import std.traits;
    void setOption(T)(int option, T value) @trusted if (isScalarType!T)
    {
        if (zmq_setsockopt(m_socket.handle, option, &value, value.sizeof) != 0) {
            throw new ZmqException;
        }
    }

    Context m_context;
    SocketType m_type;
    Resource m_socket;
}

unittest
{
    auto s1 = Socket(SocketType.pair);
    auto s2 = Socket(SocketType.pair);
    s1.bind("inproc://unittest");
    s2.connect("inproc://unittest");
    s1.send("Hello World!");
    ubyte[12] buf;
    const len = s2.receive(buf[]);
    assert (len == 12);
    assert (buf == "Hello World!");
}


version (Windows) {
    alias PlatformFD = SOCKET;
} else version (Posix) {
    alias PlatformFD = int;
}

/**
The native socket file descriptor type.

This is an alias for $(D SOCKET) on Windows and $(D int) on POSIX systems.
*/
alias FD = PlatformFD;


/**
Starts the built-in $(ZMQ) _proxy.

Corresponds_to:
    $(ZMQREF zmq_proxy())
*/
void proxy(ref Socket frontend, ref Socket backend) nothrow
{
    trusted!zmq_proxy(frontend.handle, backend.handle, null);
}

/// ditto
void proxy(ref Socket frontend, ref Socket backend, ref Socket capture) nothrow
{
    trusted!zmq_proxy(frontend.handle, backend.handle, capture.handle);
}


/**
An object that encapsulates a $(ZMQ) message.

This $(D struct) is a wrapper around a $(D zmq_msg_t) object.  Unlike
$(REF Context) and $(REF Socket), it does $(EM not) perform reference
counting, because $(ZMQ) messages have a form of reference counting of
their own.  A $(D Message) cannot be copied by normal assignment; use
$(FREF Message.copy) for this.

A default-initialized $(D Message) is not a valid $(ZMQ) message; it
should always be explicitly initialized with $(FREF _Message.opCall).
Alternatively, it may be initialized later using $(FREF _Message.reinit).
---
Message msg1;               // Invalid message
auto msg2 = Message();      // Empty message
auto msg3 = Message(1024);  // 1K message
msg1.reinit(2048);          // msg1 now has size 2K
msg2.reinit(2048);          // ...and so does msg2
---
When a $(D Message) goes out of scope, $(ZMQREF zmq_msg_close()) is
called on the underlying $(D zmq_msg_t).
*/
struct Message
{
@safe:
    /**
    Initializes a $(ZMQ) message.

    $(D size) specifies the size of the message.  If $(D size) is
    zero, the message will be empty.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_init()) if $(D size == 0) and
        $(ZMQREF zmq_msg_init_size()) if $(D size > 0).
    */
    static Message opCall(size_t size = 0)
    {
        Message m;
        m.init(size);
        return m;
    }

    ///
    unittest
    {
        auto msg = Message();
        assert(msg.size == 0);
    }

    ///
    unittest
    {
        auto msg = Message(123);
        assert(msg.size == 123);
    }

    /**
    Reinitializes a $(ZMQ) message.

    This function will release the message if it has already been initialized,
    and then initialize it anew with the specified size.  Existing message
    content will be lost.

    $(D size) specifies the size of the message.  If $(D size) is
    zero, the message will be empty.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_close()) followed by
        $(ZMQREF zmq_msg_init()) if $(D size == 0) or
        $(ZMQREF zmq_msg_init_size()) if $(D size > 0).
    */
    void reinit(size_t size = 0)
    {
        close();
        init(size);
    }

    ///
    unittest
    {
        auto msg = Message(256);
        assert (msg.size == 256);
        msg.reinit(1024);
        assert (msg.size == 1024);
    }

    @disable this(this);

    /**
    Releases the $(ZMQ) message when the $(D Message) is destroyed.

    This destructor never throws, which means that any errors will go
    undetected.  If this is undesirable, call $(FREF Message.close) before
    the $(D Message) is destroyed.

    Corresponds_to:
        $(ZMQREF zmq_msg_close())
    */
    ~this() nothrow
    {
        if (m_initialized) {
            immutable rc = trusted!zmq_msg_close(&m_msg);
            assert(rc == 0, "zmq_msg_close failed: Invalid message");
        }
    }

    /**
    Releases the $(ZMQ) message.

    Note that the message will be automatically released when the $(D Message)
    object is destroyed, so it is often not necessary to call this method
    manually.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_close())
    */
    void close()
    {
        if (m_initialized) {
            if (trusted!zmq_msg_close(&m_msg) != 0) {
                throw new ZmqException;
            }
            m_initialized = false;
        }
    }

    /**
    Copies message content to another message.

    $(D copy()) returns a new $(D Message) object, while $(D copyTo(dest))
    copies the contents of this $(D Message) into $(D dest).  $(D dest) must
    be a valid (i.e. initialized) $(D Message).

    Warning:
        These functions may not do what you think they do.  Please refer
        to $(ZMQAPI zmq_msg_copy(),the $(ZMQ) manual) for details.
    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_copy())
    */
    Message copy()
    {
        auto cp = Message();
        copyTo(cp);
        return cp;
    }

    /// ditto
    void copyTo(ref Message dest)
    {
        if (trusted!zmq_msg_copy(&dest.m_msg, &m_msg) != 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        import std.string: representation;
        auto msg1 = Message(3);
        msg1.data[] = "foo".representation;
        auto msg2 = msg1.copy();
        assert (msg2.data.asString() == "foo");
    }

    /**
    Moves message content to another message.

    $(D move()) returns a new $(D Message) object, while $(D moveTo(dest))
    moves the contents of this $(D Message) to $(D dest).  $(D dest) must
    be a valid (i.e. initialized) $(D Message).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_move())
    */
    Message move()
    {
        auto m = Message();
        moveTo(m);
        return m;
    }

    /// ditto
    void moveTo(ref Message dest)
    {
        if (trusted!zmq_msg_move(&dest.m_msg, &m_msg) != 0) {
            throw new ZmqException;
        }
    }

    ///
    unittest
    {
        import std.string: representation;
        auto msg1 = Message(3);
        msg1.data[] = "foo".representation;
        auto msg2 = msg1.move();
        assert (msg1.size == 0);
        assert (msg2.data.asString() == "foo");
    }

    /**
    The message content size in bytes.

    Corresponds_to:
        $(ZMQREF zmq_msg_size())
    */
    @property size_t size() nothrow
    {
        return trusted!zmq_msg_size(&m_msg);
    }

    ///
    unittest
    {
        auto msg = Message(123);
        assert(msg.size == 123);
    }

    /**
    Retrieves the message content.

    Corresponds_to:
        $(ZMQREF zmq_msg_data())
    */
    @property ubyte[] data() @trusted nothrow
    {
        return (cast(ubyte*) zmq_msg_data(&m_msg))[0 .. size];
    }

    ///
    unittest
    {
        import std.string: representation;
        auto msg = Message(3);
        assert(msg.data.length == 3);
        msg.data[] = "foo".representation; // Slice operator -> array copy.
        assert(msg.data.asString() == "foo");
    }

    /**
    Whether there are more message parts to retrieve.

    Corresponds_to:
        $(ZMQREF zmq_msg_more())
    */
    @property bool more() nothrow
    {
        return !!trusted!zmq_msg_more(&m_msg);
    }

    /**
    A pointer to the underlying $(D zmq_msg_t).
    */
    @property inout(zmq_msg_t)* handle() inout pure nothrow
    {
        return &m_msg;
    }

private:
    private void init(size_t size)
        in { assert (!m_initialized); }
        out { assert (m_initialized); }
        body
    {
        if (size > 0) {
            if (trusted!zmq_msg_init_size(&m_msg, size) != 0) {
                throw new ZmqException;
            }
        } else {
            if (trusted!zmq_msg_init(&m_msg) != 0) {
                throw new ZmqException;
            }
        }
        m_initialized = true;
    }

    bool m_initialized;
    zmq_msg_t m_msg;
}

unittest
{
    const url = uniqueUrl("inproc");
    auto s1 = Socket(SocketType.pair);
    auto s2 = Socket(SocketType.pair);
    s1.bind(url);
    s2.connect(url);

    auto m1a = Message(123);
    m1a.data[] = 'a';
    s1.send(m1a);
    auto m2a = Message();
    s2.receive(m2a);
    assert(m2a.size == 123);
    foreach (e; m2a.data) assert(e == 'a');

    auto m1b = Message(10);
    m1b.data[] = 'b';
    s1.send(m1b);
    auto m2b = Message();
    s2.receive(m2b);
    assert(m2b.size == 10);
    foreach (e; m2b.data) assert(e == 'b');
}


/**
Socket event types.

These are used together with $(FREF Socket.monitor), and are described
in the $(ZMQREF zmq_socket_monitor()) reference.
*/
enum EventType
{
    connected       = ZMQ_EVENT_CONNECTED,      /// Corresponds to $(D ZMQ_EVENT_CONNECTED).
    connectDelayed  = ZMQ_EVENT_CONNECT_DELAYED,/// Corresponds to $(D ZMQ_EVENT_CONNECT_DELAYED).
    connectRetried  = ZMQ_EVENT_CONNECT_RETRIED,/// Corresponds to $(D ZMQ_EVENT_CONNECT_RETRIED).
    listening       = ZMQ_EVENT_LISTENING,      /// Corresponds to $(D ZMQ_EVENT_LISTENING).
    bindFailed      = ZMQ_EVENT_BIND_FAILED,    /// Corresponds to $(D ZMQ_EVENT_BIND_FAILED).
    accepted        = ZMQ_EVENT_ACCEPTED,       /// Corresponds to $(D ZMQ_EVENT_ACCEPTED).
    acceptFailed    = ZMQ_EVENT_ACCEPT_FAILED,  /// Corresponds to $(D ZMQ_EVENT_ACCEPT_FAILED).
    closed          = ZMQ_EVENT_CLOSED,         /// Corresponds to $(D ZMQ_EVENT_CLOSED).
    closeFailed     = ZMQ_EVENT_CLOSE_FAILED,   /// Corresponds to $(D ZMQ_EVENT_CLOSE_FAILED).
    disconnected    = ZMQ_EVENT_DISCONNECTED,   /// Corresponds to $(D ZMQ_EVENT_DISCONNECTED).
    all             = ZMQ_EVENT_ALL             /// Corresponds to $(D ZMQ_EVENT_ALL).
}


/**
Receives a message on the given socket and interprets it as a socket
state change event.

$(D socket) must be a PAIR socket which is connected to an endpoint
created via a $(FREF Socket.monitor) call.  $(D receiveEvent()) receives
one message on the socket, parses its contents according to the
specification in the $(ZMQREF zmq_socket_monitor()) reference,
and returns the event information as an $(REF Event) object.

The function will attempt to detect whether the received message
is in fact an event message, by checking that its length is equal
to $(D zmq_event_t.sizeof) and that the value of the
$(D zmq_event_t.event) field is valid.  If this is not the case,
an $(REF InvalidEventException) is thrown.

Throws:
    $(REF ZmqException) if $(ZMQ) reports an error.$(BR)
    $(REF InvalidEventException) if the received message could not
    be interpreted as an event message.
See_also:
    $(FREF Socket.monitor), for monitoring socket state changes.
*/
Event receiveEvent(Socket socket) @system
{
    auto msg = Message();
    if (socket.receive(msg) != zmq_event_t.sizeof) {
        throw new InvalidEventException;
    }
    try {
        auto zmqEvent = cast(zmq_event_t*) msg.data.ptr;
        import std.conv: to;
        immutable type = to!EventType(zmqEvent.event);
        const(char)* addr;
        int value;
        final switch (type) {
            case EventType.connected:
                addr  = zmqEvent.data.connected.addr;
                value = zmqEvent.data.connected.fd;
                break;
            case EventType.connectDelayed:
                addr  = zmqEvent.data.connect_delayed.addr;
                value = zmqEvent.data.connect_delayed.err;
                break;
            case EventType.connectRetried:
                addr  = zmqEvent.data.connect_retried.addr;
                value = zmqEvent.data.connect_retried.interval;
                break;
            case EventType.listening:
                addr  = zmqEvent.data.listening.addr;
                value = zmqEvent.data.listening.fd;
                break;
            case EventType.bindFailed:
                addr  = zmqEvent.data.bind_failed.addr;
                value = zmqEvent.data.bind_failed.err;
                break;
            case EventType.accepted:
                addr  = zmqEvent.data.accepted.addr;
                value = zmqEvent.data.accepted.fd;
                break;
            case EventType.acceptFailed:
                addr  = zmqEvent.data.accept_failed.addr;
                value = zmqEvent.data.accept_failed.err;
                break;
            case EventType.closed:
                addr  = zmqEvent.data.closed.addr;
                value = zmqEvent.data.closed.fd;
                break;
            case EventType.closeFailed:
                addr  = zmqEvent.data.close_failed.addr;
                value = zmqEvent.data.close_failed.err;
                break;
            case EventType.disconnected:
                addr  = zmqEvent.data.disconnected.addr;
                value = zmqEvent.data.disconnected.fd;
                break;
            case EventType.all: // Unlikely, but...
                throw new Exception(null);
        }
        return Event(type, addr !is null ? to!string(addr) : null, value);
    } catch (Exception e) {
        // Any exception thrown within the try block signifies that there
        // is something wrong with the event message.
        throw new InvalidEventException;
    }
}

@system unittest
{
    Event[] events;
    void eventCollector()
    {
        auto coll = Socket(SocketType.pair);
        coll.connect("inproc://zmqd_receiveEvent_unittest_monitor");
        do {
            events ~= receiveEvent(coll);
        } while (events[$-1].type != EventType.closed);
    }
    import core.thread;
    auto collector = new Thread(&eventCollector);
    collector.start();

    static void eventGenerator()
    {
        auto sck1 = Socket(SocketType.pair);
        sck1.monitor("inproc://zmqd_receiveEvent_unittest_monitor");
        sck1.bind("ipc://zmqd_receiveEvent_unittest");
        import core.time;
        Thread.sleep(100.msecs);
        auto sck2 = Socket(SocketType.pair);
        sck2.connect("ipc://zmqd_receiveEvent_unittest");
        Thread.sleep(100.msecs);
        sck2.disconnect("ipc://zmqd_receiveEvent_unittest");
        Thread.sleep(100.msecs);
        sck1.unbind("ipc://zmqd_receiveEvent_unittest");
    }
    eventGenerator();
    collector.join();
    assert (events.length == 3);
    foreach (ev; events) {
        assert (ev.address == "ipc://zmqd_receiveEvent_unittest");
    }
    assert (events[0].type == EventType.listening);
    assert (events[1].type == EventType.accepted);
    assert (events[2].type == EventType.closed);
    import std.exception;
    assertNotThrown!Error(events[0].fd);
    assertThrown!Error(events[0].errno);
    assertThrown!Error(events[0].interval);
}


/**
Information about a socket state change.

Corresponds_to:
    $(ZMQAPI zmq_socket_monitor,$(D zmq_event_t))
See_also:
    $(FREF receiveEvent)
*/
struct Event
{
    /**
    The event type.

    Corresponds_to:
        $(D zmq_event_t.event)
    */
    @property EventType type() const pure nothrow
    {
        return m_type;
    }

    /**
    The peer address.

    Corresponds_to:
        $(D zmq_event_t.data.xyz.addr), where $(D xyz) is the event-specific union.
    */
    @property string address() const pure nothrow
    {
        return m_address;
    }

    /**
    The socket file descriptor.

    This property function may only be called if $(REF Event.type) is one of:
    $(D connected), $(D listening), $(D accepted), $(D closed) or $(D disonnected).

    Throws:
        $(D Error) if the property is called for a wrong event type.
    Corresponds_to:
        $(D zmq_event_t.data.xyz.addr), where $(D xyz) is the event-specific union.
    */
    @property FD fd() const pure nothrow
    {
        final switch (m_type) {
            case EventType.connected     :
            case EventType.listening     :
            case EventType.accepted      :
            case EventType.closed        :
            case EventType.disconnected  : return cast(typeof(return)) m_value;
            case EventType.connectDelayed:
            case EventType.connectRetried:
            case EventType.bindFailed    :
            case EventType.acceptFailed  :
            case EventType.closeFailed   : throw invalidProperty();
            case EventType.all           :
        }
        assert (false);
    }

    /**
    The $(D errno) code for the error which triggered the event.

    This property function may only be called if $(REF Event.type) is either
    $(D bindFailed), $(D acceptFailed) or $(D closeFailed).

    Throws:
        $(D Error) if the property is called for a wrong event type.
    Corresponds_to:
        $(D zmq_event_t.data.xyz.addr), where $(D xyz) is the event-specific union.
    */
    @property int errno() const pure nothrow
    {
        final switch (m_type) {
            case EventType.bindFailed    :
            case EventType.acceptFailed  :
            case EventType.closeFailed   : return m_value;
            case EventType.connected     :
            case EventType.connectDelayed:
            case EventType.connectRetried:
            case EventType.listening     :
            case EventType.accepted      :
            case EventType.closed        :
            case EventType.disconnected  : throw invalidProperty();
            case EventType.all           :
        }
        assert (false);
    }

    /**
    The reconnect interval.

    This property function may only be called if $(REF Event.type) is
    $(D connectRetried).

    Throws:
        $(D Error) if the property is called for a wrong event type.
    Corresponds_to:
        $(D zmq_event_t.data.connect_retried.interval)
    */
    @property Duration interval() const pure nothrow
    {
        final switch (m_type) {
            case EventType.connectRetried: return m_value.msecs;
            case EventType.connected     :
            case EventType.connectDelayed:
            case EventType.listening     :
            case EventType.bindFailed    :
            case EventType.accepted      :
            case EventType.acceptFailed  :
            case EventType.closed        :
            case EventType.closeFailed   :
            case EventType.disconnected  : throw invalidProperty();
            case EventType.all           :
        }
        assert (false);
    }

private:
    this(EventType type, string address, int value) pure nothrow
    {
        m_type = type;
        m_address = address;
        m_value = value;
    }

    Error invalidProperty(string name = __FUNCTION__)() const pure nothrow
    {
        try {
            import std.conv: text;
            return new Error(text("Property '", name,
                                  "' not available for event type '",
                                  m_type, "'"));
        } catch (Exception e) {
            assert(false);
        }
    }

    EventType m_type;
    string m_address;
    int m_value;
}


/**
Input/output multiplexing.

This function is a bare-bones wrapper around $(ZMQREF zmq_poll()), using a
plain array of $(D zmq_pollitem_t) structures to hold the socket handles
and the event flags.  This array is passed straight to the C function, thus
avoiding additional allocations.  $(REF Socket.handle) can be used to populate
the $(D zmq_pollitem_t.socket) field, or $(STDREF socket,Socket.handle) can be
used to populate $(D zmq_pollitem_t.fd) for standard socket support.

The $(D timeout) parameter may have the special value
$(COREF time,Duration.max), which in this context specifies an infinite
duration.  This is translated to an argument value of -1 in the C API.

Returns:
    The number of $(D zmq_pollitem_t) structures with events signalled
    in $(D revents), or 0 if no events have been signalled.
Throws:
    $(REF ZmqException) if $(ZMQ) reports an error.
Corresponds_to:
    $(ZMQREF zmq_poll())
*/
uint poll(zmq_pollitem_t[] items, Duration timeout)
{
    import std.conv: to;
    const n = trusted!zmq_poll(
        items.ptr,
        to!int(items.length),
        timeout == Duration.max ? -1 : to!int(timeout.total!"msecs"()));
    if (n < 0) throw new ZmqException;
    return cast(uint) n;
}

///
@system unittest
{
    auto socket1 = zmqd.Socket(zmqd.SocketType.pair);
    socket1.bind("ipc://zmqd_poll_example");

    import std.socket;
    auto socket2 = new std.socket.Socket(
        AddressFamily.INET,
        std.socket.SocketType.DGRAM);
    socket2.bind(new InternetAddress(InternetAddress.ADDR_ANY, 5678));

    auto items = [
        zmq_pollitem_t(socket1.handle, 0, ZMQ_POLLIN, 0),
        zmq_pollitem_t(null, socket2.handle, ZMQ_POLLIN | ZMQ_POLLOUT, 0)
    ];
    const n = poll(items, 100.msecs);
    assert (n == 1);
    assert (items[0].revents == 0);
    assert (items[1].revents == ZMQ_POLLOUT);
    socket2.close();
}


/**
Utility function which interprets and validates a byte array as a UTF-8 string.

Most of $(ZMQD)'s message API deals in $(D ubyte[]) arrays, but very often,
the message _data contains plain text.  $(D asString()) allows for easy and
safe interpretation of raw _data as characters.  It checks that $(D data) is
a valid UTF-8 encoded string, and returns a $(D char[]) array that refers to
the same memory region.

Throws:
    $(STDREF utf,UTFException) if $(D data) is not a valid UTF-8 string.
See_also:
    $(STDREF string,representation), which performs the opposite operation.
*/
inout(char)[] asString(inout(ubyte)[] data) pure
{
    auto s = cast(typeof(return)) data;
    import std.utf: validate;
    validate(s);
    return s;
}

///
unittest
{
    auto s1 = Socket(SocketType.pair);
    s1.bind("ipc://zmqd_asString_example");
    auto s2 = Socket(SocketType.pair);
    s2.connect("ipc://zmqd_asString_example");

    auto msg = Message(12);
    msg.data.asString()[] = "Hello World!";
    s1.send(msg);

    ubyte[12] buf;
    s2.receive(buf);
    assert(buf.asString() == "Hello World!");
}

unittest
{
    auto bytes = cast(ubyte[]) ['f', 'o', 'o'];
    auto text = bytes.asString();
    assert (text == "foo");
    assert (cast(void*) bytes.ptr == cast(void*) text.ptr);

    import std.exception: assertThrown;
    import std.utf: UTFException;
    auto b = cast(ubyte[]) [100, 252, 1];
    assertThrown!UTFException(asString(b));
}


/**
A class for exceptions thrown when any of the underlying $(ZMQ) C functions
report an error.

The exception provides a standard error message obtained with
$(ZMQREF zmq_strerror()), as well as the $(D errno) code set by the $(ZMQ)
function which reported the error.
*/
class ZmqException : Exception
{
    /**
    The $(D errno) code that was set by the $(ZMQ) function that reported
    the error.

    Corresponds_to:
        $(ZMQREF zmq_errno())
    */
    immutable int errno;

private:
    this(string file = __FILE__, int line = __LINE__) nothrow
    {
        import core.stdc.errno, std.conv;
        this.errno = core.stdc.errno.errno;
        string msg;
        try {
            msg = trusted!(to!string)(trusted!zmq_strerror(this.errno));
        } catch (Exception e) { /* We never get here */ }
        assert(msg.length);     // Still, let's assert as much.
        super(msg, file, line);
    }
}


/**
Exception thrown by $(FREF receiveEvent) on failure to interpret a
received message as an event description.
*/
class InvalidEventException : Exception
{
private:
    this(string file = __FILE__, int line = __LINE__) nothrow
    {
        super("The received message is not an event message", file, line);
    }
}


private:

struct Resource
{
@system: // Workaround for DMD issue #12529
    alias extern(C) int function(void*) nothrow CFreeFunction;
@safe:

    this(void* ptr, CFreeFunction freeFunc) pure nothrow
        in { assert(ptr !is null); } body
    {
        m_payload = new Payload(1, ptr, freeFunc);
    }

    this(this) pure nothrow
    {
        if (m_payload !is null) {
            ++(m_payload.refCount);
        }
    }

    ~this() nothrow
    {
        detach();
    }

    ref Resource opAssign(Resource rhs)
    {
        if (detach() != 0) {
            throw new ZmqException;
        }
        m_payload = rhs.m_payload;
        if (m_payload !is null) {
            ++(m_payload.refCount);
        }
        return this;
    }

    @property bool initialized() const pure nothrow
    {
        return (m_payload !is null) && (m_payload.handle !is null);
    }

    void free()
    {
        if (m_payload !is null && m_payload.free() != 0) {
            throw new ZmqException;
        }
    }

    @property inout(void)* handle() inout pure nothrow
    {
        if (m_payload !is null) {
            return m_payload.handle;
        } else {
            return null;
        }
    }

private:
    int detach() nothrow
    {
        int rc = 0;
        if (m_payload !is null) {
            if (--(m_payload.refCount) < 1) {
                rc = m_payload.free();
            }
            m_payload = null;
        }
        return rc;
    }

    struct Payload
    {
        int refCount;
        void* handle;
        CFreeFunction freeFunc;

        int free() @trusted nothrow
        {
            int rc = 0;
            if (handle !is null) {
                rc = freeFunc(handle);
                handle = null;
                freeFunc = null;
            }
            return rc;
        }
    }
    Payload* m_payload;
}

@system unittest
{
    import std.exception: assertNotThrown, assertThrown;
    static extern(C) int myFree(void* p) nothrow
    {
        auto v = cast(int*) p;
        if (*v == 0) {
            return -1;
        } else {
            *v = 0;
            return 0;
        }
    }

    int i = 1;

    {
        // Test constructor and properties.
        auto ra = Resource(&i, &myFree);
        assert (i == 1);
        assert (ra.initialized);
        assert (ra.handle == &i);

        // Test postblit constructor
        auto rb = ra;
        assert (i == 1);
        assert (rb.initialized);
        assert (rb.handle == &i);

        {
            // Test properties and free() with default-initialized object.
            Resource rc;
            assert (!rc.initialized);
            assert (rc.handle == null);
            assertNotThrown(rc.free());

            // Test assignment, both with and without detachment
            rc = rb;
            assert (i == 1);
            assert (rc.initialized);
            assert (rc.handle == &i);

            int j = 2;
            auto rd = Resource(&j, &myFree);
            assert (rd.handle == &j);
            rd = rb;
            assert (j == 0);
            assert (i == 1);
            assert (rd.handle == &i);

            // Test explicit free()
            int k = 3;
            auto re = Resource(&k, &myFree);
            assertNotThrown(re.free());
            assert(k == 0);

            // Test failure to free and assign (myFree(&k) fails when k == 0)
            re = Resource(&k, &myFree);
            assertThrown!ZmqException(re.free()); // We defined free(k == 0) as an error
            re = Resource(&k, &myFree);
            assertThrown!ZmqException(re = rb);
        }

        // i should not be "freed" yet
        assert (i == 1);
        assert (ra.handle == &i);
        assert (rb.handle == &i);
    }
    // ...but now it should.
    assert (i == 0);
}


version(unittest) private string uniqueUrl(string p, int n = __LINE__)
{
    import std.uuid;
    return p ~ "://" ~ randomUUID().toString();
}


private auto trusted(alias func, Args...)(Args args) @trusted
{
    return func(args);
}


// std.string.toStringz() is unsafe, so we provide our own implementation
// tailored to the string sizes we are likely to encounter here.
// Note that this implementation requires that the string be used immediately
// upon return, and not stored, as the buffer will be reused most of the time.
const char* zeroTermString(const char[] s) nothrow
{
    import std.algorithm: max;
    static char[] buf;
    immutable len = s.length + 1;
    if (buf.length < len) buf.length = max(len, 1023);
    buf[0 .. s.length] = s;
    buf[s.length] = '\0';
    return buf.ptr;
}

@system unittest
{
    auto c1 = zeroTermString("Hello World!");
    assert (c1[0 .. 13] == "Hello World!\0");
    auto c2 = zeroTermString("foo");
    assert (c2[0 .. 4] == "foo\0");
    assert (c1 == c2);
}
