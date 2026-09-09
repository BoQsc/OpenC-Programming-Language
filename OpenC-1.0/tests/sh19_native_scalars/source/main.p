i32 add_six(i32 a, i32 b, i32 c, i32 d, i32 e, i32 f) {
    return a + b + c + d + e + f;
}

i32 accumulate(i32 limit) {
    i32 total = 0;
    i32 index = 0;
    while index < limit {
        total = total + index;
        index = index + 1;
    }
    return total;
}

i32 recurse(i32 value) {
    if value == 0 { return 0; }
    return value + recurse(value - 1);
}

i32 fail_divide(i32 divisor) { return 10 / divisor; }

i32 main() {
    if add_six(1, 2, 3, 4, 5, 6) != 21 { return 1; }
    if accumulate(11) != 55 { return 2; }
    if recurse(10) != 55 { return 3; }
    i32 negative = 0 - 7;
    if negative >= 0 { return 4; }
    if negative + 10 != 3 { return 5; }
    if negative * 3 != -21 { return 6; }
    if negative / 3 != -2 { return 7; }
    if negative % 3 != -1 { return 8; }
    if false && fail_divide(0) == 0 { return 9; }
    if !(true || fail_divide(0) == 0) { return 10; }
    u64 wide = cast(u64, 1) << cast(usize, 40);
    if wide >> cast(usize, 40) != cast(u64, 1) { return 11; }
    if cast(i32, cast(u32, 123)) != 123 { return 12; }
    return 0;
}
