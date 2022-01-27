module taskvent;
import std.random;
import std.stdio;
import std.format;

import zmqd;

void main()
{
    // socket to send messages on
    auto sender = Socket(SocketType.push);
    sender.bind("tcp://*:5557");

    // socket to send start of batch message on
    auto sink = Socket(SocketType.push);
    sink.connect("tcp://localhost:5558");

    writeln("Press Enter when the workers are ready: ");
    stdout.flush();
    stdin.readln();
    writeln("Sending tasks to workers …");
    // The first message is "0" and signals start of batch
    sink.send("0");

    // send 100 tasks
    int totalMsec;
    foreach (int taskNbr; 0 .. 100)
    {
        auto workload = uniform(1, 101);
        totalMsec += workload;
        sender.send("%s".format(workload));
    }
    writefln("Total expected cost: %s msec", totalMsec);
}