enum u8 Choice { first = 1, second = 2 }

i32 main() {
    u64 signed_max = 9223372036854775807;
    if signed_max != 0x7fff_ffff_ffff_ffff { return 1; }
    u64 unsigned_max = 18446744073709551615;
    if unsigned_max != 0xffff_ffff_ffff_ffff { return 2; }
    u32 decimal = 12_345;
    if decimal != 12345 { return 3; }
    u32 binary = 0b1010_0101;
    if binary != 165 { return 4; }
    i64 negative = -9223372036854775807;
    if negative != 0 - 9223372036854775807 { return 5; }
    Choice selected = Choice.second;
    if selected != Choice.second { return 6; }
    return 0;
}
