// Task worker - design 2
// Adds pub-sub flow to receive and respond to kill signal
import core.thread;
import std.conv, std.stdio;
import deimos.zmq.zmq, zmqd, zhelpers;

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
            zmq_pollitem_t(receiver.handle, 0, ZMQ_POLLIN, 0),
            zmq_pollitem_t(controller.handle, 0, ZMQ_POLLIN, 0)
            ];
        poll(items);
        if (items[0].revents & ZMQ_POLLIN) {
            auto str = sRecv(receiver);
            write(str, '.');                    // Show progress
            stdout.flush();
            Thread.sleep(to!int(str).msecs);    // Do the work
            sender.send("");                    // Send results to sink
        }
        // Any waiting controller command acts as 'KILL'
        if (items[1].revents & ZMQ_POLLIN) break; // Exit loop
    }
}
