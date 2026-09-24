i64 work(i64 value) {
    i64 cursor = 0;
    while cursor < 2 {
        value = value + cursor + 3;
        cursor = cursor + 1;
    }
    if value % 2 == 0 {
        value = value + 1;
    } else {
        value = value - 1;
    }
    return value;
}
