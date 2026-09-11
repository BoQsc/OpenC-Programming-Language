import system.file;
import system.memory;

unsafe i32 main() {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(
        "VERSION", out data, out length
    );
    if !loaded.ok { return 1; }
    if length != 11 {
        memory.free(data);
        return 2;
    }

    u8 first = cast_unchecked(u8, *(data + 0));
    memory.free(data);
    if first != 49 { return 3; }
    return 0;
}
