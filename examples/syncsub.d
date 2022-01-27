import std.stdio;
import core.thread;
import core.time;
import std.conv;
import std.exception;
import std.string;
import zmqd;
import zhelpers;


void main()
{
    auto subscriber = Socket(SocketType.sub);
    subscriber.receiveHWM = 1_100_000;
    subscriber.sendHWM = 1_100_000;
    subscriber.connect("tcp://localhost:5561");
    subscriber.subscribe("");
    subscriber.receiveTimeout = 2.seconds;

    //  0MQ is so fast, we need to wait a while …
    Thread.sleep(5.seconds);

    // Synchronize with publisher
    auto client = Socket(SocketType.req);
    client.connect("tcp://localhost:5562");
    client.send("");
    client.sRecv();

    int updateNbr = 0;
    string msg;
    try {
    while (true) {
        msg = subscriber.sRecv;
        if (msg == "END")
            break;
        updateNbr += 1;
    }
    writefln("Received %s updates", updateNbr);

    } catch(Exception)
    {
        writefln("ex: after %s (%s)", updateNbr, msg);
    }
}