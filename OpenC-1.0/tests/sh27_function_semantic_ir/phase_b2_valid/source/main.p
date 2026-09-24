i64 future();

i32 main() {
    i64 value = 0;
    value = work(value);
    if value != 6 { return 1; }
    return 0;
}
