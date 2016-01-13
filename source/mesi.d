module mesi;

import std.stdio;
import std.conv;
import cache, bus;

class MesiCache : Cache
{

    ulong hit, miss, access;

    ubyte cacheId;
    Bus bus;

    CacheBlock[] cache;
    ulong addressMask;

    this(ubyte cacheId, int height, Bus bus)
    {
        const ulong maxIndex = cast(ulong) 1 << height;
        this.cacheId = cacheId;
        this.bus = bus;

        cache = new CacheBlock[maxIndex];
        for (int i = 0; i < maxIndex; i++) {
            cache[i] = new DefaultCacheBlock;
        }
        addressMask = (cast(ulong) 1 << height) - 1;
    }

    ulong addressToIndex(ulong address)
    {
        return (address / CacheBlock.size) & addressMask;
    }

    bool contains(ulong address)
    {
        const auto index = addressToIndex(address);
        return cache[index].isValid(address);
    }

    void evict(ulong index)
    {
        const auto state = cache[index].getState();

        if (state == State.MODIFIED)
        {
            bus.writeBack(cache[index]);
            cache[index].setState(State.INVALID);
        }
        else if (state == State.EXCLUSIVE || state == State.SHARED)
        {
            cache[index].setState(State.INVALID);
        }
    }

    void busUpgrade(ulong address)
    {
        if (this.contains(address))
        {
            const auto index = addressToIndex(address);
            auto cb = cache[index];
            const auto state = cache[index].getState();

            if (state == State.SHARED)
            {
                cb.setState(State.INVALID);
            }

            if (state == State.EXCLUSIVE)
            {
                // Tried to upgrade an exclusive section, impossible
                assert(false);
            }

            if (state == State.MODIFIED)
            {
                // Tried to upgrade a modified section, impossible
                assert(false);
            }
        }
    }

    CacheBlock busWrite(ulong address)
    {
        if (this.contains(address))
        {
            const auto index = addressToIndex(address);
            auto cb = cache[index];
            const auto state = cb.getState();

            if (state == State.EXCLUSIVE || state == State.SHARED)
            {
                cb.setState(State.INVALID);
            }
            else if (state == State.MODIFIED)
            {
                bus.writeBack(cb);
                cb.setState(State.INVALID);
            }

            return cb;
        }
        else
        {
            return null;
        }
    }

    CacheBlock busRead(ulong address)
    {
        if (this.contains(address))
        {
            const auto index = addressToIndex(address);
            auto cb = cache[index];
            const auto state = cb.getState();

            if (state == State.EXCLUSIVE)
            {
                cb.setState(State.SHARED);
            }
            else if (state == State.MODIFIED)
            {
                bus.writeBack(cb);
                cb.setState(State.SHARED);
            }

            return cb;
        }
        else
        {
            return null;
        }
    }

    void logAccess(ulong address) {
        access++;
        if (this.contains(address)) {
            hit++;
        } else {
            miss++;
        }
    }

    ulong read(ulong address, ubyte size) {
        logAccess(address);

        const ulong index = addressToIndex(address);
        ulong data;

        if (! this.contains(address)) {
            // Cache miss

            // Local eviction
            evict(index);

            // Bus read
            auto newBlock = bus.busRead(address, cacheId);
            cache[index].setCacheBlock(newBlock);

            // Get actual data
            data = cache[index].getData(address, size);
            if (cache[index].getLocation() == Location.DRAM) {
                cache[index].setState(State.EXCLUSIVE);
            } else {
                cache[index].setState(State.SHARED);
            }
        } else {
            // Cache hit

            data = cache[index].getData(address, size);
        }

        return data;
    }

    void write(ulong address, ulong data, ubyte size) {
        logAccess(address);

        const ulong index = addressToIndex(address);

        if (! this.contains(address)) {
            // Cache miss

            // Local eviction
            evict(index);

            // Bus write
            auto newBlock = bus.busWrite(address, cacheId);
            cache[index].setCacheBlock(newBlock);

            // Execute actual write operation (local write)
            cache[index].setData(address, data, size);

            // Set state
            cache[index].setState(State.MODIFIED);
        } else {
            // Cache hit

            cache[index].setData(address, data, size);
            if (cache[index].getState() == State.SHARED) {
                bus.busUpgrade(address, cacheId);
                cache[index].setState(State.MODIFIED);
            }
            if (cache[index].getState() == State.EXCLUSIVE) {
                cache[index].setState(State.MODIFIED);
            }
        }
    }

    void analyze() {
        writefln("\t\tHits: %s", hit);
        writefln("\t\tMisses: %s", miss);
        writefln("\t\tAccesses: %s", access);
    }
}
