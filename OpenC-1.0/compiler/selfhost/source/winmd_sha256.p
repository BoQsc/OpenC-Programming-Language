import system.memory;

u32 winmd_sha_shl(u32 value, usize amount) {
    return cast_unchecked(
        u32,
        (cast(u64, value) << amount) & cast(u64, 4294967295)
    );
}

u32 winmd_sha_rotr(u32 value, usize amount) {
    return (value >> amount) | winmd_sha_shl(value, 32 - amount);
}

u32 winmd_sha_add2(u32 left, u32 right) {
    return cast_unchecked(
        u32, (cast(u64, left) + cast(u64, right)) & cast(u64, 4294967295)
    );
}

u32 winmd_sha_add4(u32 a, u32 b, u32 c, u32 d) {
    return cast_unchecked(
        u32,
        (cast(u64, a) + cast(u64, b) + cast(u64, c) + cast(u64, d)) &
            cast(u64, 4294967295)
    );
}

u32 winmd_sha_add5(u32 a, u32 b, u32 c, u32 d, u32 e) {
    return winmd_sha_add2(winmd_sha_add4(a, b, c, d), e);
}

u32 winmd_sha_k(usize index) {
    if index == 0 { return 1116352408; }
    if index == 1 { return 1899447441; }
    if index == 2 { return 3049323471; }
    if index == 3 { return 3921009573; }
    if index == 4 { return 961987163; }
    if index == 5 { return 1508970993; }
    if index == 6 { return 2453635748; }
    if index == 7 { return 2870763221; }
    if index == 8 { return 3624381080; }
    if index == 9 { return 310598401; }
    if index == 10 { return 607225278; }
    if index == 11 { return 1426881987; }
    if index == 12 { return 1925078388; }
    if index == 13 { return 2162078206; }
    if index == 14 { return 2614888103; }
    if index == 15 { return 3248222580; }
    if index == 16 { return 3835390401; }
    if index == 17 { return 4022224774; }
    if index == 18 { return 264347078; }
    if index == 19 { return 604807628; }
    if index == 20 { return 770255983; }
    if index == 21 { return 1249150122; }
    if index == 22 { return 1555081692; }
    if index == 23 { return 1996064986; }
    if index == 24 { return 2554220882; }
    if index == 25 { return 2821834349; }
    if index == 26 { return 2952996808; }
    if index == 27 { return 3210313671; }
    if index == 28 { return 3336571891; }
    if index == 29 { return 3584528711; }
    if index == 30 { return 113926993; }
    if index == 31 { return 338241895; }
    if index == 32 { return 666307205; }
    if index == 33 { return 773529912; }
    if index == 34 { return 1294757372; }
    if index == 35 { return 1396182291; }
    if index == 36 { return 1695183700; }
    if index == 37 { return 1986661051; }
    if index == 38 { return 2177026350; }
    if index == 39 { return 2456956037; }
    if index == 40 { return 2730485921; }
    if index == 41 { return 2820302411; }
    if index == 42 { return 3259730800; }
    if index == 43 { return 3345764771; }
    if index == 44 { return 3516065817; }
    if index == 45 { return 3600352804; }
    if index == 46 { return 4094571909; }
    if index == 47 { return 275423344; }
    if index == 48 { return 430227734; }
    if index == 49 { return 506948616; }
    if index == 50 { return 659060556; }
    if index == 51 { return 883997877; }
    if index == 52 { return 958139571; }
    if index == 53 { return 1322822218; }
    if index == 54 { return 1537002063; }
    if index == 55 { return 1747873779; }
    if index == 56 { return 1955562222; }
    if index == 57 { return 2024104815; }
    if index == 58 { return 2227730452; }
    if index == 59 { return 2361852424; }
    if index == 60 { return 2428436474; }
    if index == 61 { return 2756734187; }
    if index == 62 { return 3204031479; }
    return 3329325298;
}

unsafe u32 winmd_sha_block_word(
    ptr byte block,
    usize index
) {
    usize at = index * 4;
    return winmd_sha_shl(cast(u32, cast_unchecked(u8, *(block + at))), 24) |
        winmd_sha_shl(cast(u32, cast_unchecked(u8, *(block + at + 1))), 16) |
        winmd_sha_shl(cast(u32, cast_unchecked(u8, *(block + at + 2))), 8) |
        cast(u32, cast_unchecked(u8, *(block + at + 3)));
}

unsafe u32 winmd_sha_schedule_word(
    ptr byte schedule,
    usize index
) {
    return cast_unchecked(u32, read_usize(
        schedule, index * size_of(usize)
    ));
}

unsafe void winmd_sha_schedule_set(
    ptr byte schedule,
    usize index,
    u32 value
) {
    write_usize(schedule, index * size_of(usize), cast(usize, value));
}

unsafe void winmd_sha_process(
    ref WinmdSha256 state,
    ptr byte block,
    ptr byte schedule
) {
    usize index = 0;
    while index < 16 {
        winmd_sha_schedule_set(
            schedule, index, winmd_sha_block_word(block, index)
        );
        index = index + 1;
    }
    while index < 64 {
        u32 before_two = winmd_sha_schedule_word(schedule, index - 2);
        u32 before_fifteen = winmd_sha_schedule_word(schedule, index - 15);
        u32 s1 = winmd_sha_rotr(before_two, 17) ^
            winmd_sha_rotr(before_two, 19) ^ (before_two >> 10);
        u32 s0 = winmd_sha_rotr(before_fifteen, 7) ^
            winmd_sha_rotr(before_fifteen, 18) ^ (before_fifteen >> 3);
        winmd_sha_schedule_set(
            schedule, index,
            winmd_sha_add4(
                winmd_sha_schedule_word(schedule, index - 16),
                s0,
                winmd_sha_schedule_word(schedule, index - 7),
                s1
            )
        );
        index = index + 1;
    }
    u32 a = state.a; u32 b = state.b; u32 c = state.c; u32 d = state.d;
    u32 e = state.e; u32 f = state.f; u32 g = state.g; u32 h = state.h;
    index = 0;
    while index < 64 {
        u32 big_one = winmd_sha_rotr(e, 6) ^
            winmd_sha_rotr(e, 11) ^ winmd_sha_rotr(e, 25);
        u32 choose = (e & f) ^ ((~e) & g);
        u32 temporary_one = winmd_sha_add5(
            h, big_one, choose, winmd_sha_k(index),
            winmd_sha_schedule_word(schedule, index)
        );
        u32 big_zero = winmd_sha_rotr(a, 2) ^
            winmd_sha_rotr(a, 13) ^ winmd_sha_rotr(a, 22);
        u32 majority = (a & b) ^ (a & c) ^ (b & c);
        u32 temporary_two = winmd_sha_add2(big_zero, majority);
        h = g; g = f; f = e; e = winmd_sha_add2(d, temporary_one);
        d = c; c = b; b = a; a = winmd_sha_add2(temporary_one, temporary_two);
        index = index + 1;
    }
    state.a = winmd_sha_add2(state.a, a);
    state.b = winmd_sha_add2(state.b, b);
    state.c = winmd_sha_add2(state.c, c);
    state.d = winmd_sha_add2(state.d, d);
    state.e = winmd_sha_add2(state.e, e);
    state.f = winmd_sha_add2(state.f, f);
    state.g = winmd_sha_add2(state.g, g);
    state.h = winmd_sha_add2(state.h, h);
}

unsafe void winmd_sha_put_word(ref DBuffer output, u32 value) {
    usize shift = 28;
    while shift <= 28 {
        usize digit = cast(usize, (value >> shift) & cast(u32, 15));
        if digit < 10 { d_put_byte(output, cast(u8, 48 + digit)); }
        else { d_put_byte(output, cast(u8, 87 + digit)); }
        if shift == 0 { return; }
        shift = shift - 4;
    }
}

unsafe void winmd_sha256_hex(
    ptr byte data,
    usize length,
    ref DBuffer output
) {
    WinmdSha256 state = WinmdSha256{
        a = 1779033703, b = 3144134277, c = 1013904242,
        d = 2773480762, e = 1359893119, f = 2600822924,
        g = 528734635, h = 1541459225
    };
    ptr byte schedule = memory.alloc(64 * size_of(usize));
    usize blocks = length / 64;
    usize block = 0;
    while block < blocks {
        winmd_sha_process(state, data + block * 64, schedule);
        block = block + 1;
    }
    usize tail_length = length - blocks * 64;
    usize final_length = 64;
    if tail_length >= 56 { final_length = 128; }
    ptr byte final_blocks = memory.alloc(final_length);
    usize cursor = 0;
    while cursor < final_length {
        *(final_blocks + cursor) = cast(byte, 0);
        cursor = cursor + 1;
    }
    cursor = 0;
    while cursor < tail_length {
        *(final_blocks + cursor) = *(data + blocks * 64 + cursor);
        cursor = cursor + 1;
    }
    *(final_blocks + tail_length) = cast_unchecked(byte, cast(u8, 128));
    u64 bit_length = cast(u64, length) * cast(u64, 8);
    cursor = 0;
    while cursor < 8 {
        *(final_blocks + final_length - 1 - cursor) = cast_unchecked(
            byte, cast(u8, (bit_length >> (cursor * 8)) & cast(u64, 255))
        );
        cursor = cursor + 1;
    }
    winmd_sha_process(state, final_blocks, schedule);
    if final_length == 128 {
        winmd_sha_process(state, final_blocks + 64, schedule);
    }
    memory.free(final_blocks);
    memory.free(schedule);
    winmd_sha_put_word(output, state.a); winmd_sha_put_word(output, state.b);
    winmd_sha_put_word(output, state.c); winmd_sha_put_word(output, state.d);
    winmd_sha_put_word(output, state.e); winmd_sha_put_word(output, state.f);
    winmd_sha_put_word(output, state.g); winmd_sha_put_word(output, state.h);
}
