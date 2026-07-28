import system.io;

struct Counter {
    i32 value;
}

i32 read_value(ref const Counter counter) {
    return counter.value;
}

i32 main() {
    storage Counter slot;
    ref Counter counter = construct(slot, Counter{ value = 0 });
    scope destroy(counter);

    io.print("Initial value: ");
    io.println(read_value(counter));

    unsafe {
        ptr i32 p = &counter.value;
        *p = 42;
    }

    io.print("After unsafe write: ");
    io.println(read_value(counter));

    return 0;
}