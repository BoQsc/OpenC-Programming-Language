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

unsafe void native_check_result(
    ref IrContext context, ref NativeFunction function, usize type_id
) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    usize bits = read_record_field(context.type_data, type_id, 3);
    if kind == 6 { bits = 8; }
    if bits == 0 || bits >= 64 { return; }
    if kind == 2 {
        u64 limit = (cast(u64, 1) << (bits - 1)) - cast(u64, 1);
        x64_mov_r64_imm64(function.code, 10, limit);
        x64_cmp_r64_r64(function.code, 0, 10);
        native_require(function.code, 14);
        x64_mov_r64_imm64(function.code, 10, ~limit);
        x64_cmp_r64_r64(function.code, 0, 10);
        native_require(function.code, 13);
    } else if kind == 3 || kind == 6 {
        x64_mov_r64_imm64(function.code, 10,
            (cast(u64, 1) << bits) - cast(u64, 1));
        x64_cmp_r64_r64(function.code, 0, 10);
        native_require(function.code, 6);
    }
}

unsafe void native_branch(
    ref NativeFunction function, usize target, usize condition
) {
    if condition == 16 { x64_emit_u8(function.code, 233); }
    else { x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 128 + condition); }
    usize patch = function.code.bytes.length;
    x64_emit_u32(function.code, 0);
    write_record_field(function.branch_patches, function.branch_count, 0, patch);
    write_record_field(function.branch_patches, function.branch_count, 1, target);
    function.branch_count = function.branch_count + 1;
}

unsafe usize native_scope_ordinal(ref IrContext context, usize instruction) {
    usize ordinal = 0; usize index = 0;
    while index < instruction {
        if read_record_field(context.instruction_data, index, 2) == ir_op_scope_register() {
            ordinal = ordinal + 1;
        }
        index = index + 1;
    }
    return ordinal;
}

unsafe void native_scope_call(ref IrContext context, ref NativeFunction function,
    usize instruction) {
    if d_instruction_text_is(context, instruction, "destroy") { return; }
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize target = read_record_field(context.instruction_detail, instruction, 1);
    usize count = d_operand_count(context, instruction);
    if kind == 7 && c_builtin_is(context, instruction,
        "memory.free", "system.memory.free") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        native_heap_free_r8(function); return;
    }
    if kind != 3 || target >= context.symbols.length || count > 30 {
        function.code.ok = false; return;
    }
    usize argument = 0;
    while argument < count {
        usize value = d_operand_value(context, instruction, argument);
        usize type_id = native_value_read(function, function.value_types, value);
        usize parameter = c_call_parameter(context, instruction, argument);
        bool owned_address = parameter < context.symbols.length &&
            d_parameter_owned(context, parameter) && !c_type_is_pointer_like(context,
                read_record_field(context.symbol_data, parameter, 4));
        if native_indirect_aggregate(context, type_id) || owned_address {
            native_address(function, value, 0);
        }
        else { native_load(function, value, 0); }
        x64_mov_memory_r64(function.code, 4, argument * 8, 0);
        argument = argument + 1;
    }
    x64_mov_r64_memory(function.code, 1, 4, 0);
    x64_mov_r64_memory(function.code, 2, 4, 8);
    x64_mov_r64_memory(function.code, 8, 4, 16);
    x64_mov_r64_memory(function.code, 9, 4, 24);
    x64_call_symbol(function.code, target, 0);
}

unsafe void native_scope_cleanup(ref IrContext context, ref NativeFunction function,
    usize before_instruction) {
    usize index = before_instruction;
    while index != 0 {
        index = index - 1;
        if read_record_field(context.instruction_data, index, 2) == ir_op_scope_register() {
            usize ordinal = native_scope_ordinal(context, index);
            x64_mov_r64_memory(function.code, 0, 4, 1024 + ordinal * 8);
            x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 192); usize inactive = native_skip(function.code, 4);
            x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
            x64_mov_memory_r64(function.code, 4, 1024 + ordinal * 8, 0);
            native_scope_call(context, function, index);
            native_skip_end(function.code, inactive);
        }
    }
}

unsafe void native_checked_require(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize condition
) {
    usize satisfied = native_skip(function.code, condition);
    native_scope_cleanup(context, function, instruction);
    x64_call_symbol(function.code, cast(usize, 4294967295), 0);
    native_skip_end(function.code, satisfied);
}

struct NativeInteger {
    u64 value;
    bool valid;
}

struct NativeFloat {
    u64 value;
    bool valid;
}

unsafe u64 native_f64_bits(f64 value) {
    ptr byte data = reinterpret(ptr byte, &value);
    u64 result = cast(u64, 0); usize index = 0;
    while index < 8 {
        result = result | (cast(u64, cast(u8, *(data + index))) << (index * 8));
        index = index + 1;
    }
    return result;
}

unsafe u64 native_f32_bits(f32 value) {
    ptr byte data = reinterpret(ptr byte, &value);
    u64 result = cast(u64, 0); usize index = 0;
    while index < 4 {
        result = result | (cast(u64, cast(u8, *(data + index))) << (index * 8));
        index = index + 1;
    }
    return result;
}

unsafe NativeFloat native_float_bits(text literal, usize bits) {
    usize index = 0; bool negative = false;
    if byte_at_or_zero(literal, 0) == 45 { negative = true; index = 1; }
    f64 value = 0.0; f64 divisor = 1.0; bool fraction = false;
    usize digits = 0; i32 exponent = 0; bool exponent_negative = false;
    while index < literal.length {
        u8 octet = byte_at_or_zero(literal, index);
        if octet == 95 { index = index + 1; continue; }
        if octet == 46 && !fraction { fraction = true; index = index + 1; continue; }
        if octet == 101 || octet == 69 { index = index + 1; break; }
        if octet < 48 || octet > 57 {
            return NativeFloat{ value = cast(u64, 0), valid = false };
        }
        value = value * 10.0 + cast(f64, octet - 48);
        if fraction { divisor = divisor * 10.0; }
        digits = digits + 1; index = index + 1;
    }
    if index < literal.length && (byte_at_or_zero(literal, index) == 43 ||
        byte_at_or_zero(literal, index) == 45) {
        exponent_negative = byte_at_or_zero(literal, index) == 45; index = index + 1;
    }
    usize exponent_digits = 0;
    while index < literal.length {
        u8 octet = byte_at_or_zero(literal, index); index = index + 1;
        if octet == 95 { continue; }
        if octet < 48 || octet > 57 || exponent > 1000 {
            return NativeFloat{ value = cast(u64, 0), valid = false };
        }
        exponent = exponent * 10 + cast(i32, octet - 48); exponent_digits = exponent_digits + 1;
    }
    if exponent_negative { exponent = -exponent; }
    value = value / divisor;
    while exponent > 0 { value = value * 10.0; exponent = exponent - 1; }
    while exponent < 0 { value = value / 10.0; exponent = exponent + 1; }
    if negative { value = -value; }
    if digits == 0 || (exponent_digits == 0 &&
        (byte_at_or_zero(literal, literal.length - 1) == 101 ||
         byte_at_or_zero(literal, literal.length - 1) == 69)) {
        return NativeFloat{ value = cast(u64, 0), valid = false };
    }
    if bits == 32 {
        f32 narrowed = cast(f32, value);
        return NativeFloat{ value = native_f32_bits(narrowed), valid = true };
    }
    if bits == 64 { return NativeFloat{ value = native_f64_bits(value), valid = true }; }
    return NativeFloat{ value = cast(u64, 0), valid = false };
}

NativeInteger native_integer_bits(text literal) {
    usize index = 0;
    bool negative = false;
    if byte_at_or_zero(literal, 0) == 45 { negative = true; index = 1; }
    u64 radix = cast(u64, 10);
    if byte_at_or_zero(literal, index) == 48 {
        u8 marker = byte_at_or_zero(literal, index + 1);
        if marker == 120 || marker == 88 { radix = cast(u64, 16); index = index + 2; }
        else if marker == 98 || marker == 66 { radix = cast(u64, 2); index = index + 2; }
    }
    usize digits = 0;
    u64 value = cast(u64, 0);
    u64 maximum = ~cast(u64, 0);
    while index < literal.length {
        u8 octet = byte_at_or_zero(literal, index);
        index = index + 1;
        if octet == 95 { continue; }
        u64 digit = cast(u64, 16);
        if octet >= 48 && octet <= 57 { digit = cast(u64, octet - 48); }
        else if octet >= 65 && octet <= 70 { digit = cast(u64, octet - 65 + 10); }
        else if octet >= 97 && octet <= 102 { digit = cast(u64, octet - 97 + 10); }
        if digit >= radix || value > (maximum - digit) / radix {
            return NativeInteger{ value = cast(u64, 0), valid = false };
        }
        value = value * radix + digit;
        digits = digits + 1;
    }
    if negative {
        if value > (cast(u64, 1) << cast(usize, 63)) {
            return NativeInteger{ value = cast(u64, 0), valid = false };
        }
        if value != cast(u64, 0) { value = (~value) + cast(u64, 1); }
    }
    return NativeInteger{ value = value, valid = digits != 0 };
}

unsafe void native_float_operand(ref IrContext context, ref NativeFunction function,
    usize value, usize destination, usize operation_bits) {
    usize type_id = native_value_read(function, function.value_types, value);
    if !native_float_type(context, type_id) { function.code.ok = false; return; }
    usize bits = read_record_field(context.type_data, type_id, 3);
    native_load(function, value, 0); x64_movq_xmm_r64(function.code, destination, 0);
    if bits == 32 && operation_bits == 64 {
        x64_cvtss2sd_xmm_xmm(function.code, destination, destination);
    } else if bits != operation_bits { function.code.ok = false; }
}

unsafe void native_integer_to_float(ref IrContext context,
    ref NativeFunction function, usize source_type, usize target_type) {
    usize source_kind = read_record_field(context.type_data, source_type, 0);
    usize source_bits = read_record_field(context.type_data, source_type, 3);
    usize target_bits = read_record_field(context.type_data, target_type, 3);
    if source_bits == 0 { source_bits = 64; }
    bool unsigned_u64 = (source_kind == 3 || source_kind == 6) && source_bits == 64;
    if !unsigned_u64 {
        x64_cvtsi2s_xmm_r64(function.code, target_bits, 0, 0);
    } else {
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 192); usize large = native_skip(function.code, 8);
        x64_cvtsi2s_xmm_r64(function.code, target_bits, 0, 0);
        usize done = native_jump(function.code); native_skip_end(function.code, large);
        x64_mov_r64_r64(function.code, 10, 0);
        x64_mov_r64_r64(function.code, 11, 0); x64_and_r64_imm8(function.code, 11, 1);
        x64_shift_r64_imm8(function.code, 5, 10, 1);
        x64_binary_r64_r64(function.code, 9, 10, 11);
        x64_cvtsi2s_xmm_r64(function.code, target_bits, 0, 10);
        x64_scalar_float_xmm_xmm(function.code, target_bits, 88, 0, 0);
        native_skip_end(function.code, done);
    }
    x64_movq_r64_xmm(function.code, 0, 0);
}

unsafe void native_float_to_integer(
    ref IrContext context,
    ref NativeFunction function,
    usize source_type,
    usize target_type
) {
    usize source_bits = read_record_field(context.type_data, source_type, 3);
    x64_movq_xmm_r64(function.code, 0, 0);
    x64_cvtts2si_r64_xmm(function.code, source_bits, 0, 0);
    x64_mov_r64_r64(function.code, 10, 0);
    // Checked float-to-integer conversion requires an exact mathematical
    // integer. Round-trip comparison also rejects fractions and infinities;
    // the parity check rejects NaN before equality can observe ZF.
    x64_cvtsi2s_xmm_r64(function.code, source_bits, 1, 10);
    x64_ucomi_xmm_xmm(function.code, source_bits, 0, 1);
    native_require(function.code, 11);
    native_require(function.code, 4);
    x64_mov_r64_r64(function.code, 0, 10);
    native_check_result(context, function, target_type);
}

unsafe void native_float_compare(ref IrContext context, ref NativeFunction function,
    usize instruction, usize left, usize right) {
    usize left_type = native_value_read(function, function.value_types, left);
    usize right_type = native_value_read(function, function.value_types, right);
    usize bits = read_record_field(context.type_data, left_type, 3);
    usize right_bits = read_record_field(context.type_data, right_type, 3);
    if right_bits > bits { bits = right_bits; }
    native_float_operand(context, function, left, 0, bits);
    native_float_operand(context, function, right, 1, bits);
    x64_ucomi_xmm_xmm(function.code, bits, 0, 1);
    usize condition = 16; bool ordered = false; bool inverse_ordered = false;
    if d_instruction_text_is(context, instruction, "==") { condition = 4; ordered = true; }
    if d_instruction_text_is(context, instruction, "!=") { condition = 5; inverse_ordered = true; }
    if d_instruction_text_is(context, instruction, "<") { condition = 2; ordered = true; }
    if d_instruction_text_is(context, instruction, "<=") { condition = 6; ordered = true; }
    if d_instruction_text_is(context, instruction, ">") { condition = 7; }
    if d_instruction_text_is(context, instruction, ">=") { condition = 3; }
    if condition == 16 { function.code.ok = false; return; }
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 144 + condition);
    x64_emit_u8(function.code, 192);
    if ordered || inverse_ordered {
        usize parity_condition = 11; if inverse_ordered { parity_condition = 10; }
        x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 144 + parity_condition);
        x64_emit_u8(function.code, 194);
        if ordered { x64_emit_u8(function.code, 32); }
        else { x64_emit_u8(function.code, 8); }
        x64_emit_u8(function.code, 208);
    }
    x64_zero_extend_al_eax(function.code);
}

unsafe void native_saturating_limit(ref IrContext context, ref NativeFunction function,
    usize type_id, bool maximum, usize reg) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    usize bits = read_record_field(context.type_data, type_id, 3);
    if bits == 0 { bits = 64; }
    u64 value = ~cast(u64, 0);
    if kind == 2 {
        value = cast(u64, 1) << (bits - 1);
        if maximum { value = value - cast(u64, 1); }
        else if bits < 64 { value = ~(value - cast(u64, 1)); }
    } else if bits < 64 { value = (cast(u64, 1) << bits) - cast(u64, 1); }
    x64_mov_r64_imm64(function.code, reg, value);
}

unsafe bool native_call_name_is(ref IrContext context, usize instruction, text expected) {
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize one = read_record_field(context.instruction_detail, instruction, 1);
    usize two = read_record_field(context.instruction_detail, instruction, 2);
    if kind == 3 { return d_symbol_name_is(context, one, expected); }
    return span_equals_ascii(context.source, one, two, expected);
}

unsafe bool native_saturating_call(ref IrContext context, ref NativeFunction function,
    usize instruction) {
    bool add = native_call_name_is(context, instruction, "saturating_add");
    bool sub = native_call_name_is(context, instruction, "saturating_sub");
    bool mul = native_call_name_is(context, instruction, "saturating_mul");
    if !add && !sub && !mul { return false; }
    usize result = read_record_field(context.instruction_data, instruction, 1);
    usize type_id = read_record_field(context.instruction_data, instruction, 3);
    usize kind = read_record_field(context.type_data, type_id, 0);
    usize bits = read_record_field(context.type_data, type_id, 3);
    if bits == 0 { bits = 64; }
    if (kind != 2 && kind != 3 && kind != 6) || d_operand_count(context, instruction) != 2 {
        function.code.ok = false; return true;
    }
    native_load(function, d_operand_value(context, instruction, 0), 0);
    native_load(function, d_operand_value(context, instruction, 1), 11);
    x64_mov_r64_r64(function.code, 10, 0);
    bool signed_value = kind == 2;
    if mul && signed_value {
        x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 175); x64_emit_u8(function.code, 195);
    } else if mul {
        x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 247);
        x64_emit_u8(function.code, 227);
    } else if add { x64_add_r64_r64(function.code, 0, 11); }
    else { x64_binary_r64_r64(function.code, 41, 0, 11); }
    if bits == 64 {
        usize no_overflow = 0;
        if signed_value { no_overflow = native_skip(function.code, 1); }
        else if mul {
            x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 210); no_overflow = native_skip(function.code, 4);
        } else { no_overflow = native_skip(function.code, 3); }
        if !signed_value && sub {
            x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        } else if signed_value {
            if mul { x64_xor_r64_r64(function.code, 10, 11); }
            x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 210);
            usize negative = native_skip(function.code, 8);
            native_saturating_limit(context, function, type_id, true, 0);
            usize clamped = native_jump(function.code); native_skip_end(function.code, negative);
            native_saturating_limit(context, function, type_id, false, 0);
            native_skip_end(function.code, clamped);
        } else { native_saturating_limit(context, function, type_id, true, 0); }
        native_skip_end(function.code, no_overflow);
    } else if signed_value {
        native_saturating_limit(context, function, type_id, true, 11);
        x64_cmp_r64_r64(function.code, 0, 11);
        usize not_high = native_skip(function.code, 14);
        native_saturating_limit(context, function, type_id, true, 0);
        usize done = native_jump(function.code); native_skip_end(function.code, not_high);
        native_saturating_limit(context, function, type_id, false, 11);
        x64_cmp_r64_r64(function.code, 0, 11);
        usize not_low = native_skip(function.code, 13);
        native_saturating_limit(context, function, type_id, false, 0);
        native_skip_end(function.code, not_low); native_skip_end(function.code, done);
    } else if sub {
        usize no_borrow = native_skip(function.code, 3);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        native_skip_end(function.code, no_borrow);
    } else {
        native_saturating_limit(context, function, type_id, true, 11);
        x64_cmp_r64_r64(function.code, 0, 11);
        usize in_range = native_skip(function.code, 6);
        native_saturating_limit(context, function, type_id, true, 0);
        native_skip_end(function.code, in_range);
    }
    native_store(function, result, 0); return true;
}
