// Weather update client
// Connects SUB socket to tcp://localhost:5556
// Collects weather updates and finds avg temp in zipcode
import std.format, std.stdio;
import zmqd;
import zhelpers;

void main (string[] args)
{
    // Socket to talk to server
    writeln("Collecting updates from weather server…");
    auto subscriber = Socket(SocketType.sub);
    subscriber.connect("tcp://localhost:5556");

    // Subscribe to zipcode, default is NYC, 10001
    immutable filter = args.length > 1 ? args[1] : "10001";
    subscriber.subscribe(filter);

    // Process 100 updates
    int updateNbr;
    long totalTemp;
    for (updateNbr = 0; updateNbr < 100; ++updateNbr) {
        auto str = sRecv(subscriber);

        int zipcode, temperature, relhumidity;
        formattedRead(str, "%d %d %d", &zipcode, &temperature, &relhumidity);
        totalTemp += temperature;
    }
    writefln("Average temperature for zipcode '%s' was %dF",
             filter, cast(int)(totalTemp / updateNbr));
}
