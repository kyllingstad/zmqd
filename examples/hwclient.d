// Hello World client
import std.stdio, std.string;
import zmqd;

void main()
{
    writeln("Connecting to hello world server…");
    auto requester = Socket(SocketType.req);
    requester.connect("tcp://localhost:5555");

    for (int requestNbr = 0; requestNbr < 10; ++requestNbr) {
        writefln("Sending Hello %d…", requestNbr);
        requester.send("Hello".representation);
        ubyte[10] buffer;
        requester.receive(buffer);
        writefln("Received World %d", requestNbr);
    }
}
