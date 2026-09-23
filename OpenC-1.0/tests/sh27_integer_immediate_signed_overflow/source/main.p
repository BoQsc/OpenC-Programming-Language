i32 main() {
    i64 limit = 9223372036854775807;
    i64 overflow = limit + 1;
    if overflow == 0 { return 1; }
    return 0;
}
