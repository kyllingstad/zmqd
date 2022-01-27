module mspoller;

import zmqd;

// Reading from multiple sockets
// This version uses poll()

void main()
{
    // Connect to task ventilator
    auto receiver = Socket(SocketType.pull);
    receiver.connect("tcp://localhost:5557");

    // Connect to weather server
    auto subscriber = Socket(SocketType.sub);
    subscriber.connect("tcp://localhost:5556");
    subscriber.subscribe("10001");

    // Process messages from both sockets
    while (true) {
        auto items = [
            PollItem(receiver, PollFlags.pollIn),
            PollItem(subscriber, PollFlags.pollIn),
        ];
        import core.time;
        poll(items);
        ubyte[256] msg;
        if (items[0].returnedEvents & PollFlags.pollIn) {
            try {
                receiver.receive(msg[]);
                // Process task
            } catch (Exception) { }
        }
        if (items[1].returnedEvents & PollFlags.pollIn) {
            try {
                subscriber.receive(msg[]);
                // Process weather update
            } catch (Exception) { }
        }
    }
}