module mesi;

import std.stdio;
import cache, bus;

class MesiCache : Cache {

    ulong hit, miss, access;

    ubyte cacheId;
    Bus bus;

    CacheBlock[] cache;
    ulong addressMask;

    this(ubyte cacheId, int height, Bus bus) {
        const ulong maxIndex = cast(ulong)1 << height;
        this.cacheId = cacheId;
        this.bus = bus;

        cache = new CacheBlock[maxIndex];
        addressMask = (cast(ulong)1 << height) - 1;
    }

    ulong addressToIndex(ulong address) {
        return (address / CacheBlock.size) & addressMask;
    }

    bool contains(ulong address) {
        const auto index = addressToIndex(address);
        return cache[index].isValid(address);
    }

    void evict(ulong index) {
        const auto state = cache[index].getState();

        if (state == State.MODIFIED) {
            bus.writeBack(cache[index]);
            cache[index].setState(State.INVALID);
        } else if (state == State.EXCLUSIVE || state == State.SHARED) {
            cache[index].setState(State.INVALID);
        }
    }

    void busUpgrade(ulong address) {
        if (this.contains(address)) {
            const auto index = addressToIndex(address);
            auto cb = cache[index];
            const auto state = cache[index].getState();

            if (state == State.SHARED) {
                cb.setState(State.INVALID);
            }

            if (state == State.EXCLUSIVE) {
                // Tried to upgrade an exclusive section, impossible
                assert(false);
            }

            if (state == State.MODIFIED) {
                // Tried to upgrade a modified section, impossible
                assert(false);
            }
        }
    }
}