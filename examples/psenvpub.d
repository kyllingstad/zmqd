import std.stdio;
import core.thread;

import zmqd;

void main()
{
    auto socket = Socket(SocketType.pub);
    socket.bind("tcp://*:5563");

    while (true)
    {
        socket.send("A", true);
        socket.send("We don't want to see this");
        socket.send("B", true);
        socket.send("We would like to see this");
        Thread.sleep(1.seconds);
    }
}

