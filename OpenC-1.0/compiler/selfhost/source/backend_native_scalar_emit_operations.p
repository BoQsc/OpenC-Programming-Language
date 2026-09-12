import system.io;
import system.memory;
import system.text;

unsafe bool backend_native_scalar_emit_operations(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize opcode, usize result, usize type_id, NativeLayout result_layout
) {
    if opcode == ir_op_cast() || opcode == ir_op_reinterpret() || opcode == ir_op_unary() {
        native_load(function, d_operand_value(context, instruction, 0), 0);
        if opcode == ir_op_unary() {
            if d_instruction_text_is(context, instruction, "-") {
                if native_float_type(context, type_id) {
                    usize bits = read_record_field(context.type_data, type_id, 3);
                    x64_mov_r64_imm64(function.code, 10,
                        cast(u64, 1) << (bits - 1));
                    x64_xor_r64_r64(function.code, 0, 10);
                } else {
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 247);
                    x64_emit_u8(function.code, 216); native_require(function.code, 1);
                    native_check_result(context, function, type_id);
                }
            } else if d_instruction_text_is(context, instruction, "!") {
                x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
                x64_emit_u8(function.code, 192); native_condition(function.code, 4);
            } else if d_instruction_text_is(context, instruction, "~") {
                x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 247);
                x64_emit_u8(function.code, 208); native_normalize(context, function, type_id);
            } else if d_instruction_text_is(context, instruction, "*") {
                x64_mov_r64_r64(function.code, 11, 0);
                if !native_scalar_type(context, type_id) {
                    native_address(function, result, 10);
                    native_copy_value(function, result_layout.size); return true;
                }
                native_indirect(context, function, type_id, false);
            } else if !d_instruction_text_is(context, instruction, "+") {
                function.code.ok = false;
            }
        } else {
            bool unchecked = d_instruction_text_is(context, instruction, "cast_unchecked");
            usize source_type = native_value_read(function, function.value_types,
                d_operand_value(context, instruction, 0));
            if opcode == ir_op_cast() && native_float_type(context, source_type) &&
                native_float_type(context, type_id) {
                usize source_bits = read_record_field(context.type_data, source_type, 3);
                usize target_bits = read_record_field(context.type_data, type_id, 3);
                x64_movq_xmm_r64(function.code, 0, 0);
                if source_bits == 32 && target_bits == 64 {
                    x64_cvtss2sd_xmm_xmm(function.code, 0, 0);
                } else if source_bits == 64 && target_bits == 32 {
                    x64_cvtsd2ss_xmm_xmm(function.code, 0, 0);
                } else if source_bits != target_bits { function.code.ok = false; }
                x64_movq_r64_xmm(function.code, 0, 0);
            } else if opcode == ir_op_cast() && native_float_type(context, type_id) {
                native_integer_to_float(context, function, source_type, type_id);
            } else if opcode == ir_op_cast() && native_float_type(context, source_type) {
                native_float_to_integer(
                    context, function, source_type, type_id
                );
            }
            if !unchecked && opcode == ir_op_cast() {
                usize source_kind = read_record_field(context.type_data, source_type, 0);
                usize target_kind = read_record_field(context.type_data, type_id, 0);
                if (source_kind == 2 && (target_kind == 3 || target_kind == 6)) ||
                    ((source_kind == 3 || source_kind == 6) && target_kind == 2) {
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
                    x64_emit_u8(function.code, 192); native_require(function.code, 9);
                }
                native_check_result(context, function, type_id);
            }
            native_normalize(context, function, type_id);
        }
        native_store(function, result, 0); return true;
    }
    if opcode == ir_op_short_begin() {
        native_load(function, d_operand_value(context, instruction, 0), 0);
        native_store(function, result, 0);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 192);
        usize condition = 5;
        if d_instruction_text_is(context, instruction, "&&") { condition = 4; }
        usize patch = native_skip(function.code, condition);
        write_usize(function.short_patches, (result - function.first_value) * size_of(usize), patch);
        return true;
    }
    if opcode == ir_op_short_end() {
        usize destination = d_operand_value(context, instruction, 0);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        native_store(function, destination, 0);
        native_skip_end(function.code, read_usize(function.short_patches,
            (destination - function.first_value) * size_of(usize)));
        return true;
    }
    if opcode == ir_op_binary() || opcode == ir_op_compare() {
        usize left = d_operand_value(context, instruction, 0);
        usize text_type = native_value_read(function, function.value_types, left);
        if c_type_is_text(context, text_type) {
            if opcode != ir_op_compare() || (!d_instruction_text_is(context, instruction, "==") &&
                !d_instruction_text_is(context, instruction, "!=")) { function.code.ok = false; return true; }
            native_text_equal(function, left, d_operand_value(context, instruction, 1));
            if d_instruction_text_is(context, instruction, "!=") {
                x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 131);
                x64_emit_u8(function.code, 240); x64_emit_u8(function.code, 1);
            }
            native_store(function, result, 0); return true;
        }
        usize right = d_operand_value(context, instruction, 1);
        usize right_type = native_value_read(function, function.value_types, right);
        if native_float_type(context, text_type) || native_float_type(context, right_type) {
            if !native_float_type(context, text_type) || !native_float_type(context, right_type) {
                function.code.ok = false; return true;
            }
            if opcode == ir_op_compare() {
                native_float_compare(context, function, instruction, left, right);
            } else {
                usize bits = read_record_field(context.type_data, type_id, 3);
                native_float_operand(context, function, left, 0, bits);
                native_float_operand(context, function, right, 1, bits);
                usize operation = 0;
                if d_instruction_text_is(context, instruction, "+") { operation = 88; }
                if d_instruction_text_is(context, instruction, "-") { operation = 92; }
                if d_instruction_text_is(context, instruction, "*") { operation = 89; }
                if d_instruction_text_is(context, instruction, "/") { operation = 94; }
                if operation == 0 { function.code.ok = false; return true; }
                x64_scalar_float_xmm_xmm(function.code, bits, operation, 0, 1);
                x64_movq_r64_xmm(function.code, 0, 0);
            }
            native_store(function, result, 0); return true;
        }
        native_load(function, left, 0);
        native_load(function, right, 11);
        usize left_type = native_value_read(function, function.value_types, left);
        bool signed_value = read_record_field(context.type_data, left_type, 0) == 2;
        if opcode == ir_op_compare() {
            x64_cmp_r64_r64(function.code, 0, 11);
            usize condition = 16;
            if d_instruction_text_is(context, instruction, "==") { condition = 4; }
            if d_instruction_text_is(context, instruction, "!=") { condition = 5; }
            if d_instruction_text_is(context, instruction, "<") {
                condition = 2; if signed_value { condition = 12; }
            }
            if d_instruction_text_is(context, instruction, "<=") {
                condition = 6; if signed_value { condition = 14; }
            }
            if d_instruction_text_is(context, instruction, ">") {
                condition = 7; if signed_value { condition = 15; }
            }
            if d_instruction_text_is(context, instruction, ">=") {
                condition = 3; if signed_value { condition = 13; }
            }
            if condition == 16 { function.code.ok = false; return true; }
            native_condition(function.code, condition);
        } else {
            bool checked = true;
            if c_type_is_pointer_like(context, left_type) {
                NativeLayout element = native_layout(context,
                    read_record_field(context.type_data, left_type, 1), 0);
                usize pointer_right_type = native_value_read(
                    function, function.value_types,
                    d_operand_value(context, instruction, 1));
                if !element.valid || element.size == 0 ||
                    c_type_is_pointer_like(context, pointer_right_type) ||
                    (!d_instruction_text_is(context, instruction, "+") &&
                    !d_instruction_text_is(context, instruction, "-")) {
                    function.code.ok = false; return true;
                }
                x64_mov_r64_imm64(function.code, 10, cast(u64, element.size));
                x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 15);
                x64_emit_u8(function.code, 175); x64_emit_u8(function.code, 218);
                if d_instruction_text_is(context, instruction, "+") { x64_add_r64_r64(function.code, 0, 11); }
                else { x64_binary_r64_r64(function.code, 41, 0, 11); }
                native_store(function, result, 0); return true;
            }
            if d_instruction_text_is(context, instruction, "+") {
                x64_add_r64_r64(function.code, 0, 11);
            } else if d_instruction_text_is(context, instruction, "-") {
                x64_binary_r64_r64(function.code, 41, 0, 11);
            } else if d_instruction_text_is(context, instruction, "&") {
                x64_binary_r64_r64(function.code, 33, 0, 11); checked = false;
            } else if d_instruction_text_is(context, instruction, "|") {
                x64_binary_r64_r64(function.code, 9, 0, 11); checked = false;
            } else if d_instruction_text_is(context, instruction, "^") {
                x64_xor_r64_r64(function.code, 0, 11); checked = false;
            } else if d_instruction_text_is(context, instruction, "*") {
                if signed_value {
                    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 15);
                    x64_emit_u8(function.code, 175); x64_emit_u8(function.code, 195);
                    native_require(function.code, 1);
                } else {
                    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 247);
                    x64_emit_u8(function.code, 227);
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
                    x64_emit_u8(function.code, 210); native_require(function.code, 4);
                }
                native_check_result(context, function, type_id); checked = false;
            } else if d_instruction_text_is(context, instruction, "/") ||
                d_instruction_text_is(context, instruction, "%") {
                x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
                x64_emit_u8(function.code, 219); native_require(function.code, 5);
                if signed_value {
                    x64_mov_r64_imm64(function.code, 10, cast(u64, 1) << cast(usize, 63));
                    x64_cmp_r64_r64(function.code, 0, 10);
                    usize skip = native_skip(function.code, 5);
                    x64_mov_r64_imm64(function.code, 10, ~cast(u64, 0));
                    x64_cmp_r64_r64(function.code, 11, 10);
                    native_require(function.code, 5);
                    native_skip_end(function.code, skip);
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 153);
                    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 247);
                    x64_emit_u8(function.code, 251);
                } else {
                    x64_emit_u8(function.code, 49); x64_emit_u8(function.code, 210);
                    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 247);
                    x64_emit_u8(function.code, 243);
                }
                if d_instruction_text_is(context, instruction, "%") {
                    x64_mov_r64_r64(function.code, 0, 2);
                }
                native_check_result(context, function, type_id); checked = false;
            } else if d_instruction_text_is(context, instruction, "<<") ||
                d_instruction_text_is(context, instruction, ">>") {
                usize bits = read_record_field(context.type_data, left_type, 3);
                if bits == 0 { bits = 64; }
                x64_mov_r64_imm64(function.code, 10, cast(u64, bits));
                x64_cmp_r64_r64(function.code, 11, 10); native_require(function.code, 2);
                x64_mov_r64_r64(function.code, 1, 11);
                bool shift_left = d_instruction_text_is(context, instruction, "<<");
                usize extension = 232;
                if signed_value { extension = 248; }
                if shift_left {
                    x64_mov_r64_r64(function.code, 11, 0);
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 211);
                    x64_emit_u8(function.code, 224);
                    x64_mov_r64_r64(function.code, 10, 0);
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 211);
                    x64_emit_u8(function.code, extension);
                    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 4);
                    x64_mov_r64_r64(function.code, 0, 10);
                    native_check_result(context, function, type_id);
                } else {
                    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 211);
                    x64_emit_u8(function.code, extension);
                }
                checked = false;
            } else { function.code.ok = false; return true; }
            if checked {
                usize no_overflow = 3; if signed_value { no_overflow = 1; }
                native_require(function.code, no_overflow);
                native_check_result(context, function, type_id);
            }
        }
        native_store(function, result, 0); return true;
    }
    return false;
}
