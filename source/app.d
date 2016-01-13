import std.stdio;
import std.math;
import std.conv;
import std.array;
import std.format;
import std.c.process;
import memory, bus, cache, mesi;

Cache[int] caches;
Memory dram;
Bus interconnect;
int numCores;

ulong lineNumber = 0;
ulong errors = 0;

void main(string[] args)
{
    if (args.length != 3) {
        writeln("Usage:");
        writeln("./dlang-mesi <#cores> <input file>");
        exit(1);
    }

    numCores = to!int(args[1]);
    const string inputFile = args[2];
    const auto size = 32;

    initSimulation(numCores, size);

    writeln("Starting simulation..");

    auto file = File(inputFile);
    auto lines = file.byLine();

    foreach(line; lines) {
        lineNumber++;

        auto sections = line.split("\t");
        int threadId = to!int(sections[0]);
        ulong address = to!ulong(sections[2], 16);  // hexadecimal to decimal
        ulong data = to!ulong(sections[3]);
        int dataSize = to!int(sections[4]);

        if (sections[1] == "R") {
            simulateRead(threadId, address, data, dataSize);
        } else {
            simulateWrite(threadId, address, data, dataSize);
        }

        if (lineNumber % 1_000_000 == 0) {
            writefln("Simulated %s million instructions ", lineNumber / 1_000_000);
            stdout.flush();
        }
    }

    analyze();
}

void initSimulation(int numCores, int size) {
    dram = new Memory;
    interconnect = new Bus(numCores);
    interconnect.setMemory(dram);

    int height = to!int(log2(size * 1024 / CacheBlock.size));
    for (int i = 0; i < numCores; i++) {
        caches[i] = new MesiCache(to!ubyte(i), height, interconnect);
        interconnect.addCache(caches[i], i);
    }
}

void simulateWrite(int threadId, ulong address, ulong data, int size) {
    caches[threadId % numCores].write(address, data, to!ubyte(size));
}

void simulateRead(int threadId, ulong address, ulong data, int size) {
    ulong dataFromMem = caches[threadId % numCores].read(address, to!ubyte(size));
    if (dataFromMem != data) {
        errors++;
        if (errors <= 100) {
            writefln("%s: got data: '%s' but expected to get '%s' for addr: %s (%s)",
                lineNumber, dataFromMem, data, address, size);
        }

        if (errors == 100) {
            writefln("100 errors printed, switching to silent mode");
        }

        stdout.flush();
    }
}

void analyze() {
    writeln();
    writefln("%s errors reported out of %s instructions (%s%%)", errors, lineNumber, (errors/lineNumber));
    writefln("---");
    writefln("Cache statistics:");
    for (int i = 0; i < caches.length; i++) {
        writefln("\tCache %s:", i);
        caches[i].analyze();
    }
    writefln("---");
    writefln("Bus statistics:");
    interconnect.analyze();
    writefln("---");
    writefln("DRAM statistics:");
    dram.analyze();
}