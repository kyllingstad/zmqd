// Demonstrate request-reply identities
import zmqd, zhelpers;

void main()
{
    auto sink = Socket(SocketType.router);
    sink.bind("inproc://example");

    // First allow 0MQ to set the identity
    auto anonymous = Socket(SocketType.req);
    anonymous.connect ("inproc://example");
    anonymous.send("ROUTER uses a generated UUID");
    sDump(sink);

    // Then set the identity ourselves
    auto identified = Socket(SocketType.req);
    identified.identity = "PEER2";
    identified.connect("inproc://example");
    identified.send("ROUTER socket uses REQ's socket identity");
    sDump (sink);
}
