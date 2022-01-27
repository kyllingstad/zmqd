import zmqd;

void main()
{
    auto frontend = Socket(SocketType.xsub);
    frontend.bind("tcp://192.168.55.210:5556");

    auto backend = Socket(SocketType.xpub);
    backend.bind("tcp://10.1.1.0:8100");

    proxy(frontend, backend);
}