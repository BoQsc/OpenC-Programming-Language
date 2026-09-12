import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
