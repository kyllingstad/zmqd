import std.stdio : writefln;

import zmqd;

void main()
{
    auto info = zmqVersion();
    writefln("Current ØMQ version in %s.%s.%s",
        info.major, info.minor, info.patch);
}
