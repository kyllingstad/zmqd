// Multithreaded relay
import core.thread, core.time;
import std.stdio;
import zmqd, zhelpers;

void step1()
{
    // Connect to step2 and tell it we're ready
    auto xmitter = Socket(SocketType.pair);
    xmitter.connect("inproc://step2");
    writeln("Step 1 ready, signaling step 2");
    xmitter.send("READY");
}

void step2()
{
    // Bind inproc socket before starting step1
    auto receiver = Socket(SocketType.pair);
    receiver.bind("inproc://step2");
    (new Thread(&step1)).start();

    // Wait for signal and pass it on
    sRecv(receiver);

    // Connect to step3 and tell it we're ready
    auto xmitter = Socket(SocketType.pair);
    xmitter.connect("inproc://step3");
    writeln("Step 2 ready, signaling step 3");
    xmitter.send("READY");
}

void main()
{
    // Bind inproc socket before starting step2
    auto receiver = Socket(SocketType.pair);
    receiver.bind("inproc://step3");
    (new Thread(&step2)).start();

    // Wait for signal
    sRecv(receiver);

    writeln("Test successful!");
}
