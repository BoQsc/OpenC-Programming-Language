status make(out i32 value) {
    value = 9;
    return status{ code = 0, message = "" };
}
i32 main() {
    i32 value;
    status original = make(out value);
    status copied = original;
    if !copied.ok { return copied.code; }
    return value;
}
