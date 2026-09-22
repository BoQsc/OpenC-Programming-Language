import system.file;
import system.io;
import system.memory;

unsafe i32 main() {
    usize iteration = 0;
    while iteration < 64 {
        ptr byte block = memory.alloc(4096);
        usize offset = 0;
        while offset < 4096 {
            memory.store_usize(block + offset, iteration + offset);
            offset = offset + 8;
        }
        status written = file.write_bytes("sh27-runtime-payload.bin", block, 4096);
        if !written.ok { memory.free(block); return 2; }
        ptr byte observed;
        usize length;
        status read = file.read_bytes_raw(
            "sh27-runtime-payload.bin", out observed, out length
        );
        if !read.ok { memory.free(block); return 3; }
        if length != 4096 {
            memory.free(observed); memory.free(block); return 4;
        }
        offset = 0;
        while offset < 4096 {
            if memory.load_usize(observed + offset) != iteration + offset {
                memory.free(observed); memory.free(block); return 5;
            }
            offset = offset + 8;
        }
        memory.free(observed);
        memory.free(block);
        iteration = iteration + 1;
    }
    io.println("SH27_RUNTIME_OK");
    return 0;
}
