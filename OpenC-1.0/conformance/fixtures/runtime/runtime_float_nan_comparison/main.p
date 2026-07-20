bool equal(f64 value) { return value == value; }
i32 main() {
    f64 nan = 0.0 / 0.0;
    if equal(nan) { return 1; }
    return 0;
}
