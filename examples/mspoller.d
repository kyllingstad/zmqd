// Reading from multiple sockets
// This version uses poll()

void main()
{
    // Connect to task ventilator
    import zmqd;
    auto receiver = Socket(SocketType.pull);
    receiver.connect("tcp://localhost:5557");

    // Connect to weather server
    auto subscriber = Socket(SocketType.sub);
    subscriber.connect("tcp://localhost:5556");
    subscriber.subscribe("10001");

    // Process messages from both sockets
    while (true) {
        import deimos.zmq.zmq;
        auto items = [
            zmq_pollitem_t(receiver.handle, 0, ZMQ_POLLIN, 0 ),
            zmq_pollitem_t(subscriber.handle, 0, ZMQ_POLLIN, 0 )
        ];
        import core.time;
        poll(items);
        ubyte[256] msg;
        if (items[0].revents & ZMQ_POLLIN) {
            try {
                receiver.receive(msg[]);
                // Process task
            } catch (Exception) { }
        }
        if (items [1].revents & ZMQ_POLLIN) {
            try {
                subscriber.receive(msg[]);
                // Process weather update
            } catch (Exception) { }
        }
    }
}
