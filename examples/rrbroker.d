// Simple request-reply broker
import deimos.zmq.zmq, zmqd;
import zhelpers;

void main()
{
    // Prepare our context and sockets
    auto frontend = Socket(SocketType.router);
    auto backend = Socket(SocketType.dealer);
    frontend.bind("tcp://*:5559");
    backend.bind("tcp://*:5560");

    // Initialize poll set
    auto items = [
        zmq_pollitem_t(frontend.handle, 0, ZMQ_POLLIN, 0),
        zmq_pollitem_t(backend.handle, 0, ZMQ_POLLIN, 0),
    ];
    // Switch messages between sockets
    while (true) {
        import core.time: Duration;
        Message message;
        poll(items);
        if (items[0].revents & ZMQ_POLLIN) {
            do {
                // Process all parts of the message
                message.reinit();
                frontend.receive(message);
                backend.send(message, message.more);
            } while (message.more);
        }
        if (items[1].revents & ZMQ_POLLIN) {
            do {
                // Process all parts of the message
                message.reinit();
                backend.receive(message);
                frontend.send(message, message.more);
            } while (message.more);
        }
    }
}
