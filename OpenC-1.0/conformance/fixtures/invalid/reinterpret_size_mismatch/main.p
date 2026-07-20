i32 main() {
    u32 value = 1;
    unsafe { u64 bits = reinterpret(u64, value); return cast(i32, bits); }
}
