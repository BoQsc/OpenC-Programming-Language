i32 factorial(i32 value) {
    if value <= 1 {
        return 1;
    }
    return value * factorial(value - 1);
}

i32 main() {
    return factorial(5);
}
