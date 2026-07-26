when true {
    i32 selected(i32 value);
}

i32 main() {
    i32 value = 1;
    when true {
        value = selected(value);
    }
    return value;
}
