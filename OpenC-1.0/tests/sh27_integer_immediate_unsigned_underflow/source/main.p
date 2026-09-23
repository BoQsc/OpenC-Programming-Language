i32 main() {
    u64 zero = 0;
    u64 underflow = zero - 1;
    if underflow == 0 { return 1; }
    return 0;
}
