module cache;

import std.stdio;

interface Cache {
    bool contains(ulong address);

    ulong read(ulong address, ubyte size);
    void write(ulong address, ulong data, ubyte size);
    void evict(ulong index);

    CacheBlock busRead(ulong address);
    CacheBlock busWrite(ulong address);
    void busUpgrade(ulong address);
    void busUpdate(ulong address, CacheBlock cacheBlock);
}

enum Location {
    CACHE,
    DRAM
}

enum State {
    INVALID,
    SHARED,
    EXCLUSIVE,
    MODIFIED
}

interface CacheBlock {
    const static ubyte size = 64;

    void setTag(ulong address);

    ulong getTag();
    ulong getTag(ulong address);

    bool isValid(ulong address);

    State getState();
    void setState(State state);

    Location getLocation();

    ulong getData(ulong address, ubyte size);
    void setData(ulong address, ulong data, ubyte size);

    // Copy
    void setCacheBlock(CacheBlock cb);
}



class DefaultCacheBlock : CacheBlock {

    State state;
    Location location;
    ulong tag;
    ulong[CacheBlock.size / 8] data;

    this() {
        this(Location.CACHE);
    }

    this(Location loc) {
        tag = 0;
        state = State.INVALID;
        location = loc;
        for (int i = 0; i < CacheBlock.size; i++) {
            data[i] = -1;
        }
    }

    void setCacheBlock(CacheBlock cb) {
        auto address = cb.getTag();
        setTag(address);

        for (int i = 0; i < CacheBlock.size / 8; i++) {
            setData(address, cb.getData(address, 8), 8);
            address += 8;
        }
    }

    ulong getTag() {
        return tag;
    }

    ulong getTag(ulong address) {
        return address - (address % CacheBlock.size);
    }

    void setTag(ulong address) {
        this.tag = getTag(address);
    }

    bool isValid(ulong address) {
        return ((getTag(address) == getTag()) && state != State.INVALID);
    }

    void setState(State state) {
        this.state = state;
    }

    State getState() {
        return state;
    }

    Location getLocation() {
        return location;
    }

    ulong getData(ulong address, ubyte size) {
        const int offset = address % 8;
        const ulong offsetArray = (address % CacheBlock.size - offset) >> 3;
        ulong dataOut = data[offsetArray];
        if (size < 8) {
            ulong mask = (cast(ulong)1 << (size * 8)) - 1;
            mask <<= offset * 8;

            dataOut &= mask;
            dataOut >>= offset * 8;
        }

        return dataOut;
    }

    void setData(ulong address, ulong dataIn, ubyte size) {
        setTag(address);

        const int offset = address % 8;
        const ulong offsetArray = (address % CacheBlock.size - offset) >> 3;
        if (size == 8) {
            data[offsetArray] = dataIn;
        } else {
            ulong mask = (cast(ulong)1 << (size * 8)) - 1;
            mask <<= offset * 8;
            mask ^= cast(ulong)-1;

            dataIn <<= offset * 8;

            data[offsetArray] &= mask;
            data[offsetArray] |= dataIn;
        }
    }
}