i32 main() {
    i8 limit = 127;
    i8 overflow = limit + 1;
    if overflow == 0 { return 1; }
    return 0;
}
