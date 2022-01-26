module msreader;

// Reading from multiple sockets
// This version uses a simple recv loop
import core.thread, core.time;
import zmqd;

void main()
{
    // Connect to task ventilator
    auto receiver = Socket(SocketType.pull);
    receiver.connect("tcp://localhost:5557");

    // Connect to weather server
    auto subscriber = Socket(SocketType.sub);
    subscriber.connect("tcp://localhost:5556");
    subscriber.subscribe("10001 ");

    // Process messages from both sockets
    // We prioritize traffic from the task ventilator
    while (true) {
        ubyte[256] msg;
        while (true) {
            auto r = receiver.tryReceive(msg[]);
            if (r[1]) {
                // Process task
            } else {
                break;
            }
        }
        while (true) {
            auto r = subscriber.tryReceive(msg[]);
            if (r[1]) {
                // Process weather update
            } else {
                break;
            }
        }
        // No activity, so sleep for 1 msec
        Thread.sleep(1.msecs);
    }
}