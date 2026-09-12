import system.io;
import system.memory;
import system.text;

unsafe bool backend_native_scalar_emit_composite(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize opcode, usize result, usize type_id, NativeLayout result_layout
) {
    if opcode == ir_op_bounds() {
        usize base = d_operand_value(context, instruction, 0);
        usize base_type = native_value_read(function, function.value_types, base);
        native_sequence_length(context, function, base, base_type, 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_cmp_r64_r64(function.code, 0, 11);
        native_checked_require(context, function, instruction, 2);
        return true;
    }
    if opcode == ir_op_slice_create() {
        usize base = d_operand_value(context, instruction, 0);
        usize base_type = native_value_read(function, function.value_types, base);
        usize base_kind = read_record_field(context.type_data, base_type, 0);
        if base_kind != 10 && base_kind != 11 { function.code.ok = false; return true; }
        if base_kind == 10 {
            usize origin = native_value_read(function, function.value_origins, base);
            if origin != 0 { base = origin; }
        }
        native_sequence_length(context, function, base, base_type, 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        native_load(function, d_operand_value(context, instruction, 2), 10);
        x64_cmp_r64_r64(function.code, 10, 11); native_require(function.code, 6);
        x64_cmp_r64_r64(function.code, 0, 10); native_require(function.code, 6);
        x64_binary_r64_r64(function.code, 41, 10, 0);
        x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 10);
        NativeLayout element = native_layout(context, read_record_field(context.type_data, base_type, 1), 0);
        x64_mov_r64_imm64(function.code, 10, cast(u64, element.size));
        x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 175); x64_emit_u8(function.code, 194);
        native_sequence_address(context, function, base, base_type, 11);
        x64_add_r64_r64(function.code, 0, 11); native_store(function, result, 0);
        return true;
    }
    if opcode == ir_op_address() {
        native_address(function, d_operand_value(context, instruction, 0), 0);
        native_store(function, result, 0); return true;
    }
    if opcode == ir_op_object_construct() {
        usize storage_value = d_operand_value(context, instruction, 0);
        usize value = d_operand_value(context, instruction, 1);
        usize value_type = native_value_read(function, function.value_types, value);
        NativeLayout layout = native_layout(context, value_type, 0);
        if !layout.valid { function.code.ok = false; return true; }
        native_address(function, storage_value, 10); native_store(function, result, 10);
        native_address(function, value, 11); native_copy_value(function, layout.size);
        return true;
    }
    if opcode == ir_op_object_destroy() { return true; }
    if opcode == ir_op_optional_none() || opcode == ir_op_optional_some() {
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        usize offset = 0;
        while offset < result_layout.size {
            x64_mov_memory_r64(function.code, 4, native_slot(function, result) + offset, 0);
            offset = offset + 8;
        }
        if opcode == ir_op_optional_some() {
            x64_mov_r64_imm64(function.code, 0, cast(u64, 1)); native_store(function, result, 0);
            usize value = d_operand_value(context, instruction, 0);
            NativeLayout element = native_layout(context, read_record_field(context.type_data, type_id, 1), 0);
            native_address(function, result, 10);
            x64_add_r64_imm8(function.code, 10, x64_align_up(1, element.alignment));
            native_address(function, value, 11); native_copy_value(function, element.size);
        }
        return true;
    }
    if opcode == ir_op_aggregate_create() || opcode == ir_op_status_create() || opcode == ir_op_array_create() {
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        usize offset = 0;
        while offset < result_layout.size {
            x64_mov_memory_r64(function.code, 4, native_slot(function, result) + offset, 0);
            offset = offset + 8;
        }
        usize argument = 0;
        while argument < d_operand_count(context, instruction) {
            DBuffer name = d_buffer_create(256);
            d_put_operand_immediate(context, name, instruction, argument);
            if opcode == ir_op_array_create() {
                NativeLayout element = native_layout(context, read_record_field(context.type_data, type_id, 1), 0);
                offset = argument * element.size;
            } else { offset = native_field_offset(context, type_id, d_buffer_text(name)); }
            d_buffer_destroy(name);
            if offset == cast(usize, 4294967295) { function.code.ok = false; return true; }
            usize value = d_operand_value(context, instruction, argument);
            usize member_type = native_value_read(function, function.value_types, value);
            native_address(function, result, 10);
            x64_mov_r64_imm64(function.code, 0, cast(u64, offset));
            x64_add_r64_r64(function.code, 10, 0);
            if native_scalar_type(context, member_type) {
                x64_mov_r64_r64(function.code, 11, 10);
                native_load(function, value, 0);
                native_indirect(context, function, member_type, true);
            } else {
                NativeLayout member = native_layout(context, member_type, 0);
                if !member.valid { function.code.ok = false; return true; }
                native_value_address(context, function, value, 11);
                native_copy_value(function, member.size);
            }
            argument = argument + 1;
        }
        return true;
    }
    if opcode == ir_op_aggregate_field() {
        usize base = d_operand_value(context, instruction, 0);
        usize base_type = native_value_read(function, function.value_types, base);
        if c_type_is_pointer_like(context, base_type) {
            base_type = read_record_field(context.type_data, base_type, 1);
        }
        usize base_kind = read_record_field(context.type_data, base_type, 0);
        if (base_kind == 10 || base_kind == 11 || base_kind == 7) &&
            d_instruction_text_is(context, instruction, "length") {
            native_sequence_length(context, function, base, base_type, 0);
            native_store(function, result, 0); return true;
        }
        if base_kind == 10 || base_kind == 11 {
            native_sequence_address(context, function, base, base_type, 11);
            native_load(function, d_operand_value(context, instruction, 1), 0);
            NativeLayout element = native_layout(context, read_record_field(context.type_data, base_type, 1), 0);
            x64_mov_r64_imm64(function.code, 10, cast(u64, element.size));
            x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 15);
            x64_emit_u8(function.code, 175); x64_emit_u8(function.code, 194);
            x64_add_r64_r64(function.code, 11, 0);
            if d_instruction_address_field(context, instruction) {
                native_store(function, result, 11);
                native_value_write(function, function.address_values, result, 1);
            }
            else if native_scalar_type(context, type_id) {
                native_indirect(context, function, type_id, false); native_store(function, result, 0);
            } else {
                native_address(function, result, 10); native_copy_value(function, result_layout.size);
            }
            return true;
        }
        DBuffer name = d_buffer_create(256);
        if read_record_field(context.instruction_detail, instruction, 0) == 5 {
            d_put_slice(name, context.source,
                read_record_field(context.instruction_detail, instruction, 1),
                read_record_field(context.instruction_detail, instruction, 2));
        } else { d_put_instruction_text(context, name, instruction); }
        usize offset = native_field_offset(context, base_type, d_buffer_text(name));
        if base_kind == 14 && d_buffer_text(name) != "present" {
            native_value_address(context, function, base, 11);
            x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 128);
            x64_emit_u8(function.code, 59); x64_emit_u8(function.code, 0);
            native_require(function.code, 5);
        }
        d_buffer_destroy(name);
        if offset == cast(usize, 4294967295) { function.code.ok = false; return true; }
        native_value_address(context, function, base, 11);
        x64_mov_r64_imm64(function.code, 0, cast(u64, offset));
        x64_add_r64_r64(function.code, 11, 0);
        if read_record_field(context.type_data, base_type, 0) == 8 &&
            d_instruction_text_is(context, instruction, "ok") {
            // status.code is an i32, not the bool result type.
            x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 139);
            x64_emit_u8(function.code, 3);
            x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
            native_condition(function.code, 4);
            native_store(function, result, 0);
        } else if d_instruction_address_field(context, instruction) {
            native_store(function, result, 11);
            native_value_write(function, function.address_values, result, 1);
        } else if native_scalar_type(context, type_id) {
            native_indirect(context, function, type_id, false);
            native_store(function, result, 0);
        } else {
            native_address(function, result, 10);
            native_copy_value(function, result_layout.size);
        }
        return true;
    }
    return false;
}
