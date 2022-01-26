module hwclient;

import std.stdio;
import zmqd;

//  Hello World client

void main()
{
    writeln ("Connecting to hello world server...");
    auto requester = Socket(SocketType.req);
    requester.connect("tcp://localhost:5555");

    foreach (int requestNbr; 0..10) 
    {
        ubyte[10] buffer;
        writefln("Sending Hello #%s", requestNbr);
        requester.send("Hello");
        requester.receive(buffer);
        writefln("Received: %s #%s", cast(string)buffer, requestNbr);
    }
}
