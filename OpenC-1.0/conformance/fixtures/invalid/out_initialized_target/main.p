status make(out i32 value);
i32 main() {
    i32 value = 1;
    status result = make(out value);
    return result.code;
}
