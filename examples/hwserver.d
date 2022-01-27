module hwserver;

import core.thread, core.time;
import std.stdio : writeln, writefln;
import std.conv : to;
import zmqd;

void main()
{
    //  Socket to talk to clients
    auto responder = Socket(SocketType.rep);
    responder.bind("tcp://*:5555");

    while (true) {
        ubyte[10] buffer;
        responder.receive(buffer);
        writefln("Received: \"%s\"", cast(string)buffer);
        Thread.sleep(1.seconds);
        responder.send("World");
    }
}
