// Task worker
// Connects PULL socket to tcp://localhost:5557
// Collects workloads from ventilator via that socket
// Connects PUSH socket to tcp://localhost:5558
// Sends results to sink via that socket
import core.thread;
import std.conv, std.stdio;
import zmqd, zhelpers;

void main()
{
    // Socket to receive messages on
    auto receiver = Socket(SocketType.pull);
    receiver.connect("tcp://localhost:5557");

    // Socket to send messages to
    auto sender = Socket(SocketType.push);
    sender.connect("tcp://localhost:5558");

    // Process tasks forever
    while (true) {
        auto str = sRecv(receiver);
        write(str, '.'); // Show progress
        stdout.flush();
        Thread.sleep(to!int(str).msecs); // Do the work
        sender.send(""); // Send results to sink
    }
}
