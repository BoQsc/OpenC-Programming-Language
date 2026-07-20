import system.memory;
i32 main() {
    ptr byte data = memory.alloc(1);
    scope memory.free(data);
    unsafe {
        ptr byte bad = data + 2;
        *bad = 1;
    }
    return 0;
}
