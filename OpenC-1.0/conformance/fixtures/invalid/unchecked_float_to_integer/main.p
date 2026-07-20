i32 main() {
    f32 value = 1.5;
    unsafe { return cast_unchecked(i32, value); }
}
