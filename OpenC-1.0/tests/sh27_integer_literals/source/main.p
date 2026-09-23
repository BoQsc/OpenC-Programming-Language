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
    u64 high_bit_32 = 2147483648;
    if high_bit_32 != 0x8000_0000 { return 7; }
    u64 last_imm32 = 4294967295;
    if last_imm32 != 0xffff_ffff { return 8; }
    u64 first_imm64 = 4294967296;
    if first_imm64 != 0x1_0000_0000 { return 9; }
    u64 across_imm32 = last_imm32 + 1;
    if across_imm32 != first_imm64 { return 10; }
    i64 near_signed_max = 9223372036854775806;
    i64 signed_max_after_add = near_signed_max + 1;
    if signed_max_after_add != 9223372036854775807 { return 11; }
    u8 small = 127;
    u8 small_after_sub = small - 1;
    if small_after_sub != 126 { return 12; }
    return 0;
}
