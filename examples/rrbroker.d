// Simple request-reply broker
import zmqd;
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
        PollItem(frontend, PollFlags.pollIn),
        PollItem(backend, PollFlags.pollIn),
    ];
    // Switch messages between sockets
    while (true) {
        import core.time: Duration;
        Frame message;
        poll(items);
        if (items[0].returnedEvents & PollFlags.pollIn) {
            do {
                // Process all parts of the message
                message.rebuild();
                frontend.receive(message);
                backend.send(message, message.more);
            } while (message.more);
        }
        if (items[1].returnedEvents & PollFlags.pollIn) {
            do {
                // Process all parts of the message
                message.rebuild();
                backend.receive(message);
                frontend.send(message, message.more);
            } while (message.more);
        }
    }
}