void zapHandler()
{
    immutable metadata = cast(immutable(ubyte)[]) [
        5, 'H', 'e', 'l', 'l', 'o',
        0, 0, 0, 5, 'W', 'o', 'r', 'l', 'd'
    ];

    import zmqd;
    auto handler = Socket(SocketType.rep);
    handler.bind("inproc://zeromq.zap.01");

    // Process ZAP requests forever
    try {
        while (true) {
            import zhelpers: sRecv;
            immutable version_  = sRecv(handler);
            immutable sequence  = sRecv(handler);
            immutable domain    = sRecv(handler);
            immutable address   = sRecv(handler);
            immutable identity  = sRecv(handler);
            immutable mechanism = sRecv(handler);

            assert (version_ == "1.0");
            assert (mechanism == "NULL");

            handler.send(version_, true);
            handler.send(sequence, true);
            if (domain == "DOMAIN") {
                handler.send("200", true);
                handler.send("OK", true);
                handler.send("anonymous", true);
                handler.send(metadata);
            } else {
                handler.send("400", true);
                handler.send("BAD DOMAIN", true);
                handler.send("", true);
                handler.send("");
            }
        }
    } catch (ZmqException e) {
        import deimos.zmq.zmq: ETERM;
        assert (e.errno == ETERM);
    }
}

void main()
{
    import core.thread: Thread;
    auto zapThread = new Thread(&zapHandler);
    zapThread.start();

    import zmqd;
    auto server = Socket(SocketType.dealer);
    auto client = Socket(SocketType.dealer);
    server.zapDomain = "DOMAIN";
    server.bind("tcp://127.0.0.1:9001");
    client.connect("tcp://127.0.0.1:9001");

    client.send("This is a message");
    auto msg = Frame();
    server.receive(msg);
    assert (msg.metadata("Hello") == "World");
    assert (msg.metadata("Socket-Type") == "DEALER");
    assert (msg.metadata("User-Id") == "anonymous");
    assert (msg.metadata("Peer-Address") == "127.0.0.1");
    import std.exception: assertThrown;
    assertThrown!ZmqException(msg.metadata("No Such"));
    msg.close();

    client.close();
    server.close();

    // Shutdown
    defaultContext().terminate();

    // Wait until ZAP handler terminates
    zapThread.join();
}
