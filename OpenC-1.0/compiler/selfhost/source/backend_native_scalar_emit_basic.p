import system.io;
import system.memory;
import system.text;

unsafe bool backend_native_scalar_emit_basic(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize opcode, usize result, usize type_id, NativeLayout result_layout
) {
    if opcode == ir_op_nop() {
        if result != 0 && result_layout.size != 0 {
            x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
            usize zero_offset = 0;
            while zero_offset < result_layout.size {
                x64_mov_memory_r64(function.code, 4,
                    native_slot(function, result) + zero_offset, 0);
                zero_offset = zero_offset + 8;
            }
        }
        return true;
    }
    if opcode == ir_op_target_fault() {
        native_scope_cleanup(context, function, instruction);
        x64_call_symbol(function.code, cast(usize, 4294967294), 0);
        return true;
    }
    if opcode == ir_op_const_text() {
        usize literal_length = read_record_field(
            context.instruction_detail, instruction, 2);
        DBuffer literal = d_buffer_create(literal_length + 16);
        d_put_instruction_text(context, literal, instruction);
        usize start = function.constants.length;
        if !native_decode_text(function.constants, d_buffer_text(literal)) {
            function.code.ok = false;
        }
        d_buffer_destroy(literal);
        usize length = function.constants.length - start;
        d_put_byte(function.constants, 0);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 141);
        x64_emit_u8(function.code, 5);
        usize patch = function.code.bytes.length;
        x64_emit_u32(function.code, 0);
        x64_add_relocation(function.code, patch, x64_relocation_relative32(),
            cast(usize, 2147483648) + start, 0, 4);
        native_store(function, result, 0);
        x64_mov_r64_imm64(function.code, 0, cast(u64, length));
        x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
        return true;
    }
    if opcode == ir_op_const_float() {
        DBuffer literal = d_buffer_create(128);
        d_put_instruction_text(context, literal, instruction);
        NativeFloat parsed = native_float_bits(d_buffer_text(literal),
            read_record_field(context.type_data, type_id, 3));
        d_buffer_destroy(literal);
        if !parsed.valid { function.code.ok = false; return true; }
        x64_mov_r64_imm64(function.code, 0, parsed.value);
        native_store(function, result, 0); return true;
    }
    if opcode == ir_op_const_integer() || opcode == ir_op_const_bool() {
        DBuffer literal = d_buffer_create(128);
        d_put_instruction_text(context, literal, instruction);
        u64 value = cast(u64, 0);
        if opcode == ir_op_const_bool() {
            if d_buffer_text(literal) == "true" { value = cast(u64, 1); }
        } else {
            NativeInteger parsed = native_integer_bits(d_buffer_text(literal));
            if !parsed.valid { function.code.ok = false; }
            value = parsed.value;
        }
        d_buffer_destroy(literal);
        x64_mov_r64_imm64(function.code, 0, value);
        native_store(function, result, 0); return true;
    }
    if opcode == ir_op_local_alloc() {
        usize parameter = c_local_parameter(context, instruction);
        if parameter < context.symbols.length {
            usize index = 0;
            while index < ir_parameter_count(context, context.function_symbol) &&
                ir_parameter_at(context, context.function_symbol, index) != parameter {
                index = index + 1;
            }
            if function.indirect_return { index = index + 1; }
            x64_mov_r64_memory(function.code, 0, 4, function.frame_size + 8 + index * 8);
            usize parameter_mode = read_record_field(
                context.detail_data, parameter, 3
            );
            if parameter_mode == 1 &&
                !c_type_is_reference(context, type_id) {
                native_store(function, result, 0);
                native_value_write(
                    function, function.address_values, result, 1
                );
            } else if native_indirect_aggregate(context, type_id) ||
                (d_parameter_owned(context, parameter) && !c_type_is_pointer_like(context, type_id)) {
                x64_mov_r64_r64(function.code, 11, 0);
                native_address(function, result, 10);
                native_copy_value(function, result_layout.size);
            } else {
                native_store(function, result, 0);
            }
        }
        return true;
    }
    if opcode == ir_op_load() || opcode == ir_op_store() {
        usize source = d_operand_value(context, instruction, 0);
        usize destination = result;
        if opcode == ir_op_store() {
            destination = source;
            source = d_operand_value(context, instruction, 1);
        }
        if opcode == ir_op_load() {
            usize origin = native_value_read(function, function.value_origins, source);
            if origin == 0 { origin = source; }
            native_value_write(function, function.value_origins, result, origin);
        }
        usize copy_type = native_value_read(function, function.value_types, source);
        usize destination_type_for_copy = native_value_read(
            function, function.value_types, destination);
        if opcode == ir_op_store() && read_record_field(context.type_data, copy_type, 0) == 10 &&
            read_record_field(context.type_data, destination_type_for_copy, 0) == 11 {
            usize origin = native_value_read(function, function.value_origins, source);
            if origin == 0 { origin = source; }
            native_address(function, origin, 0); native_store(function, destination, 0);
            native_sequence_length(context, function, source, copy_type, 0);
            x64_mov_memory_r64(function.code, 4, native_slot(function, destination) + 8, 0);
            return true;
        }
        if opcode == ir_op_load() { copy_type = type_id; }
        if !native_scalar_type(context, copy_type) {
            NativeLayout layout = native_layout(context, copy_type, 0);
            if !layout.valid { function.code.ok = false; return true; }
            native_value_address(context, function, source, 11);
            if opcode == ir_op_store() &&
                d_operand_immediate_is(context, instruction, 0, "deref") {
                native_load(function, destination, 10);
            } else { native_value_address(context, function, destination, 10); }
            native_copy_value(function, layout.size); return true;
        }
        native_load(function, source, 0);
        usize destination_type = native_value_read(
            function, function.value_types, destination);
        usize source_type = native_value_read(function, function.value_types, source);
        if opcode == ir_op_load() && (
            (c_type_is_reference(context, source_type) &&
                !c_type_is_reference(context, type_id)) ||
            native_value_read(
                function, function.address_values, source
            ) != 0
        ) {
            x64_mov_r64_r64(function.code, 11, 0);
            native_indirect(context, function, type_id, false);
        }
        if opcode == ir_op_store() && ((c_type_is_reference(context, destination_type) &&
            !d_operand_immediate_is(context, instruction, 0, "bind")) ||
            d_operand_immediate_is(context, instruction, 0, "deref") ||
            native_value_read(
                function, function.address_values, destination
            ) != 0) {
            native_load(function, destination, 11);
            native_indirect(context, function, source_type, true);
        } else { native_store(function, destination, 0); }
        return true;
    }
    return false;
}
