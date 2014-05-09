// Task worker - design 2
// Adds pub-sub flow to receive and respond to kill signal
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

    // Socket for control input
    auto controller = Socket(SocketType.sub);
    controller.connect("tcp://localhost:5559");
    controller.subscribe("");

    // Process messages from either socket
    while (true) {
        auto items = [
            PollItem(receiver, PollFlags.pollIn),
            PollItem(controller, PollFlags.pollIn),
            ];
        poll(items);
        if (items[0].returnedEvents & PollFlags.pollIn) {
            auto str = sRecv(receiver);
            write(str, '.');                    // Show progress
            stdout.flush();
            Thread.sleep(to!int(str).msecs);    // Do the work
            sender.send("");                    // Send results to sink
        }
        // Any waiting controller command acts as 'KILL'
        if (items[1].returnedEvents & PollFlags.pollIn) break; // Exit loop
    }
}
