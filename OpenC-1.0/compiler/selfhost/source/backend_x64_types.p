struct Win64AbiType {
    usize kind;
    usize size;
    usize alignment;
    bool trivial;
}

struct Win64AbiLocation {
    usize kind;
    usize register_code;
    usize stack_offset;
    bool indirect;
    bool duplicate_float_to_integer;
}

struct Win64ReturnLocation {
    usize kind;
    usize register_code;
    bool hidden_pointer;
    bool shifts_arguments;
}

struct Win64FrameLayout {
    usize shadow_bytes;
    usize stack_argument_bytes;
    usize local_bytes;
    usize vector_save_bytes;
    usize fixed_allocation_bytes;
    usize saved_integer_registers;
    usize saved_vector_registers;
    usize body_stack_alignment;
    bool makes_calls;
    bool requires_unwind;
}

struct Win64LayoutCursor {
    usize size;
    usize alignment;
    usize pack;
    bool union_layout;
    usize bit_unit_offset;
    usize bit_unit_size;
    usize bit_used;
    bool bit_unit_active;
    bool ok;
}

struct Win64FieldLayout {
    usize byte_offset;
    usize bit_offset;
    usize size;
    usize alignment;
    usize bit_width;
    bool ok;
}

struct X64Code {
    DBuffer bytes;
    ptr byte relocation_data;
    PackedBuffer relocations;
    bool ok;
}

struct X64UnwindBuilder {
    ptr byte operation_data;
    PackedBuffer operations;
    usize prolog_size;
    usize frame_register;
    usize frame_offset;
    bool ok;
}

usize win64_abi_type_void() { return 0; }
usize win64_abi_type_integer() { return 1; }
usize win64_abi_type_pointer() { return 2; }
usize win64_abi_type_f32() { return 3; }
usize win64_abi_type_f64() { return 4; }
usize win64_abi_type_aggregate() { return 5; }
usize win64_abi_type_vector128() { return 6; }

usize win64_abi_location_none() { return 0; }
usize win64_abi_location_integer_register() { return 1; }
usize win64_abi_location_vector_register() { return 2; }
usize win64_abi_location_stack() { return 3; }
usize win64_abi_location_hidden_return() { return 4; }

usize win64_abi_register_rax() { return 0; }
usize win64_abi_register_rcx() { return 1; }
usize win64_abi_register_rdx() { return 2; }
usize win64_abi_register_rbx() { return 3; }
usize win64_abi_register_rsp() { return 4; }
usize win64_abi_register_rbp() { return 5; }
usize win64_abi_register_rsi() { return 6; }
usize win64_abi_register_rdi() { return 7; }
usize win64_abi_register_r8() { return 8; }
usize win64_abi_register_r9() { return 9; }
usize win64_abi_register_r10() { return 10; }
usize win64_abi_register_r11() { return 11; }
usize win64_abi_register_r12() { return 12; }
usize win64_abi_register_r13() { return 13; }
usize win64_abi_register_r14() { return 14; }
usize win64_abi_register_r15() { return 15; }

usize x64_relocation_relative32() { return 1; }
usize x64_relocation_absolute64() { return 2; }
usize x64_relocation_image_relative32() { return 3; }

usize x64_unwind_push_nonvolatile() { return 0; }
usize x64_unwind_allocate_large() { return 1; }
usize x64_unwind_allocate_small() { return 2; }
usize x64_unwind_set_frame_pointer() { return 3; }
usize x64_unwind_save_nonvolatile() { return 4; }
usize x64_unwind_save_nonvolatile_far() { return 5; }
usize x64_unwind_save_xmm128() { return 8; }
usize x64_unwind_save_xmm128_far() { return 9; }

usize x64_align_up(usize value, usize alignment) {
    if alignment <= 1 { return value; }
    usize remainder = value % alignment;
    if remainder == 0 { return value; }
    return value + alignment - remainder;
}

usize x64_min(usize left, usize right) {
    if left < right { return left; }
    return right;
}

usize x64_max(usize left, usize right) {
    if left > right { return left; }
    return right;
}

text win64_integer_register_name(usize code) {
    if code == 0 { return "rax"; }
    if code == 1 { return "rcx"; }
    if code == 2 { return "rdx"; }
    if code == 3 { return "rbx"; }
    if code == 4 { return "rsp"; }
    if code == 5 { return "rbp"; }
    if code == 6 { return "rsi"; }
    if code == 7 { return "rdi"; }
    if code == 8 { return "r8"; }
    if code == 9 { return "r9"; }
    if code == 10 { return "r10"; }
    if code == 11 { return "r11"; }
    if code == 12 { return "r12"; }
    if code == 13 { return "r13"; }
    if code == 14 { return "r14"; }
    if code == 15 { return "r15"; }
    return "none";
}

text win64_vector_register_name(usize code) {
    if code == 0 { return "xmm0"; }
    if code == 1 { return "xmm1"; }
    if code == 2 { return "xmm2"; }
    if code == 3 { return "xmm3"; }
    if code == 4 { return "xmm4"; }
    if code == 5 { return "xmm5"; }
    if code == 6 { return "xmm6"; }
    if code == 7 { return "xmm7"; }
    if code == 8 { return "xmm8"; }
    if code == 9 { return "xmm9"; }
    if code == 10 { return "xmm10"; }
    if code == 11 { return "xmm11"; }
    if code == 12 { return "xmm12"; }
    if code == 13 { return "xmm13"; }
    if code == 14 { return "xmm14"; }
    if code == 15 { return "xmm15"; }
    return "none";
}

text win64_location_kind_name(usize kind) {
    if kind == win64_abi_location_integer_register() {
        return "integer_register";
    }
    if kind == win64_abi_location_vector_register() {
        return "vector_register";
    }
    if kind == win64_abi_location_stack() { return "stack"; }
    if kind == win64_abi_location_hidden_return() {
        return "hidden_return";
    }
    return "none";
}
