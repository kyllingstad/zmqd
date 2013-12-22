// Task sink
// Binds PULL socket to tcp://localhost:5558
// Collects results from workers via that socket
import std.datetime, std.stdio;
import zmqd, zhelpers;

void main()
{
    // Prepare our context and socket
    auto receiver = Socket(SocketType.pull);
    receiver.bind("tcp://*:5558");

    // Wait for start of batch
    sRecv(receiver);

    // Start our clock now
    import std.datetime;
    StopWatch watch;
    watch.start();

    // Process 100 confirmations
    for (int taskNbr = 0; taskNbr < 100; ++taskNbr) {
        sRecv(receiver);
        if ((taskNbr / 10) * 10 == taskNbr) {
            write(":");
        } else {
            write(".");
        }
        stdout.flush();
    }
    // Calculate and report duration of batch
    watch.stop();
    writefln("Total elapsed time: %d msec\n", watch.peek().msecs);
}
