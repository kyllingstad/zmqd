// Helper module for example applications.
module zhelpers;

import zmqd;

string sRecv(ref Socket socket)
{
    ubyte[256] buffer;
    immutable size = socket.receive(buffer);
    import std.algorithm: min;
    return buffer[0 .. min(size,256)].idup.asString();
}

void sDump(Socket socket)
{
    import std.stdio;
    writeln("----------------------------------------");
    do {
        // Process all parts of the message
        auto message = Message();
        immutable size = socket.receive(message);

        // Dump the message as text or binary
        const data = message.data;
        import std.algorithm: any;
        immutable isText = !data.any!(c => (c < 32 || c > 127))();

        writef("[%03d] ", size);
        foreach (ubyte c; data) {
            if (isText) write(cast(char) c);
            else writef("%02X", c);
        }
        writeln();
    } while (socket.more);
}
