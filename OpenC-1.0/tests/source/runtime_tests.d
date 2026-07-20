module tests.runtime_tests;

import openc.runtime.types : OpenCOptional, OpenCSlice, OpenCStorage, Status, i32;

unittest {
    assert(Status.success().ok);
    assert(!Status.failure(1, "failure").ok);
}

unittest {
    auto value = OpenCOptional!i32.some(42);
    assert(value.hasValue);
    assert(value.value == 42);
    value.clear();
    assert(!value.hasValue);
}

unittest {
    OpenCStorage!i32 storage;
    assert(!storage.initialized);
    storage.construct(7);
    assert(storage.initialized);
    assert(storage.get() == 7);
    storage.destroyValue();
    assert(!storage.initialized);
}

unittest {
    i32[3] data = [1, 2, 3];
    auto slice = OpenCSlice!i32(data.ptr, data.length);
    assert(slice[1] == 2);
    auto middle = slice[1 .. 3];
    assert(middle.length == 2);
}
