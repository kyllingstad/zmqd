// ROUTER-to-REQ example
import core.thread;
import std.stdio;
import zmqd, zhelpers;

enum nbrWorkers = 10;

void workerTask()
{
    auto context = Context();
    auto worker = Socket(context, SocketType.dealer);
    sSetId(worker); // Set a printable identity
    worker.connect("tcp://localhost:5671");

    for (int total = 0; ; ++total) {
        // Tell the broker we're ready for work
        worker.send("", true);
        worker.send("Hi Boss");

        // Get workload from broker, until finished
        sRecv(worker); // Envelope delimiter
        if (sRecv(worker) == "Fired!") {
            writefln("Completed: %d tasks", total);
            break;
        }

        // Do some random work
        import std.random: uniform;
        Thread.sleep((uniform(0, 500)+1).msecs);
    }
}

// While this example runs in a single process, that is only to make
// it easier to start and stop the example. Each thread has its own
// context and conceptually acts as a separate process.

void main()
{
    auto context = Context();
    auto broker = Socket(context, SocketType.router);
    broker.bind("tcp://*:5671");

    for (int workerNbr = 0; workerNbr < nbrWorkers; ++workerNbr) {
        (new Thread(&workerTask)).start();
    }
    // Run for five seconds and then tell workers to end
    import std.datetime;
    const endTime = Clock.currTime() + 5.seconds;
    int workersFired = 0;
    while (true) {
        // Next message gives us least recently used worker
        broker.send(sRecv(broker), true);
        sRecv(broker); // Envelope delimiter
        sRecv(broker); // Response from worker
        broker.send("", true);

        // Encourage workers until it's time to fire them
        if (Clock.currTime() < endTime) {
            broker.send("Work harder");
        } else {
            broker.send("Fired!");
            if (++workersFired == nbrWorkers) break;
        }
    }
}

