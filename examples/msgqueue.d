// Simple message queuing broker
// Same as request-reply broker but using QUEUE device
import zmqd;
import zhelpers;

void main()
{
    // Socket facing clients
    auto frontend = Socket(SocketType.router);
    frontend.bind("tcp://*:5559");

    // Socket facing services
    auto backend = Socket(SocketType.dealer);
    backend.bind("tcp://*:5560");

    // Start the proxy
    proxy(frontend, backend);
}
