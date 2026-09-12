import system.io;
import system.memory;
import system.text;

unsafe void native_scalar_instruction(
    ref IrContext context, ref NativeFunction function, usize instruction
) {
    usize opcode = read_record_field(context.instruction_data, instruction, 2);
    usize result = read_record_field(context.instruction_data, instruction, 1);
    usize type_id = read_record_field(context.instruction_data, instruction, 3);
    NativeLayout result_layout = native_layout(context, type_id, 0);
    if result != 0 && !result_layout.valid {
        function.code.ok = false; return;
    }
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
        return;
    }
    if opcode == ir_op_target_fault() {
        native_scope_cleanup(context, function, instruction);
        x64_call_symbol(function.code, cast(usize, 4294967294), 0);
        return;
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
        return;
    }
    if opcode == ir_op_const_float() {
        DBuffer literal = d_buffer_create(128);
        d_put_instruction_text(context, literal, instruction);
        NativeFloat parsed = native_float_bits(d_buffer_text(literal),
            read_record_field(context.type_data, type_id, 3));
        d_buffer_destroy(literal);
        if !parsed.valid { function.code.ok = false; return; }
        x64_mov_r64_imm64(function.code, 0, parsed.value);
        native_store(function, result, 0); return;
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
        native_store(function, result, 0); return;
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
        return;
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
            return;
        }
        if opcode == ir_op_load() { copy_type = type_id; }
        if !native_scalar_type(context, copy_type) {
            NativeLayout layout = native_layout(context, copy_type, 0);
            if !layout.valid { function.code.ok = false; return; }
            native_value_address(context, function, source, 11);
            if opcode == ir_op_store() &&
                d_operand_immediate_is(context, instruction, 0, "deref") {
                native_load(function, destination, 10);
            } else { native_value_address(context, function, destination, 10); }
            native_copy_value(function, layout.size); return;
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
        return;
    }
    if opcode == ir_op_bounds() {
        usize base = d_operand_value(context, instruction, 0);
        usize base_type = native_value_read(function, function.value_types, base);
        native_sequence_length(context, function, base, base_type, 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_cmp_r64_r64(function.code, 0, 11);
        native_checked_require(context, function, instruction, 2);
        return;
    }
    if opcode == ir_op_slice_create() {
        usize base = d_operand_value(context, instruction, 0);
        usize base_type = native_value_read(function, function.value_types, base);
        usize base_kind = read_record_field(context.type_data, base_type, 0);
        if base_kind != 10 && base_kind != 11 { function.code.ok = false; return; }
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
        return;
    }
    if opcode == ir_op_address() {
        native_address(function, d_operand_value(context, instruction, 0), 0);
        native_store(function, result, 0); return;
    }
    if opcode == ir_op_object_construct() {
        usize storage_value = d_operand_value(context, instruction, 0);
        usize value = d_operand_value(context, instruction, 1);
        usize value_type = native_value_read(function, function.value_types, value);
        NativeLayout layout = native_layout(context, value_type, 0);
        if !layout.valid { function.code.ok = false; return; }
        native_address(function, storage_value, 10); native_store(function, result, 10);
        native_address(function, value, 11); native_copy_value(function, layout.size);
        return;
    }
    if opcode == ir_op_object_destroy() { return; }
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
        return;
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
            if offset == cast(usize, 4294967295) { function.code.ok = false; return; }
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
                if !member.valid { function.code.ok = false; return; }
                native_value_address(context, function, value, 11);
                native_copy_value(function, member.size);
            }
            argument = argument + 1;
        }
        return;
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
            native_store(function, result, 0); return;
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
            return;
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
        if offset == cast(usize, 4294967295) { function.code.ok = false; return; }
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
        return;
    }
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
                    native_copy_value(function, result_layout.size); return;
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
        native_store(function, result, 0); return;
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
        return;
    }
    if opcode == ir_op_short_end() {
        usize destination = d_operand_value(context, instruction, 0);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        native_store(function, destination, 0);
        native_skip_end(function.code, read_usize(function.short_patches,
            (destination - function.first_value) * size_of(usize)));
        return;
    }
    if opcode == ir_op_binary() || opcode == ir_op_compare() {
        usize left = d_operand_value(context, instruction, 0);
        usize text_type = native_value_read(function, function.value_types, left);
        if c_type_is_text(context, text_type) {
            if opcode != ir_op_compare() || (!d_instruction_text_is(context, instruction, "==") &&
                !d_instruction_text_is(context, instruction, "!=")) { function.code.ok = false; return; }
            native_text_equal(function, left, d_operand_value(context, instruction, 1));
            if d_instruction_text_is(context, instruction, "!=") {
                x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 131);
                x64_emit_u8(function.code, 240); x64_emit_u8(function.code, 1);
            }
            native_store(function, result, 0); return;
        }
        usize right = d_operand_value(context, instruction, 1);
        usize right_type = native_value_read(function, function.value_types, right);
        if native_float_type(context, text_type) || native_float_type(context, right_type) {
            if !native_float_type(context, text_type) || !native_float_type(context, right_type) {
                function.code.ok = false; return;
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
                if operation == 0 { function.code.ok = false; return; }
                x64_scalar_float_xmm_xmm(function.code, bits, operation, 0, 1);
                x64_movq_r64_xmm(function.code, 0, 0);
            }
            native_store(function, result, 0); return;
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
            if condition == 16 { function.code.ok = false; return; }
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
                    function.code.ok = false; return;
                }
                x64_mov_r64_imm64(function.code, 10, cast(u64, element.size));
                x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 15);
                x64_emit_u8(function.code, 175); x64_emit_u8(function.code, 218);
                if d_instruction_text_is(context, instruction, "+") { x64_add_r64_r64(function.code, 0, 11); }
                else { x64_binary_r64_r64(function.code, 41, 0, 11); }
                native_store(function, result, 0); return;
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
            } else { function.code.ok = false; return; }
            if checked {
                usize no_overflow = 3; if signed_value { no_overflow = 1; }
                native_require(function.code, no_overflow);
                native_check_result(context, function, type_id);
            }
        }
        native_store(function, result, 0); return;
    }
    if opcode == ir_op_call() {
        if native_compiler_intrinsic(
            context, function, instruction, result
        ) { return; }
        if native_saturating_call(context, function, instruction) { return; }
        if native_runtime_call(context, function, instruction) { return; }
        if c_builtin_is(context, instruction, "text.byte_length", "system.text.byte_length") {
            usize value = d_operand_value(context, instruction, 0);
            x64_mov_r64_memory(function.code, 0, 4, native_slot(function, value) + 8);
            native_store(function, result, 0); return;
        }
        bool hidden = result != 0 && native_indirect_aggregate(context, type_id);
        usize kind = read_record_field(context.instruction_detail, instruction, 0);
        usize target = read_record_field(context.instruction_detail, instruction, 1);
        usize count = d_operand_count(context, instruction);
        if kind != 3 || target >= context.symbols.length || count > 30 {
            function.code.ok = false; return;
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
        return;
    }
    if opcode == ir_op_scope_register() {
        usize ordinal = native_scope_ordinal(context, instruction);
        if ordinal >= function.scope_count { function.code.ok = false; return; }
        x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
        x64_mov_memory_r64(function.code, 4, 1024 + ordinal * 8, 0);
        return;
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
        return;
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
        x64_add_rsp(function.code, function.frame_size); x64_ret(function.code); return;
    }
    function.code.ok = false;
}
