module memory;

import std.stdio;
import cache;

class Memory {

    ulong access, reads, writes, dataRead, dataWritten;
    ulong[ulong] memory;

    //ulong read(ulong address, ubyte size) {
    //}

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

    //void write(ulong address, ulong data, ubyte size) {
    //}

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

    private ulong get(ulong address) {
        ulong dramIndex = getIndex(address);
        if (!dramIndex in memory) {
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