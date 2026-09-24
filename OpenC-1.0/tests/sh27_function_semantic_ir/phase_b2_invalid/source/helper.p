i64 work(i64 value) {
    if value < 0 {
        value = value + missing;
    }
    return value;
}
