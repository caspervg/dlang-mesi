module memory;

import std.stdio;
import cache;

class Memory {

    ulong access, reads, writes, dataRead, dataWritten;
    ulong[ulong] memory;

    CacheBlock readBlock(ulong address) {
        access++;
        reads++;
        dataRead += CacheBlock.size;

        auto cb = new DefaultCacheBlock(Location.DRAM);
        ulong tag = cb.getTag(address);
        for (int i = 0; i < (CacheBlock.size / 8); i++) {
            cb.setData(tag, get(tag), 8);
            tag += 8;
        }

        return cb;
    }

    void writeBlock(CacheBlock cb) {
        access++;
        writes++;
        dataWritten += CacheBlock.size;

        ulong address = cb.getTag();
        for (int i = 0; i < (CacheBlock.size / 8); i++) {
            set(address, cb.getData(address, 8));
            address += 8;
        }
    }

    void analyze() {
        writefln("\tAccesses: %s", access);
        writefln("\tReads: %s", reads);
        writefln("\tWritten: %s", writes);
        writeln();
        writefln("\tData read: %s kByte", (dataRead >> 10));
        writefln("\tData written: %s kByte", (dataWritten >> 10));
    }

    private ulong get(ulong address) {
        ulong dramIndex = getIndex(address);

        const ulong* elem = (dramIndex in memory);
        if (elem is null) {
            memory[dramIndex] = -1;
        }
        return memory[dramIndex];
    }

    private void set(ulong address, ulong data) {
        ulong dramIndex = getIndex(address);
        memory[dramIndex] = data;
    }

    private ulong getIndex(ulong address) {
        ulong mask = (cast(ulong)-1) << 3;
        return address & mask;
    }
}