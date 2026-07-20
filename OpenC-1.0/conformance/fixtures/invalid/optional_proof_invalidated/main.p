i32 read(optional i32 value) {
    if value.present {
        value = none;
        return value.value;
    }
    return 0;
}
