i32 main() {
    u32 bits = 0x3f800000;
    unsafe {
        f32 value = reinterpret(f32, bits);
        if value == 1.0 { return 0; }
    }
    return 1;
}
