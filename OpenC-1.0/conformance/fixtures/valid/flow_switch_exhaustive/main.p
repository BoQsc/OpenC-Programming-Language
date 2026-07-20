enum Choice { a, b }
i32 choose(Choice choice) {
    i32 value;
    switch choice {
        case Choice.a { value = 1; }
        case Choice.b { value = 2; }
    }
    return value;
}
i32 main() { return choose(Choice.a); }
