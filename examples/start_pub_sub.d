import std;
import core.thread;

void main(string[] args)
{
	string syncsub = args[1];
	string syncpub = args[2];

	Pid[] children;
	writefln("spawning subscribers %s", syncsub);
	foreach (int i; 0 .. 10)
	{
		children ~= spawnShell("./" ~ syncsub);
	}
	writefln("spawning publisher %s", syncpub);
	auto pub = spawnShell("./" ~ syncpub);
    writeln("waiting for publisher to finish");
	wait(pub);
	Thread.sleep(1.seconds);
    foreach (pid; children)
    {
        writefln("killing %s", pid);
        kill(pid);
    }
}
