// Hello World worker
// Connects REP socket to tcp://*:5560
// Expects "Hello" from client, replies with "World"
import core.time, core.thread;
import std.stdio;
import zmqd;
import zhelpers;

void main()
{
    // Socket to talk to clients
    auto responder = Socket(SocketType.rep);
    responder.connect("tcp://localhost:5560");

    while (true) {
        // Wait for next request from client
        auto str = sRecv(responder);
        writefln("Received request: [%s]", str);

        // Do some 'work'
        Thread.sleep(1.msecs);

        // Send reply back to client
        responder.send("World");
    }
    // We never get here
}

