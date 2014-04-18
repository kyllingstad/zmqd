/**
Helper module for example applications.

This module is a partial port of the C header file
$(LINK2 https://github.com/imatix/zguide/blob/master/examples/C/zhelpers.h,zhelpers.h).
*/
module zhelpers;

import zmqd;



string sRecv(Socket socket)
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


void sSetId(Socket socket)
{
    import std.random: uniform;
    import std.string: sformat;
    char[9] identity;
    sformat(identity[], "%04X-%04X", uniform(0, 0x10000), uniform(0, 0x10000));
    socket.identity = identity[];
}
