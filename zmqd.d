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

Authors:
    $(LINK2 http://github.com/kyllingstad,Lars T. Kyllingstad)
Copyright:
    Copyright (c) 2013, Lars T. Kyllingstad
License:
    $(ZMQD) is released under the $(LINK2 http://www.boost.org/LICENSE_1_0.txt,
    Boost Software License, version 1.0).$(BR)
    Please refer to the $(LINK2 http://zeromq.org/area:licensing,$(ZMQ) site)
    for details about $(ZMQ) licensing.
Macros:
    D      = <code>$0</code>
    EM     = <em>$0</em>
    LDOTS  = &hellip;
    QUOTE  = <blockquote>$0</blockquote>
    REF    = $(D $(LINK2 #$1,$1))
    STDREF = $(D $(LINK2 http://dlang.org/phobos/std_$1.html#.$2,std.$1.$2))
    ZMQ    = &#x2205;MQ
    ZMQAPI = $(LINK2 http://api.zeromq.org/3-2:$1,$+)
    ZMQD   = $(ZMQ)D
    ZMQREF = $(D $(ZMQAPI $1,$1))
*/
module zmqd;

import std.typecons;
import deimos.zmq.zmq;


version(Windows) {
    alias SOCKET = size_t;
}


/**
Reports the $(ZMQ) library version.

Returns:
    A $(STDREF typecons,Tuple) with three integer fields that represent the
    three versioning levels: $(D major), $(D minor) and $(D patch).
Corresponds_to:
    $(ZMQREF zmq_version())
*/
Tuple!(int, "major", int, "minor", int, "patch") zmqVersion() @safe nothrow
{
    typeof(return) v;
    trusted!zmq_version(&v.major, &v.minor, &v.patch);
    return v;
}


/**
An object that encapsulates a $(ZMQ) context.

In most programs, it is not necessary to use this type directly,
as $(REF Socket) will use a default global context if not explicitly
provided with one.  See $(REF defaultContext) for details.

A default-initialized $(D Context) is not a valid $(ZMQ) context; it
must always be explicitly initialized with $(REF _Context.opCall):
---
Context ctx;        // Not a valid context yet
ctx = Context();    // ...but now it is.
---
$(D Context) objects can be passed around by value, and two copies will
refer to the same context.  The underlying context is managed using
reference counting, so that when the last copy of a $(D Context) goes
out of scope, the context is automatically destroyed.

See_also:
    $(REF defaultContext)
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
    @trusted unittest // TODO: Remove @trusted for DMD 2.064
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

These are described in the $(ZMQREF zmq_socket()) reference.  They are
almost always referred to by their abbreviation (e.g. REQ for a "request"
socket), so those names are used here as well.
*/
enum SocketType
{
    req     = ZMQ_REQ,      ///
    rep     = ZMQ_REP,      ///
    dealer  = ZMQ_DEALER,   ///
    router  = ZMQ_ROUTER,   ///
    pub     = ZMQ_PUB,      ///
    sub     = ZMQ_SUB,      ///
    xpub    = ZMQ_XPUB,     ///
    xsub    = ZMQ_XSUB,     ///
    push    = ZMQ_PUSH,     ///
    pull    = ZMQ_PULL,     ///
    pair    = ZMQ_PAIR,     ///
}


/**
An object that encapsulates a $(ZMQ) socket.

A default-initialized $(D Socket) is not a valid $(ZMQ) socket; it
must always be explicitly initialized with a constructor (see
$(REF _Socket.this)):
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
    by $(REF defaultContext)) is used.

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
            // TODO: Replace the next line with the one below for DMD 2.064
            (Context c) @trusted { m_context = c; } (context);
            // m_context = ctx;
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

    The $(D char[]) overload is a convenience function that simply casts the
    string to $(D ubyte[]).

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_send())
    */
    // TODO: DONTWAIT and SNDMORE flags
    void send(const ubyte[] data)
    {
        if (trusted!zmq_send(m_socket.handle, data.ptr, data.length, 0) < 0) {
            throw new ZmqException;
        }
    }

    /// ditto
    void send(const char[] data) @trusted
    {
        send(cast(ubyte[]) data);
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

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_send())
    */
    void send(ref Message msg)
    {
        if (trusted!zmq_msg_send(msg.handle, m_socket.handle, 0) < 0) {
            throw new ZmqException;
        }
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

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_recv())
    */
    size_t receive(ubyte[] data)
    {
        const len = trusted!zmq_recv(m_socket.handle, data.ptr, data.length, 0);
        if (len >= 0) {
            import std.conv;
            return to!size_t(len);
        } else {
            throw new ZmqException;
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
        char[12] buf;
        rcv.receive(buf.representation);
        assert (buf[] == "Hello World!");
    }

    /**
    Receives a message part.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_recv())
    */
    void receive(ref Message msg)
    {
        if (trusted!zmq_msg_recv(msg.handle, m_socket.handle, 0) < 0) {
            throw new ZmqException;
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

    /**
    The socket _type.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_getsockopt()) with $(D ZMQ_TYPE).
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
        $(ZMQREF zmq_msg_getsockopt()) with $(D ZMQ_RCVMORE).
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
    $(ZMQREF zmq_msg_getsockopt()) and $(ZMQREF zmq_msg_setsockopt()). For
    example, $(D identity) corresponds to $(D ZMQ_IDENTITY),
    $(D receiveBufferSize) corresponds to $(D ZMQ_RCVBUF), etc.

    Notes:
    $(UL
        $(LI For convenience, the setter for the $(D identity) property
            accepts strings.  To retrieve a string with the getter, use
            the $(REF asString) function.
            ---
            sck.identity = "foobar";
            assert (sck.identity.asString() == "foobar");
            ---
            )
        $(LI The $(D fd) property is an $(D int) on POSIX and a $(D SOCKET)
            on Windows.)
        $(LI The $(D ZMQ_SUBSCRIBE) and $(D ZMQ_UNSUBSCRIBE) options are
            treated differently from the others; see $(REF Socket.subscribe)
            and $(REF Socket.unsubscribe))
    )

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_getsockopt()) and $(ZMQREF zmq_msg_setsockopt()).
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
    @property int recoveryInterval() { return getOption!int(ZMQ_RECOVERY_IVL); }
    /// ditto
    @property void recoveryInterval(int value) { setOption(ZMQ_RECOVERY_IVL, value); }

    /// ditto
    @property int sendBufferSize() { return getOption!int(ZMQ_SNDBUF); }
    /// ditto
    @property void sendBufferSize(int value) { setOption(ZMQ_SNDBUF, value); }

    /// ditto
    @property int receiveBufferSize() { return getOption!int(ZMQ_RCVBUF); }
    /// ditto
    @property void receiveBufferSize(int value) { setOption(ZMQ_RCVBUF, value); }

    /// ditto
    @property int linger() { return getOption!int(ZMQ_LINGER); }
    /// ditto
    @property void linger(int value) { setOption(ZMQ_LINGER, value); }

    /// ditto
    @property int reconnectionInterval() { return getOption!int(ZMQ_RECONNECT_IVL); }
    /// ditto
    @property void reconnectionInterval(int value) { setOption(ZMQ_RECONNECT_IVL, value); }

    /// ditto
    @property int maxReconnectionInterval() { return getOption!int(ZMQ_RECONNECT_IVL_MAX); }
    /// ditto
    @property void maxReconnectionInterval(int value) { setOption(ZMQ_RECONNECT_IVL_MAX, value); }

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
    @property int receiveTimeout() { return getOption!int(ZMQ_RCVTIMEO); }
    /// ditto
    @property void receiveTimeout(int value) { setOption(ZMQ_RCVTIMEO, value); }

    /// ditto
    @property int sendTimeout() { return getOption!int(ZMQ_SNDTIMEO); }
    /// ditto
    @property void sendTimeout(int value) { setOption(ZMQ_SNDTIMEO, value); }

    /// ditto
    @property bool ipv4Only() { return !!getOption!int(ZMQ_IPV4ONLY); }
    /// ditto
    @property void ipv4Only(bool value) { setOption(ZMQ_IPV4ONLY, value ? 1 : 0); }

    /// ditto
    @property bool delayAttachOnConnect() { return !!getOption!int(ZMQ_DELAY_ATTACH_ON_CONNECT); }
    /// ditto
    @property void delayAttachOnConnect(bool value) { setOption(ZMQ_DELAY_ATTACH_ON_CONNECT, value ? 1 : 0); }


    version (Windows) {
        alias FD = SOCKET;
    } else version (Posix) {
        alias FD = int;
    }

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
        assert(s.type == SocketType.xpub);
        assert(s.sendHWM == 1000);
        assert(s.receiveHWM == 1000);
        assert(s.threadAffinity == 0);
        assert(s.identity == null);
        assert(s.rate == 100);
        assert(s.recoveryInterval == 10_000);
        assert(s.sendBufferSize == 0);
        assert(s.receiveBufferSize == 0);
        assert(s.linger == -1);
        assert(s.reconnectionInterval == 100);
        assert(s.maxReconnectionInterval == 0);
        assert(s.backlog == 100);
        assert(s.maxMsgSize == -1);
        assert(s.multicastHops == 1);
        assert(s.receiveTimeout == -1);
        assert(s.sendTimeout == -1);
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
        s.recoveryInterval = 5_000;
        assert(s.recoveryInterval == 5_000);
        s.sendBufferSize = 500;
        assert(s.sendBufferSize == 500);
        s.receiveBufferSize = 600;
        assert(s.receiveBufferSize == 600);
        s.linger = 0;
        assert(s.linger == 0);
        s.linger = 100;
        assert(s.linger == 100);
        s.reconnectionInterval = 200;
        assert(s.reconnectionInterval == 200);
        s.maxReconnectionInterval = 300;
        assert(s.maxReconnectionInterval == 300);
        s.backlog = 50;
        assert(s.backlog == 50);
        s.maxMsgSize = 1000;
        assert(s.maxMsgSize == 1000);
        s.multicastHops = 2;
        assert(s.multicastHops == 2);
        s.receiveTimeout = 3_000;
        assert(s.receiveTimeout == 3_000);
        s.sendTimeout = 2_000;
        assert(s.sendTimeout == 2_000);
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

    @trusted unittest
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
    @trusted unittest // TODO: Remove @trusted for DMD 2.064
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


/**
An object that encapsulates a $(ZMQ) message.

This $(D struct) is a wrapper around a $(D zmq_msg_t) object.  Unlike
$(REF Context) and $(REF Socket), it does $(EM not) perform reference
counting, because $(ZMQ) messages have a form of reference counting of
their own.  A $(D Message) cannot be copied by normal assignment; use
$(REF Message.copy) for this.

A default-initialized $(D Message) is not a valid $(ZMQ) message; it
must always be explicitly initialized with $(REF _Message.opCall) or
$(REF _Message.this):
---
Message msg1;               // Invalid message
auto msg2 = Message();      // Empty message
auto msg3 = Message(1024);  // 1K message
---
When a $(D Message) goes out of scope, $(ZMQREF zmq_msg_close()) is
called on the underlying $(D zmq_msg_t).
*/
struct Message
{
@safe:
    /**
    Initialises an empty $(ZMQ) message.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_init())
    */
    static Message opCall()
    {
        Message m;
        if (trusted!zmq_msg_init(&m.m_msg) != 0) {
            throw new ZmqException;
        }
        m.m_initialized = true;
        return m;
    }

    ///
    unittest
    {
        auto msg = Message();
        assert(msg.size == 0);
    }

    /**
    Initialises a $(ZMQ) message of a specified size.

    Throws:
        $(REF ZmqException) if $(ZMQ) reports an error.
    Corresponds_to:
        $(ZMQREF zmq_msg_init_size())
    */
    this(size_t size)
    {
        if (trusted!zmq_msg_init_size(&m_msg, size) != 0) {
            throw new ZmqException;
        }
        m_initialized = true;
    }

    ///
    unittest
    {
        auto msg = Message(123);
        assert(msg.size == 123);
    }

    @disable this(this);

    /**
    Releases the $(ZMQ) message when the $(D Message) is destroyed.

    This destructor never throws, which means that any errors will go
    undetected.  If this is undesirable, call $(REF Message.close) before
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
inout(char)[] asString(inout(ubyte)[] data) @safe pure
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
@safe:
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


private:

struct Resource
{
    alias extern(C) int function(void*) nothrow CFreeFunction;

    this(void* ptr, CFreeFunction freeFunc) @safe pure nothrow
        in { assert(ptr !is null); } body
    {
        m_payload = new Payload(1, ptr, freeFunc);
    }

    this(this) @safe pure nothrow
    {
        if (m_payload !is null) {
            ++(m_payload.refCount);
        }
    }

    // TODO: This function could be @safe, if not for a weird compiler bug.
    // https://d.puremagic.com/issues/show_bug.cgi?id=11505
    ~this() @trusted nothrow
    {
        detach();
    }

    ref Resource opAssign(Resource rhs) @safe
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

    @property bool initialized() const @safe pure nothrow
    {
        return (m_payload !is null) && (m_payload.handle !is null);
    }

    void free() @safe
    {
        if (m_payload !is null && m_payload.free() != 0) {
            throw new ZmqException;
        }
    }

    @property inout(void)* handle() inout @safe pure nothrow
    {
        if (m_payload !is null) {
            return m_payload.handle;
        } else {
            return null;
        }
    }

private:
    int detach() @safe nothrow
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

unittest
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
const char* zeroTermString(const char[] s) @safe nothrow
{
    import std.algorithm: max;
    static char[] buf;
    immutable len = s.length + 1;
    if (buf.length < len) buf.length = max(len, 1023);
    buf[0 .. s.length] = s;
    buf[s.length] = '\0';
    return buf.ptr;
}

unittest
{
    auto c1 = zeroTermString("Hello World!");
    assert (c1[0 .. 13] == "Hello World!\0");
    auto c2 = zeroTermString("foo");
    assert (c2[0 .. 4] == "foo\0");
    assert (c1 == c2);
}
