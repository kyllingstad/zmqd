// Multithreaded Hello World server
import core.thread, core.time;
import std.stdio;
import zmqd, zhelpers;

void workerRoutine()
{
    // Socket to talk to dispatcher
    auto receiver = Socket(SocketType.rep);
    receiver.connect("inproc://workers");

    while (true) {
        auto str = sRecv(receiver);
        writefln("Received request: [%s]", str);
        // Do some 'work'
        Thread.sleep(1.msecs);
        // Send reply back to client
        receiver.send("World");
    }
}

void main()
{
    // Socket to talk to clients
    auto clients = Socket(SocketType.router);
    clients.bind("tcp://*:5555");

    // Socket to talk to workers
    auto workers = Socket(SocketType.dealer);
    workers.bind("inproc://workers");

    // Launch pool of worker threads
    foreach (threadNbr; 0 .. 5) {
        (new Thread(&workerRoutine)).start();
    }
    // Connect work threads to client threads via a queue proxy
    proxy(clients, workers);
}
