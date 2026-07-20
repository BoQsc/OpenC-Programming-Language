module openc.runtime.types;

import core.stdc.stdint;
import core.lifetime : emplace;

alias i8 = byte;
alias i16 = short;
alias i32 = int;
alias i64 = long;
alias u8 = ubyte;
alias u16 = ushort;
alias u32 = uint;
alias u64 = ulong;
alias isize = ptrdiff_t;
alias usize = size_t;
alias OpenCByte = ubyte;
alias OpenCText = immutable(char)[];

struct Status {
    i32 code;
    OpenCText message;

    this(i32 code, OpenCText message = "") nothrow @safe {
        this.code = code;
        this.message = message;
    }

    @property bool ok() const nothrow @safe {
        return code == 0;
    }

    static Status success() nothrow @safe {
        return Status(0, "");
    }

    static Status failure(i32 code, OpenCText message = "") nothrow @safe {
        assert(code != 0);
        return Status(code, message);
    }
}

struct OpenCOptional(T) {
private:
    bool present;
    T valueStorage;

public:
    static OpenCOptional none() nothrow @safe {
        OpenCOptional result;
        result.present = false;
        return result;
    }

    static OpenCOptional some(T value) {
        OpenCOptional result;
        result.present = true;
        result.valueStorage = value;
        return result;
    }

    @property bool hasValue() const nothrow @safe {
        return present;
    }

    ref T value() return {
        if (!present) opencCheckedFailure("optional value is absent");
        return valueStorage;
    }

    ref const(T) value() const return {
        if (!present) opencCheckedFailure("optional value is absent");
        return valueStorage;
    }

    void clear() {
        if (present) {
            destroy(valueStorage);
            present = false;
        }
    }
}

struct OpenCStorage(T) {
private:
    align(T.sizeof) ubyte[T.sizeof] bytes;
    bool active;

public:
    @property bool initialized() const nothrow @safe {
        return active;
    }

    ref T construct(Args...)(auto ref Args args) {
        if (active) opencCheckedFailure("storage already contains a live object");
        auto pointer = cast(T*) bytes.ptr;
        emplace(pointer, args);
        active = true;
        return *pointer;
    }

    ref T get() return {
        if (!active) opencCheckedFailure("storage does not contain a live object");
        return *cast(T*) bytes.ptr;
    }

    ref const(T) get() const return {
        if (!active) opencCheckedFailure("storage does not contain a live object");
        return *cast(const(T)*) bytes.ptr;
    }

    void destroyValue() {
        if (!active) opencCheckedFailure("storage object is not initialized");
        destroy(*cast(T*) bytes.ptr);
        active = false;
    }
}

struct OpenCSlice(T) {
    T* data;
    usize length;

    ref T opIndex(usize index) return {
        if (index >= length) opencCheckedFailure("slice index out of bounds");
        return data[index];
    }

    OpenCSlice opSlice(usize lower, usize upper) return {
        if (lower > upper || upper > length) opencCheckedFailure("slice range out of bounds");
        return OpenCSlice(data + lower, upper - lower);
    }
}

extern(C) noreturn opencCheckedFailure(const(char)[] message);
