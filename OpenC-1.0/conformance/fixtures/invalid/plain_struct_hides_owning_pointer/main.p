import system.memory;

struct Holder { ptr byte data; }

i32 main() {
    ptr byte owner = memory.alloc(8);
    Holder holder = Holder{ data = owner };
    return 0;
}
