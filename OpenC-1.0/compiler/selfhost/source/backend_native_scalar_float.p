import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
