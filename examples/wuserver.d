module wuserver;

// Weather update server
// Binds PUB socket to tcp://*:5556
// Publishes random weather updates
import std.random, std.string;
import zmqd;

void main()
{
    // Prepare our publisher
    auto publisher = Socket(SocketType.pub);
    publisher.bind ("tcp://*:5556");
    publisher.bind ("ipc://weather.ipc");

    while (true) {
        // Get values that will fool the boss
        auto zipcode = uniform(0, 100_000);
        auto temperature = uniform(-80, 135);
        auto relhumidity = uniform(10, 60);

        // Send message to all subscribers
        publisher.send(format("%05d %d %d", zipcode, temperature, relhumidity));
    }
}