import std.stdio;
import core.thread;

import zmqd;
import zhelpers;

void main()
{
    auto sub = Socket(SocketType.sub);
    sub.connect("tcp://localhost:5563");
    sub.subscribe("B");

    while (true)
    {
        string addr = sub.sRecv;
        string contents = sub.sRecv;
        writefln("[%s] %s", addr, contents);
    }
}
