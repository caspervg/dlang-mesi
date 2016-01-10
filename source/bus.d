module bus;

import std.stdio;
import cache, memory;

class Bus {

    ulong busWrites, busReads, busUpgrades, busUpdates;
    Cache[] caches;
    Memory memory;

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
            auto block = c.busRead(address);
            if (block !is null) {
                return block;
            }
        }

        // Return from backing store
        auto block = memory.readBlock(address);
        return block;
    }
}