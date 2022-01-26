import std.stdio;
import core.thread;
import core.time;
import std.conv;

import zmqd;

enum subscribersExpected = 10;

void main()
{
    auto publisher = Socket(SocketType.pub);
    publisher.sendHWM = 1_100_000;
    // zmqd sets the linger period to 0, but the libzmq default is
    // infinite. We must reset it to infinite, otherwise the example won't
    // work
    publisher.linger = infiniteDuration;
    publisher.bind("tcp://*:5561");

    // Synchronize with publisher
    auto service = Socket(SocketType.rep);
    service.bind("tcp://*:5562");

    writeln("Waiting for subscribers");
    foreach (int subscribers; 0 .. subscribersExpected)
    {
        ubyte[256] buffer;
        service.receive(buffer);
        service.send("");
    }

    writeln("Broadcasting messages");
    foreach (int updateNbr; 0 .. 1_000_000)
    {
        publisher.send("A message");    
    }
    writeln("END");
    publisher.send("END");
}