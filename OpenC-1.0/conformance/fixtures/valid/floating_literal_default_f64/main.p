f64 identity(f64 value) { return value; }

i32 main() {
    f64 value = identity(1.25);
    if value == 1.25 { return 0; }
    return 1;
}
