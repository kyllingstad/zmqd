// Report 0MQ version

void main()
{
    import std.stdio, zmqd;
    const ver = zmqVersion();
    writefln("Current 0MQ version is %d.%d.%d", ver.major, ver.minor, ver.patch);
}
