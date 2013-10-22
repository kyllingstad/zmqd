module zmqd;

import std.typecons;
import deimos.zmq.zmq;


version(Windows) {
    alias SOCKET = size_t;
}


Tuple!(int, "major", int, "minor", int, "patch") zmqVersion()
{
    typeof(return) v;
    zmq_version(&v.major, &v.minor, &v.patch);
    return v;
}


struct Context
{
    static Context opCall()
    {
        if (auto c = zmq_ctx_new()) {
            Context ctx;
            ctx.m_resource = Resource(c, &zmq_ctx_destroy);
            return ctx;
        } else {
            throw new ZmqException;
        }
    }

    void destroy()
    {
        m_resource.free();
    }

    @property int ioThreads()
    {
        return getOption(ZMQ_IO_THREADS);
    }

    @property void ioThreads(int value)
    {
        setOption(ZMQ_IO_THREADS, value);
    }

    @property int maxSockets()
    {
        return getOption(ZMQ_MAX_SOCKETS);
    }

    @property void maxSockets(int value)
    {
        setOption(ZMQ_MAX_SOCKETS, value);
    }

    @property void* handle()
    {
        return m_resource.handle;
    }

    @property bool initialized()
    {
        return m_resource.initialized;
    }

private:
    int getOption(int option)
    {
        immutable value =  zmq_ctx_get(m_resource.handle, option);
        if (value < 0) {
            throw new ZmqException;
        }
        return value;
    }

    void setOption(int option, int value)
    {
        if (zmq_ctx_set(m_resource.handle, option, value) != 0) {
            throw new ZmqException;
        }
    }

    Resource m_resource;
}


Context defaultContext()
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


enum SocketType
{
    req     = ZMQ_REQ,
    rep     = ZMQ_REP,
    dealer  = ZMQ_DEALER,
    router  = ZMQ_ROUTER,
    pub     = ZMQ_PUB,
    sub     = ZMQ_SUB,
    xpub    = ZMQ_XPUB,
    xsub    = ZMQ_XSUB,
    push    = ZMQ_PUSH,
    pull    = ZMQ_PULL,
    pair    = ZMQ_PAIR,
}


struct Socket
{
    this(SocketType type)
    {
        this(defaultContext(), type);
    }

    this(Context ctx, SocketType type)
    {
        if (auto s = zmq_socket(ctx.handle, type)) {
            m_context = ctx;
            m_type = type;
            m_socket = Resource(s, &zmq_close);
        } else {
            throw new ZmqException;
        }
    }

    void bind(const char[] endpoint)
    {
        import std.string;
        if (zmq_bind(m_socket.handle, toStringz(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    void unbind(const char[] endpoint)
    {
        import std.string;
        if (zmq_unbind(m_socket.handle, toStringz(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    void connect(const char[] endpoint)
    {
        import std.string;
        if (zmq_connect(m_socket.handle, toStringz(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    void disconnect(const char[] endpoint)
    {
        import std.string;
        if (zmq_disconnect(m_socket.handle, toStringz(endpoint)) != 0) {
            throw new ZmqException;
        }
    }

    // TODO: DONTWAIT and SNDMORE flags
    void send(const void[] data)
    {
        if (zmq_send(m_socket.handle, data.ptr, data.length, 0) < 0) {
            throw new ZmqException;
        }
    }

    size_t receive(void[] data)
    {
        const len = zmq_recv(m_socket.handle, data.ptr, data.length, 0);
        if (len >= 0) {
            import std.conv;
            return to!size_t(len);
        } else {
            throw new ZmqException;
        }
    }

    @property SocketType type() { return getOption!SocketType(ZMQ_TYPE); }

    @property bool receiveMore() { return !!getOption!int(ZMQ_RCVMORE); }

    @property int sendHWM() { return getOption!int(ZMQ_SNDHWM); }
    @property void sendHWM(int value) { setOption(ZMQ_SNDHWM, value); }

    @property int receiveHWM() { return getOption!int(ZMQ_RCVHWM); }
    @property void receiveHWM(int value) { setOption(ZMQ_RCVHWM, value); }

    @property ulong threadAffinity() { return getOption!ulong(ZMQ_AFFINITY); }
    @property void threadAffinity(ulong value) { setOption(ZMQ_AFFINITY, value); }

    @property ubyte[] identity()
    {
        auto buf = new ubyte[255];
        size_t len = buf.length;
        if (zmq_getsockopt(m_socket.handle, ZMQ_IDENTITY, buf.ptr, &len) != 0) {
            throw new ZmqException;
        }
        return buf[0 .. len];
    }
    @property char[] identityText()
    {
        auto s = cast(char[]) identity;
        import std.utf;
        validate(s);
        return s;
    }
    @property void identity(const ubyte[] value) { setOption(ZMQ_IDENTITY, value); }
    @property void identity(const  char[] value) { setOption(ZMQ_IDENTITY, value); }

    @property int rate() { return getOption!int(ZMQ_RATE); }
    @property void rate(int value) { setOption(ZMQ_RATE, value); }

    @property int recoveryInterval() { return getOption!int(ZMQ_RECOVERY_IVL); }
    @property void recoveryInterval(int value) { setOption(ZMQ_RECOVERY_IVL, value); }

    @property int sendBufferSize() { return getOption!int(ZMQ_SNDBUF); }
    @property void sendBufferSize(int value) { setOption(ZMQ_SNDBUF, value); }

    @property int receiveBufferSize() { return getOption!int(ZMQ_RCVBUF); }
    @property void receiveBufferSize(int value) { setOption(ZMQ_RCVBUF, value); }

    @property int linger() { return getOption!int(ZMQ_LINGER); }
    @property void linger(int value) { setOption(ZMQ_LINGER, value); }

    @property int reconnectionInterval() { return getOption!int(ZMQ_RECONNECT_IVL); }
    @property void reconnectionInterval(int value) { setOption(ZMQ_RECONNECT_IVL, value); }

    @property int maxReconnectionInterval() { return getOption!int(ZMQ_RECONNECT_IVL_MAX); }
    @property void maxReconnectionInterval(int value) { setOption(ZMQ_RECONNECT_IVL_MAX, value); }

    @property int backlog() { return getOption!int(ZMQ_BACKLOG); }
    @property void backlog(int value) { setOption(ZMQ_BACKLOG, value); }

    @property long maxMsgSize() { return getOption!long(ZMQ_MAXMSGSIZE); }
    @property void maxMsgSize(long value) { setOption(ZMQ_MAXMSGSIZE, value); }

    @property int multicastHops() { return getOption!int(ZMQ_MULTICAST_HOPS); }
    @property void multicastHops(int value) { setOption(ZMQ_MULTICAST_HOPS, value); }

    @property int receiveTimeout() { return getOption!int(ZMQ_RCVTIMEO); }
    @property void receiveTimeout(int value) { setOption(ZMQ_RCVTIMEO, value); }

    @property int sendTimeout() { return getOption!int(ZMQ_SNDTIMEO); }
    @property void sendTimeout(int value) { setOption(ZMQ_SNDTIMEO, value); }

    @property bool ipv4Only() { return !!getOption!int(ZMQ_IPV4ONLY); }
    @property void ipv4Only(bool value) { setOption(ZMQ_IPV4ONLY, value ? 1 : 0); }

    @property bool delayAttachOnConnect() { return !!getOption!int(ZMQ_DELAY_ATTACH_ON_CONNECT); }
    @property void delayAttachOnConnect(bool value) { setOption(ZMQ_DELAY_ATTACH_ON_CONNECT, value ? 1 : 0); }

    version (Windows) {
        alias FD = SOCKET;
    } else version (Posix) {
        alias FD = int;
    }
    @property FD fd() { return getOption!FD(ZMQ_FD); }
    @property int events() { return getOption!int(ZMQ_EVENTS); }
    @property char[] lastEndpoint()
    {
        auto buf = new char[1024];
        size_t len = buf.length;
        if (zmq_getsockopt(m_socket.handle, ZMQ_LAST_ENDPOINT, buf.ptr, &len) != 0) {
            throw new ZmqException;
        }
        return buf[0 .. len-1];
    }

    // TODO: Some low-level options are missing still, plus setters for
    // ZMQ_ROUTER_MANDATORY and ZMQ_XPUB_VERBOSE.

    void subscribe(const ubyte[] filterPrefix) { setOption(ZMQ_SUBSCRIBE, filterPrefix); }
    void subscribe(const  char[] filterPrefix) { setOption(ZMQ_SUBSCRIBE, filterPrefix); }
    void unsubscribe(const ubyte[] filterPrefix) { setOption(ZMQ_UNSUBSCRIBE, filterPrefix); }
    void unsubscribe(const  char[] filterPrefix) { setOption(ZMQ_UNSUBSCRIBE, filterPrefix); }

private:
    T getOption(T)(int option)
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
        zmq_setsockopt(m_socket.handle, option, value.ptr, value.length);
    }

    import std.traits;
    void setOption(T)(int option, T value) if (isScalarType!T)
    {
        zmq_setsockopt(m_socket.handle, option, &value, value.sizeof);
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
    char[12] cbuf;
    const clen = s2.receive(cbuf[]);
    assert (clen == 12);
    assert (cbuf == "Hello World!");
    s2.send([1.0, 3.14, 9.81, 2.718]);
    double[3] dbuf;
    const dlen = s1.receive(dbuf[]);
    assert (dlen == 4*double.sizeof);
    assert (dbuf == [1.0, 3.14, 9.81]);
}

unittest
{
    // We test all the socket options by checking that they have their default value.
    auto s = Socket(SocketType.xpub);
    const e = "inproc://unittest2";
    s.bind(e);
    assert(s.type == SocketType.xpub);
    assert(!s.receiveMore);
    assert(s.sendHWM == 1000);
    assert(s.receiveHWM == 1000);
    assert(s.threadAffinity == 0);
    assert(s.identity == null);
    assert(s.identityText == "");
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
    assert(s.identityText == "ABC");
    s.identity = "foo";
    assert(s.identity == [102, 111, 111]);
    assert(s.identityText == "foo");
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

unittest
{
    // See http://zguide.zeromq.org/page:all#Getting-the-Message-Out for an
    // explanation of why we need sleep().
    void sleep(int ms) {
        import core.thread, core.time;
        Thread.sleep(dur!"msecs"(ms));
    }
    auto pub = Socket(SocketType.pub);
    auto sub = Socket(SocketType.sub);
    pub.bind("inproc://unittest3");
    sub.connect("inproc://unittest3");
    pub.send("Hello");
    sleep(100);
    sub.subscribe("He");
    sub.subscribe(cast(ubyte[])['W', 'o']);
    sleep(100);
    pub.send("Heeee");
    pub.send("World");
    sleep(100);
    char bbuf[5];
    char cbuf[5];
    sub.receive(bbuf);
    sub.receive(cbuf);
    assert(bbuf[] == cast(ubyte[])['H', 'e', 'e', 'e', 'e']);
    assert(cbuf[] == "World");
}



class ZmqException : Exception
{
    this(string file = __FILE__, int line = __LINE__)
    {
        import core.stdc.errno, std.conv;
        this.errno = core.stdc.errno.errno;
        super(to!string(zmq_strerror(this.errno)), file, line);
    }
    immutable int errno;
}


private:

struct Resource
{
    import std.typecons: RefCounted;
    alias extern(C) int function(void*) CFreeFunction;

    this(void* handle, CFreeFunction freeFunc)
        in { assert(handle !is null); } body
    {
        m_payload = Payload(handle, freeFunc);
    }

    @property bool initialized()
    {
        return handle !is null;
    }

    void free()
    {
        if (initialized) {
            if (m_payload.free(m_payload.handle) != 0) {
                throw new ZmqException;
            }
            m_payload.handle = null;
            m_payload.free = null;
        }
    }

    @property void* handle()
    {
        return m_payload.handle;
    }

private:
    struct Payload
    {
        void* handle;
        CFreeFunction free;
        ~this() { if (this.handle != null) this.free(this.handle); }
    }
    RefCounted!Payload m_payload;
}
