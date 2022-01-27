
import core.sys.posix.signal;
import core.sys.posix.unistd;
import core.sys.linux.sys.signalfd;
import std.stdio;
import zmqd;

void main()
{
    sigset_t set;
    sigemptyset(&set);
    sigaddset(&set, SIGINT);
    sigaddset(&set, SIGTERM);


    sigprocmask(SIG_BLOCK, &set, null);
    int fd = signalfd(-1, &set, SFD_NONBLOCK);

    auto socket = Socket(SocketType.rep);
    socket.bind("tcp://*:5555");

    auto items = [
        PollItem(fd, PollFlags.pollIn),
        PollItem(socket, PollFlags.pollIn)
    ];

    while (true) 
    {
        try {
            const count = poll(items);
            if (count == 0)
                continue;
            // Signal pipe FD
            if (items[0].returnedEvents & PollFlags.pollIn) 
            {
                signalfd_siginfo info;
                read(fd, &info, signalfd_siginfo.sizeof);
                writeln("W: interrupt received, killing server …");
                break;
            }

            // Read socket
            if (items[1].returnedEvents & PollFlags.pollIn) 
            {
                ubyte[255] buffer;
                // Use non-blocking so we can continue to check self-pipe via zmq_poll
                auto result = socket.tryReceive(buffer);

                // on EAGAIN and EINTR the result is false, all other errors throw
                if (!result[1]) {
                    continue;
                }
                writeln("W: recv");

                // Now send message back.
                // ...
            }
        } 
    }
    writeln("W: fin");
}