import system.io;
import system.memory;
import system.text;

unsafe void native_load(ref NativeFunction function, usize value, usize reg) {
    x64_mov_r64_memory(function.code, reg, 4, native_slot(function, value));
}

unsafe void native_store(ref NativeFunction function, usize value, usize reg) {
    x64_mov_memory_r64(function.code, 4, native_slot(function, value), reg);
}

unsafe void native_address(ref NativeFunction function, usize value, usize reg) {
    x64_emit_rex(function.code, true, reg, 0, 4);
    x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, reg, 4, native_slot(function, value));
}

unsafe usize native_scalar_width(ref IrContext context, usize type_id) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind == 9 { return 4; }
    if kind == 5 || kind == 6 { return 1; }
    if kind == 12 || kind == 13 { return 8; }
    usize bits = read_record_field(context.type_data, type_id, 3);
    if bits == 0 { return 8; }
    return bits / 8;
}

unsafe bool native_float_type(ref IrContext context, usize type_id) {
    return type_id < context.types.length &&
        read_record_field(context.type_data, type_id, 0) == 4;
}

// Typed indirect access: R11 holds the address, RAX the value. In particular,
// byte/word/dword stores must never overwrite an adjacent aggregate field.
unsafe void native_indirect(ref IrContext context, ref NativeFunction function,
    usize type_id, bool store_value) {
    usize width = native_scalar_width(context, type_id);
    if width == 8 {
        if store_value { x64_mov_memory_r64(function.code, 11, 0, 0); }
        else { x64_mov_r64_memory(function.code, 0, 11, 0); }
        return;
    }
    if width != 1 && width != 2 && width != 4 { function.code.ok = false; return; }
    if store_value && width == 2 { x64_emit_u8(function.code, 102); }
    x64_emit_u8(function.code, 65);
    if store_value {
        usize operation = 137; if width == 1 { operation = 136; }
        x64_emit_u8(function.code, operation);
    } else if width == 4 { x64_emit_u8(function.code, 139); }
    else {
        x64_emit_u8(function.code, 15);
        usize operation = 182; if width == 2 { operation = 183; }
        x64_emit_u8(function.code, operation);
    }
    x64_emit_u8(function.code, 3);
    if !store_value { native_normalize(context, function, type_id); }
}

unsafe void native_condition(ref X64Code code, usize condition) {
    x64_emit_u8(code, 15); x64_emit_u8(code, 144 + condition);
    x64_emit_u8(code, 192);
    x64_zero_extend_al_eax(code);
}

unsafe void native_require(ref X64Code code, usize condition) {
    // The shared failure routine exits with code 70 and never returns.
    x64_emit_u8(code, 112 + condition); x64_emit_u8(code, 5);
    x64_call_symbol(code, cast(usize, 4294967295), 0);
}

unsafe usize native_skip(ref X64Code code, usize condition) {
    x64_emit_u8(code, 15); x64_emit_u8(code, 128 + condition);
    usize offset = code.bytes.length;
    x64_emit_u32(code, 0); return offset;
}

unsafe void native_skip_end(ref X64Code code, usize offset) {
    x64_patch_u32(code, offset, cast(u32, code.bytes.length - offset - 4));
}

unsafe usize native_jump(ref X64Code code) {
    x64_emit_u8(code, 233); usize patch = code.bytes.length;
    x64_emit_u32(code, 0); return patch;
}

unsafe void native_text_equal(ref NativeFunction function, usize left, usize right) {
    native_load(function, left, 8); native_load(function, right, 9);
    x64_mov_r64_memory(function.code, 10, 4, native_slot(function, left) + 8);
    x64_mov_r64_memory(function.code, 11, 4, native_slot(function, right) + 8);
    x64_cmp_r64_r64(function.code, 10, 11);
    usize mismatch_length = native_skip(function.code, 5);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210);
    usize empty = native_skip(function.code, 4);
    usize loop_start = function.code.bytes.length;
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 58);
    x64_emit_u8(function.code, 1);
    usize mismatch_byte = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 8, 1); x64_add_r64_imm8(function.code, 9, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255);
    x64_emit_u8(function.code, 202);
    x64_emit_u8(function.code, 117);
    x64_emit_u8(function.code, 256 - (function.code.bytes.length + 1 - loop_start));
    native_skip_end(function.code, empty);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    usize done = native_jump(function.code);
    native_skip_end(function.code, mismatch_length);
    native_skip_end(function.code, mismatch_byte);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_skip_end(function.code, done);
}

unsafe void native_allocate_stack(ref X64Code code, usize frame) {
    // Probe every page before moving RSP. Only volatile, non-argument registers
    // are touched, so register parameters survive this OpenC-owned prologue.
    // RSP stays unchanged throughout the probes: unwind has one allocation.
    if frame > cast(usize, 2147483647) { code.ok = false; return; }
    if frame >= 4096 {
        x64_mov_r64_r64(code, 11, 4);
        x64_mov_r64_imm64(code, 10, cast(u64, frame / 4096));
        usize loop_start = code.bytes.length;
        x64_emit_u8(code, 73); x64_emit_u8(code, 129); x64_emit_u8(code, 235);
        x64_emit_u32(code, 4096);
        x64_mov_r64_memory(code, 0, 11, 0);
        x64_emit_u8(code, 73); x64_emit_u8(code, 255); x64_emit_u8(code, 202);
        x64_emit_u8(code, 117);
        x64_emit_u8(code, 256 - (code.bytes.length + 1 - loop_start));
        if frame % 4096 != 0 {
            x64_emit_u8(code, 73); x64_emit_u8(code, 129); x64_emit_u8(code, 235);
            x64_emit_u32(code, frame % 4096);
            x64_mov_r64_memory(code, 0, 11, 0);
        }
    }
    x64_sub_rsp(code, frame);
}

unsafe void native_normalize(ref IrContext context, ref NativeFunction function, usize type_id) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    usize bits = read_record_field(context.type_data, type_id, 3);
    if kind == 6 { bits = 8; }
    if bits == 0 || bits >= 64 { return; }
    if kind == 2 {
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 193);
        x64_emit_u8(function.code, 224); x64_emit_u8(function.code, 64 - bits);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 193);
        x64_emit_u8(function.code, 248); x64_emit_u8(function.code, 64 - bits);
    } else if kind == 3 || kind == 6 {
        x64_mov_r64_imm64(function.code, 10, (cast(u64, 1) << bits) - cast(u64, 1));
        x64_binary_r64_r64(function.code, 33, 0, 10);
    }
}

unsafe bool native_scalar_type(ref IrContext context, usize type_id) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind == 9 {
        usize symbol = c_named_type_symbol(context, type_id);
        return symbol < context.symbols.length && read_record_field(context.symbol_data, symbol, 0) == resolution_symbol_enum();
    }
    return kind == 1 || kind == 2 || kind == 3 || kind == 4 || kind == 5 || kind == 6 ||
        kind == 12 || kind == 13;
}
