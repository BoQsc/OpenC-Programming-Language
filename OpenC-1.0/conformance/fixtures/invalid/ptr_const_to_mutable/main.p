i32 main() {
    i32 value = 1;
    unsafe {
        ptr i32 address = &value;
        ptr const i32 view = address;
        ptr i32 writable = view;
        *writable = 2;
    }
    return value;
}
