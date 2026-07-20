import system.memory;
i32 main() {
    ptr byte a = memory.alloc(1);
    scope memory.free(a);
    ptr byte b = memory.alloc(1);
    scope memory.free(b);
    unsafe {
        if a < b { return 1; }
    }
    return 0;
}
