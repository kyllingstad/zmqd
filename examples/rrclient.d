// Hello World client
// Connects REQ socket to tcp://localhost:5559
// Sends "Hello" to server, expects "World" back
import std.stdio;
import zmqd;
import zhelpers;

void main()
{
    // Socket to talk to server
    auto requester = Socket(SocketType.req);
    requester.connect("tcp://localhost:5559");

    foreach (int requestNbr; 1..11) 
    {
        requester.send("Hello");
        auto str = sRecv(requester);
        writefln("Received reply %d [%s]", requestNbr, str);
    }
}