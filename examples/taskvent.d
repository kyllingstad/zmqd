// Task ventilator
// Binds PUSH socket to tcp://localhost:5557
// Sends batch of tasks to workers via that socket
import std.format, std.random, std.stdio;
import zmqd;

void main ()
{
    // Socket to send messages on
    auto sender = Socket(SocketType.push);
    sender.bind("tcp://*:5557");

    // Socket to send start of batch message on
    auto sink = Socket(SocketType.push);
    sink.connect("tcp://localhost:5558");

    write("Press Enter when the workers are ready: ");
    stdout.flush();
    stdin.readln();
    writeln("Sending tasks to workers…");

    // The first message is "0" and signals start of batch
    sink.send("0");

    // Send 100 tasks
    int msecTotal = 0; // Total expected cost in msecs
    for (int taskNbr = 0; taskNbr < 100; ++taskNbr) {
        // Random workload from 1 to 100msecs
        immutable workload = uniform(1, 101);
        msecTotal += workload;
        sender.send(format("%d", workload));
    }
    writefln("Total expected cost: %d msec", msecTotal);
}

