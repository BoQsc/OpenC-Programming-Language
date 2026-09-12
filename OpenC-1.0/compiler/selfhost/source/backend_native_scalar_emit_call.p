import system.io;
import system.memory;
import system.text;

unsafe bool backend_native_scalar_emit_call(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize opcode, usize result, usize type_id, NativeLayout result_layout
) {
    if opcode == ir_op_call() {
        if native_compiler_intrinsic(
            context, function, instruction, result
        ) { return true; }
        if native_saturating_call(context, function, instruction) { return true; }
        if native_runtime_call(context, function, instruction) { return true; }
        if c_builtin_is(context, instruction, "text.byte_length", "system.text.byte_length") {
            usize value = d_operand_value(context, instruction, 0);
            x64_mov_r64_memory(function.code, 0, 4, native_slot(function, value) + 8);
            native_store(function, result, 0); return true;
        }
        bool hidden = result != 0 && native_indirect_aggregate(context, type_id);
        usize kind = read_record_field(context.instruction_detail, instruction, 0);
        usize target = read_record_field(context.instruction_detail, instruction, 1);
        usize count = d_operand_count(context, instruction);
        if kind != 3 || target >= context.symbols.length || count > 30 {
            function.code.ok = false; return true;
        }
        usize argument = 0;
        if hidden {
            native_address(function, result, 0);
            x64_mov_memory_r64(function.code, 4, 0, 0);
        }
        while argument < count {
            usize position = argument; if hidden { position = position + 1; }
            usize value = d_operand_value(context, instruction, argument);
            usize parameter = c_call_parameter(context, instruction, argument);
            bool address = false;
            bool slice_conversion = false;
            if parameter < context.symbols.length {
                usize mode = read_record_field(context.detail_data, parameter, 3);
                usize actual = native_value_read(function, function.value_types, value);
                usize expected = read_record_field(context.symbol_data, parameter, 4);
                slice_conversion = read_record_field(context.type_data, actual, 0) == 10 &&
                    read_record_field(context.type_data, expected, 0) == 11;
                address = mode == 1 && !c_type_is_reference(context, expected) &&
                    !c_type_is_reference(context, actual);
                if d_parameter_owned(context, parameter) &&
                    !c_type_is_pointer_like(context, expected) { address = true; }
            }
            if slice_conversion {
                usize actual = native_value_read(function, function.value_types, value);
                usize origin = native_value_read(function, function.value_origins, value);
                if origin == 0 { origin = value; }
                native_address(function, origin, 0);
                x64_mov_memory_r64(function.code, 4, 256 + argument * 16, 0);
                native_sequence_length(context, function, value, actual, 0);
                x64_mov_memory_r64(function.code, 4, 264 + argument * 16, 0);
                x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 141);
                x64_emit_memory_modrm(function.code, 0, 4, 256 + argument * 16);
            } else if address {
                if native_value_read(function, function.address_values, value) != 0 {
                    native_load(function, value, 0);
                } else { native_address(function, value, 0); }
            }
            else {
                usize actual = native_value_read(function, function.value_types, value);
                if native_indirect_aggregate(context, actual) {
                    if native_value_read(function,
                        function.address_values, value) != 0 {
                        native_load(function, value, 0);
                    } else { native_address(function, value, 0); }
                } else { native_load(function, value, 0); }
            }
            x64_mov_memory_r64(function.code, 4, position * 8, 0);
            argument = argument + 1;
        }
        // Marshal all arguments before loading volatile ABI registers.
        x64_mov_r64_memory(function.code, 1, 4, 0);
        x64_mov_r64_memory(function.code, 2, 4, 8);
        x64_mov_r64_memory(function.code, 8, 4, 16);
        x64_mov_r64_memory(function.code, 9, 4, 24);
        argument = 0;
        while argument < count && argument < 4 {
            usize position = argument; if hidden { position = position + 1; }
            usize value = d_operand_value(context, instruction, argument);
            usize actual = native_value_read(function, function.value_types, value);
            if position < 4 && native_float_type(context, actual) {
                x64_mov_r64_memory(function.code, 0, 4, position * 8);
                x64_movq_xmm_r64(function.code, position, 0);
            }
            argument = argument + 1;
        }
        x64_call_symbol(function.code, target, 0);
        if result != 0 && !hidden {
            if native_float_type(context, type_id) { x64_movq_r64_xmm(function.code, 0, 0); }
            native_store(function, result, 0);
        }
        return true;
    }
    if opcode == ir_op_scope_register() {
        usize ordinal = native_scope_ordinal(context, instruction);
        if ordinal >= function.scope_count { function.code.ok = false; return true; }
        x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
        x64_mov_memory_r64(function.code, 4, 1024 + ordinal * 8, 0);
        return true;
    }
    if opcode == ir_op_branch() || opcode == ir_op_branch_conditional() {
        usize first = d_operand_first(context, instruction);
        if opcode == ir_op_branch() {
            native_branch(function, read_record_field(context.operand_data, first, 2), 16);
        } else {
            native_load(function, d_operand_value(context, instruction, 0), 0);
            x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 192);
            native_branch(function, read_record_field(context.operand_data, first + 1, 2), 5);
            native_branch(function, read_record_field(context.operand_data, first + 2, 2), 16);
        }
        return true;
    }
    if opcode == ir_op_return() || opcode == ir_op_return_void() {
        if opcode == ir_op_return() {
            usize returned_type = native_value_read(function, function.value_types,
                d_operand_value(context, instruction, 0));
            if function.indirect_return {
                NativeLayout layout = native_layout(context, returned_type, 0);
                native_address(function, d_operand_value(context, instruction, 0), 11);
                x64_mov_r64_memory(function.code, 10, 4, 240);
                native_copy_value(function, layout.size);
                x64_mov_r64_memory(function.code, 0, 4, 240);
            } else {
                native_load(function, d_operand_value(context, instruction, 0), 0);
                if native_float_type(context, returned_type) {
                    x64_movq_xmm_r64(function.code, 0, 0);
                }
            }
        }
        native_scope_cleanup(context, function, instruction);
        // Cleanup calls may clobber a scalar return, so reload it afterward.
        if opcode == ir_op_return() && !function.indirect_return {
            native_load(function, d_operand_value(context, instruction, 0), 0);
            usize returned_type = native_value_read(function, function.value_types,
                d_operand_value(context, instruction, 0));
            if native_float_type(context, returned_type) {
                x64_movq_xmm_r64(function.code, 0, 0);
            }
        }
        x64_add_rsp(function.code, function.frame_size); x64_ret(function.code); return true;
    }
    return false;
}
