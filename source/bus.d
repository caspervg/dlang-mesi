module bus;

import std.stdio;
import cache, memory;

class Bus {

    ulong busWrites, busReads, busUpgrades, busUpdates;
    int numCores;
    Cache[16] caches;
    Memory memory;

    this(int numCores) {
        this.numCores = numCores;
    }

    void setMemory(Memory ram) {
        this.memory = ram;
    }

    void addCache(Cache cache, int index) {
        this.caches[index] = cache;
    }

    CacheBlock busWrite(ulong address, ubyte cacheId) {
        busWrites++;

        // Try the caches
        foreach (int i, Cache c; caches) {
            if (c is null) continue;

            auto block = c.busWrite(address);
            if (block !is null) {
                return block;
            }
        }

        // Return from the backing store
        auto block = memory.readBlock(address);
        return block;
    }

    CacheBlock busRead(ulong address, ubyte cacheId) {
        busReads++;

        // Try the caches
        foreach (int i, Cache c; caches) {
            if (c is null) continue;

            auto block = c.busRead(address);
            if (block !is null) {
                return block;
            }
        }

        // Return from backing store
        auto block = memory.readBlock(address);
        return block;
    }

    void busUpgrade(ulong address, ubyte cacheId) {
        busUpgrades++;

        // Ask the caches
        foreach (int i, Cache c; caches) {
            if (c is null) continue;

            c.busUpgrade(address);
        }
    }

    void writeBack(CacheBlock cb) {
        memory.writeBlock(cb);
    }
}