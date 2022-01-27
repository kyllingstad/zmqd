module examples.lbbroker2;

import std.stdio;
import std.concurrency;
import std.range;
import std.conv;

import core.thread;

import zmqd;
import zhelpers;

enum clientCount = 10;
enum workerCount = 3;

void main()
{
    auto frontend = Socket(SocketType.router);
    frontend.linger = infiniteDuration;
    frontend.bind("tcp://*:5672");

    auto backend = Socket(SocketType.router);
    backend.linger = infiniteDuration;
    backend.bind("tcp://*:5673");

    // starts clients
    foreach (const int i; 0 .. clientCount)
        spawn(&clientTask, i);

    // start workers
    foreach (const int i; 0 .. workerCount)
        spawn(&workerTask, i);

    //  main task body
    //  Here is the main loop for the least-recently-used queue. It has two
    //  sockets; a frontend for clients and a backend for workers. It polls
    //  the backend in all cases, and polls the frontend only when there are
    //  one or more workers ready. This is a neat way to use 0MQ's own queues
    //  to hold messages we're not ready to process yet. When we get a client
    //  request, we pop the next available worker and send the request to it,
    //  including the originating client identity. When a worker replies, we
    //  requeue that worker and forward the reply to the original client
    //  using the reply envelope.

    //  Queue of available workers
    string[] availableWorkers;
    int requestsServed = 0;
    while (true)
    {
        PollItem[] items = [
            PollItem(backend, PollFlags.pollIn),
            PollItem(frontend, PollFlags.pollIn)
        ];

        //  Poll frontend only if we have available workers
        poll(availableWorkers.length ? items : items[0..1]);

        // handle worker activity on backend
        if (items[0].returnedEvents & PollFlags.pollIn)
        {
            // worker-id for load balancing
            string workerId = backend.sRecv;
            availableWorkers ~= workerId;

            // second frame is empty
            string delimiter = backend.sRecv;
            assert(delimiter.empty);

            // third frame is READY or else a client reply id
            string clientId = backend.sRecv;
            if (clientId != "READY")
            {
                delimiter = backend.sRecv;
                assert(delimiter.empty);
                auto reply = backend.sRecv;
                frontend.send(clientId, true);
                frontend.send("", true);
                frontend.send(reply);
                // exit once all clients are served
                if (++requestsServed == clientCount)
                    break;
            }
        }

        //  Here is how we handle a client request:
        if (items[1].returnedEvents & PollFlags.pollIn)
        {
            string clientId = frontend.sRecv;
            string delimiter = frontend.sRecv;
            assert(delimiter.empty);
            string request = frontend.sRecv;

            //  Dequeue and drop the next worker identity
            string worker = availableWorkers.front;
            availableWorkers.popFront;
            backend.send(worker, true);
            backend.send("", true);
            backend.send(clientId, true);
            backend.send("", true);
            backend.send(request);

        }
    }
    import core.stdc.stdlib : exit;
    exit(0);
}

//  While this example runs in a single process, that is just to make
//  it easier to start and stop the example. Each thread has its own
//  context and conceptually acts as a separate process.
//  Basic request-reply client using REQ socket
//  Because s_send and s_recv can't handle 0MQ binary identities, we
//  set a printable text identity to allow routing.
void clientTask(int clientNumber)
{
    Context ctx = Context();
    auto socket = Socket(ctx, SocketType.req);
    socket.identity = clientNumber.to!string;
    socket.linger = infiniteDuration;
    socket.connect("tcp://localhost:5672");

    socket.send("HELLO");
    string reply = socket.sRecv;
    writefln("Client [%s]: %s", clientNumber, reply);
}

//  worker task
//  While this example runs in a single process, that is just to make
//  it easier to start and stop the example. Each thread has its own
//  context and conceptually acts as a separate process.
//  This is the worker task, using a REQ socket to do load-balancing.
//  Because s_send and s_recv can't handle 0MQ binary identities, we
//  set a printable text identity to allow routing.

void workerTask(int workerNumber)
{
    Context ctx = Context();
    auto worker = Socket(ctx, SocketType.req);
    worker.identity = workerNumber.to!string;
    worker.connect("tcp://localhost:5673");

    worker.send("READY");
    while (true)
    {
        import core.time : seconds;

        //  Read and save all frames until we get an empty frame
        //  In this example there is only 1, but there could be more
        string identity = worker.sRecv;
        string delimiter = worker.sRecv;
        assert(delimiter.empty);

        string request = worker.sRecv;
        writefln("Worker: [%s], %s", workerNumber, request);
        worker.send(identity, true);
        worker.send("", true);
        worker.send("OK");
    }
}
