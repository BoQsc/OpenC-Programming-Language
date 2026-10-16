import system.io;
import system.memory;
import system.text;

unsafe bool native_try_integer_immediate(
    ref IrContext context, ref NativeFunction function,
    usize constant_instruction, usize binary_instruction,
    usize following_instruction, ptr byte use_counts,
    ref usize instruction_count
) {
    if read_record_field(context.instruction_data, constant_instruction, 2) !=
            ir_op_const_integer() ||
        read_record_field(context.instruction_detail, constant_instruction, 0) != 4 ||
        read_record_field(context.instruction_data, binary_instruction, 2) !=
            ir_op_binary() ||
        d_operand_count(context, binary_instruction) != 2 {
        return false;
    }
    usize constant = read_record_field(
        context.instruction_data, constant_instruction, 1);
    if constant < function.first_value ||
        constant > context.next_value ||
        d_operand_value(context, binary_instruction, 1) != constant ||
        read_usize(use_counts,
            (constant - function.first_value) * size_of(usize)) != 1 {
        return false;
    }
    usize immediate = read_record_field(
        context.instruction_detail, constant_instruction, 1);
    if immediate > 127 { return false; }
    usize type_id = read_record_field(
        context.instruction_data, binary_instruction, 3);
    if type_id >= context.types.length { return false; }
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind != 2 && kind != 3 { return false; }
    usize left = d_operand_value(context, binary_instruction, 0);
    if left < function.first_value ||
        left > context.next_value ||
        native_value_read(function, function.value_types, left) != type_id {
        return false;
    }
    usize operation = 8;
    if d_instruction_text_is(context, binary_instruction, "+") {
        operation = 0;
    } else if d_instruction_text_is(context, binary_instruction, "-") {
        operation = 5;
    }
    if operation == 8 { return false; }
    usize result = read_record_field(
        context.instruction_data, binary_instruction, 1);
    NativeLayout layout = native_layout(context, type_id, 0);
    instruction_count = 2;
    if result == 0 || !layout.valid { function.code.ok = false; return true; }
    usize store_destination = result;
    if following_instruction < context.instructions.length &&
        read_record_field(context.instruction_data, following_instruction, 2) ==
            ir_op_store() &&
        d_operand_count(context, following_instruction) == 2 &&
        d_operand_value(context, following_instruction, 1) == result &&
        result >= function.first_value && result <= context.next_value &&
        read_usize(use_counts,
            (result - function.first_value) * size_of(usize)) == 1 &&
        !d_operand_immediate_is(context, following_instruction, 0, "deref") &&
        !d_operand_immediate_is(context, following_instruction, 0, "bind") {
        usize destination = d_operand_value(context, following_instruction, 0);
        if destination >= function.first_value &&
            destination <= context.next_value &&
            native_value_read(function, function.value_types, destination) == type_id &&
            native_value_read(function, function.address_values, destination) == 0 {
            store_destination = destination;
            instruction_count = 3;
        }
    }
    native_load(function, left, 0);
    x64_alu_r64_imm8(function.code, operation, 0, immediate);
    usize no_overflow = 3;
    if kind == 2 { no_overflow = 1; }
    native_require(function.code, no_overflow);
    native_check_result(context, function, type_id);
    native_store(function, store_destination, 0);
    return true;
}

unsafe void native_emit_function(
    ref IrContext context, ref DBuffer output, ref BuildTimings timings,
    usize symbol, usize entry_module, usize first
) {
    if !output.ok { return; }
    // These are compiler-engineering budgets, not language limits. They stop a
    // malformed layout or capacity estimate before it can reserve gigabytes.
    usize maximum_instructions = 65536;
    usize maximum_values = 1048576;
    usize maximum_frame_bytes = 16777216;
    usize maximum_code_bytes = 67108864;
    usize maximum_constant_bytes = 33554432;
    if context.instructions.length > maximum_instructions ||
        context.next_value > maximum_values ||
        context.source.length > 16777088 {
        io.error("error[OPENC-NATIVE-BUDGET]: function ");
        io.error(project_slice(context.source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)));
        io.error(" exceeds native IR budget; instructions=");
        io.print(context.instructions.length); io.error(" values=");
        io.print(context.next_value); io.error(" source-bytes=");
        io.print(context.source.length); io.error("\n");
        output.ok = false;
        return;
    }
    // Lowering publishes monotonically increasing function-local SSA values.
    // Its caller captures the first ID before lowering. Build types, slots,
    // operand-use counts and capacity facts together in creation order; none
    // depends on final block order. The old reference-origin pass wrote into
    // value_slots and was immediately overwritten before any reader.
    usize value_capacity = context.next_value - first + 1;
    ptr byte value_types = memory.alloc(value_capacity * size_of(usize));
    ptr byte value_slots = memory.alloc(value_capacity * size_of(usize));
    ptr byte references = memory.alloc(value_capacity * size_of(usize));
    usize frame_cursor = 1536;
    usize next_result = first;
    usize scope_count = 0;
    usize maximum_layout_size = 8;
    bool function_has_call = false;
    bool function_has_cast = false;
    bool function_has_small_integer = false;
    usize argument_snapshot_calls = 0;
    usize direct_constant_capacity = 256;
    usize index = 0;
    while index < context.instructions.length {
        NativeLayout instruction_layout = native_layout(context,
            read_record_field(context.instruction_data, index, 3), 0);
        if instruction_layout.valid && instruction_layout.size > maximum_layout_size {
            maximum_layout_size = instruction_layout.size;
        }
        usize result = read_record_field(context.instruction_data, index, 1);
        if result != 0 {
            // Fail before indexing scratch if a future lowerer violates the
            // contiguous-ID handoff, rather than silently changing frame order.
            if result != next_result || result >= context.next_value {
                memory.free(references); memory.free(value_slots);
                memory.free(value_types); output.ok = false; return;
            }
            usize value_size = 8;
            usize value_alignment = 8;
            if instruction_layout.valid {
                if instruction_layout.size > value_size { value_size = instruction_layout.size; }
                if instruction_layout.alignment > value_alignment {
                    value_alignment = instruction_layout.alignment;
                }
            }
            frame_cursor = x64_align_up(frame_cursor, value_alignment);
            write_usize(value_slots, (result - first) * size_of(usize), frame_cursor);
            write_usize(value_types, (result - first) * size_of(usize),
                read_record_field(context.instruction_data, index, 3));
            frame_cursor = frame_cursor + value_size;
            next_result = next_result + 1;
        }
        usize operand_first = read_record_field(context.instruction_detail, index, 3);
        usize operand_count = d_operand_count(context, index);
        usize operand = 0;
        while operand < operand_count {
            usize value = read_record_field(context.operand_data, operand_first + operand, 0);
            if value >= first && value - first < value_capacity {
                usize offset = (value - first) * size_of(usize);
                write_usize(references, offset, read_usize(references, offset) + 1);
            }
            operand = operand + 1;
        }
        usize opcode = read_record_field(
            context.instruction_data, index, 2
        );
        if opcode == ir_op_scope_register() {
            scope_count = scope_count + 1;
        }
        if opcode == ir_op_call() {
            function_has_call = true;
            if c_builtin_is(context, index,
                "process.argument", "system.process.argument") ||
                c_builtin_is(context, index,
                "process.argument_count", "system.process.argument_count") {
                argument_snapshot_calls = argument_snapshot_calls + 1;
            }
        }
        if opcode == ir_op_cast() { function_has_cast = true; }
        if opcode == ir_op_const_integer() &&
            read_record_field(context.instruction_detail, index, 0) == 4 &&
            read_record_field(context.instruction_detail, index, 1) <= 127 {
            function_has_small_integer = true;
        }
        if opcode == ir_op_const_text() {
            direct_constant_capacity = direct_constant_capacity +
                read_record_field(context.instruction_detail, index, 2) + 1;
        }
        index = index + 1;
    }
    if next_result != context.next_value {
        memory.free(references); memory.free(value_slots);
        memory.free(value_types); output.ok = false; return;
    }
    // Preserve the historical one-past-last sentinel slot and exact frame.
    frame_cursor = x64_align_up(frame_cursor, 8);
    write_usize(value_slots, (context.next_value - first) * size_of(usize), frame_cursor);
    frame_cursor = frame_cursor + 8;
    ptr byte order = d_instruction_order(context);
    usize frame = x64_align_up(frame_cursor, 16) + 8;
    usize code_capacity = context.instructions.length * 1024 +
        maximum_layout_size * 32 + 65536;
    usize relocation_capacity = context.instructions.length * 32 + 32;
    // The lazy argument snapshot includes allocation checks, CAS publication,
    // and loser cleanup. Keep its larger intrinsic expansion in the bounds;
    // the initial allocations below still grow only as actual emission needs.
    code_capacity = code_capacity + argument_snapshot_calls * 2048;
    relocation_capacity = relocation_capacity + argument_snapshot_calls * 128;
    usize constant_capacity = context.source.length * 2 + 256;
    constant_capacity = constant_capacity + argument_snapshot_calls * 512;
    // A call-free function cannot enter a runtime intrinsic emitter.  Its
    // constant section contains only decoded source literals, whose encoded
    // IR spans are a conservative exact bound, plus one terminator each.
    if !function_has_call && scope_count == 0 {
        code_capacity = context.instructions.length * 256 +
            maximum_layout_size * 32 + 4096;
        // Non-cast scalar and composite instructions contribute no more than
        // four fault relocations. A checked float-to-integer cast can
        // contribute six, so retain the wider bound for any function that
        // contains a cast. Reserve one final slot for malformed fallthrough.
        relocation_capacity = context.instructions.length * 4 + 1;
        if function_has_cast {
            relocation_capacity = context.instructions.length * 6 + 1;
        }
    }
    if !function_has_call {
        constant_capacity = direct_constant_capacity;
    }
    usize initial_code_capacity = context.instructions.length * 64 + 512;
    if initial_code_capacity > code_capacity {
        initial_code_capacity = code_capacity;
    }
    usize initial_relocation_capacity = context.instructions.length + 8;
    if initial_relocation_capacity > relocation_capacity {
        initial_relocation_capacity = relocation_capacity;
    }
    if frame > maximum_frame_bytes || code_capacity > maximum_code_bytes ||
        constant_capacity > maximum_constant_bytes {
        io.error("error[OPENC-NATIVE-BUDGET]: function ");
        io.error(project_slice(context.source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)));
        io.error(" exceeds native allocation budget; frame-bytes=");
        io.print(frame); io.error(" code-capacity="); io.print(code_capacity);
        io.error(" constant-capacity="); io.print(constant_capacity);
        io.error("\n");
        memory.free(value_slots); memory.free(order);
        memory.free(references); memory.free(value_types);
        output.ok = false;
        return;
    }
    NativeFunction function = NativeFunction{
        code = x64_code_create_bounded(
            initial_code_capacity, code_capacity,
            initial_relocation_capacity, relocation_capacity
        ),
        constants = d_buffer_create(constant_capacity),
        first_value = first, frame_size = frame,
        indirect_return = native_indirect_aggregate(context,
            read_record_field(context.symbol_data, symbol, 4)),
        value_types = ir_pointer_alias(value_types),
        value_origins = memory.alloc(value_capacity * size_of(usize)),
        address_values = memory.alloc(value_capacity * size_of(usize)),
        value_slots = ir_pointer_alias(value_slots),
        blocks = memory.alloc((context.blocks.length + 1) * size_of(usize)),
        branch_patches = memory.alloc((context.instructions.length * 2 + 1) * record_stride()),
        short_patches = memory.alloc((context.next_value - first + 1) * size_of(usize)),
        branch_count = 0,
        scope_count = scope_count
    };
    index = 0;
    while index < value_capacity {
        write_usize(function.value_origins, index * size_of(usize), 0);
        write_usize(function.address_values, index * size_of(usize), 0);
        index = index + 1;
    }
    native_allocate_stack(function.code, frame);
    usize prolog = function.code.bytes.length;
    x64_mov_memory_r64(function.code, 4, frame + 8, 1);
    x64_mov_memory_r64(function.code, 4, frame + 16, 2);
    x64_mov_memory_r64(function.code, 4, frame + 24, 8);
    x64_mov_memory_r64(function.code, 4, frame + 32, 9);
    index = 0;
    while index < ir_parameter_count(context, context.function_symbol) {
        usize position = index; if function.indirect_return { position = position + 1; }
        usize parameter = ir_parameter_at(context, context.function_symbol, index);
        if position < 4 && parameter < context.symbols.length && native_float_type(context,
            read_record_field(context.symbol_data, parameter, 4)) {
            x64_movq_r64_xmm(function.code, 0, position);
            x64_mov_memory_r64(function.code, 4, frame + 8 + position * 8, 0);
        }
        index = index + 1;
    }
    if function.indirect_return { x64_mov_memory_r64(function.code, 4, 240, 1); }
    if scope_count > 32 { function.code.ok = false; }
    index = 0;
    while index < scope_count && function.code.ok {
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        x64_mov_memory_r64(function.code, 4, 1024 + index * 8, 0);
        index = index + 1;
    }
    usize block = 0;
    usize failed_instruction = context.instructions.length;
    index = 0;
    while block < context.blocks.length && function.code.ok {
        write_usize(function.blocks, block * size_of(usize), function.code.bytes.length);
        while index < context.instructions.length && read_record_field(
            context.instruction_data, read_usize(order, index * size_of(usize)), 0
        ) == block && function.code.ok {
            usize lowering_instruction = read_usize(order, index * size_of(usize));
            bool immediate_pair = false;
            usize fused_count = 0;
            if function_has_small_integer &&
                index + 1 < context.instructions.length {
                usize next_instruction = read_usize(
                    order, (index + 1) * size_of(usize));
                if read_record_field(context.instruction_data,
                        next_instruction, 0) == block {
                    usize following_instruction = context.instructions.length;
                    if index + 2 < context.instructions.length {
                        usize candidate = read_usize(
                            order, (index + 2) * size_of(usize));
                        if read_record_field(context.instruction_data,
                                candidate, 0) == block {
                            following_instruction = candidate;
                        }
                    }
                    immediate_pair = native_try_integer_immediate(
                        context, function, lowering_instruction,
                        next_instruction, following_instruction,
                        references, fused_count);
                    if immediate_pair {
                        if !function.code.ok {
                            failed_instruction = next_instruction;
                        }
                        index = index + fused_count;
                    }
                }
            }
            if !immediate_pair {
                native_scalar_instruction(context, function, lowering_instruction);
                if !function.code.ok { failed_instruction = lowering_instruction; }
                index = index + 1;
            }
        }
        block = block + 1;
    }
    // A malformed fallthrough must not enter the next function.
    x64_call_symbol(function.code, cast(usize, 4294967295), 0);
    index = 0;
    while index < function.branch_count && function.code.ok {
        usize offset = read_record_field(function.branch_patches, index, 0);
        usize target = read_record_field(function.branch_patches, index, 1);
        if target >= context.blocks.length { function.code.ok = false; }
        else {
            usize destination = read_usize(function.blocks, target * size_of(usize));
            i64 delta = cast(i64, destination) - cast(i64, offset + 4);
            u32 encoded = 0;
            if delta < 0 { encoded = cast(u32, cast(u64, 4294967296) - cast(u64, 0 - delta)); }
            else { encoded = cast(u32, delta); }
            x64_patch_u32(function.code, offset, encoded);
        }
        index = index + 1;
    }
    usize unwind_size = x64_unwind_allocation_size(prolog, frame);
    // This compact native stream serializes relocation offset and symbol,
    // not kind or width. Reject an unsupported kind before it can be patched
    // as a relative32 and turn a function pointer into an invalid address.
    index = 0;
    while index < function.code.relocations.length {
        if read_record_field(function.code.relocation_data, index, 1) !=
                x64_relocation_relative32() ||
            read_record_field(function.code.relocation_data, index, 4) != 4 {
            function.code.ok = false;
        }
        index = index + 1;
    }
    if function.code.ok && unwind_size != 0 && function.constants.ok {
        pe32_put_u32(output, symbol);
        usize entry = 0; if c_function_is_entry(context, symbol, entry_module) { entry = 1; }
        pe32_put_u32(output, entry);
        pe32_put_u32(output, function.code.bytes.length);
        pe32_put_u32(output, unwind_size);
        pe32_put_u32(output, function.code.relocations.length);
        pe32_put_u32(output, function.constants.length);
        x64_copy_bytes(output, function.code.bytes);
        if !x64_put_unwind_allocation(output, prolog, frame) {
            output.ok = false;
        }
        index = 0;
        while index < function.code.relocations.length {
            pe32_put_u32(output, read_record_field(function.code.relocation_data, index, 0));
            pe32_put_u32(output, read_record_field(function.code.relocation_data, index, 2));
            index = index + 1;
        }
        x64_copy_bytes(output, function.constants);
    } else {
        io.error("error[OPENC-NATIVE-UNSUPPORTED]: function ");
        io.error(project_slice(context.source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)));
        io.error(" requires native lowering not yet implemented");
        if failed_instruction < context.instructions.length {
            io.error(" at IR instruction "); io.print(failed_instruction);
            io.error(" opcode "); io.print(read_record_field(
                context.instruction_data, failed_instruction, 2));
        }
        io.error(" code-bytes "); io.print(function.code.bytes.length);
        io.error("/"); io.print(function.code.bytes.capacity);
        io.error(" relocations "); io.print(function.code.relocations.length);
        io.error("/"); io.print(function.code.relocations.capacity);
        io.error(" constants "); io.print(function.constants.length);
        io.error("/"); io.print(function.constants.capacity);
        io.error("\n");
        output.ok = false;
    }
    timings.native_code_reserved_bytes =
        timings.native_code_reserved_bytes + function.code.bytes.capacity;
    timings.native_code_used_bytes =
        timings.native_code_used_bytes + function.code.bytes.length;
    timings.native_relocation_reserved_records =
        timings.native_relocation_reserved_records +
        function.code.relocations.capacity;
    timings.native_relocation_used_records =
        timings.native_relocation_used_records + function.code.relocations.length;
    timings.native_constant_reserved_bytes =
        timings.native_constant_reserved_bytes + constant_capacity;
    timings.native_constant_used_bytes =
        timings.native_constant_used_bytes + function.constants.length;
    memory.free(order); memory.free(references);
    memory.free(function.branch_patches); memory.free(function.blocks);
    memory.free(function.short_patches);
    memory.free(value_types); x64_code_destroy(function.code);
    memory.free(function.value_origins);
    memory.free(function.address_values);
    memory.free(value_slots);
    d_buffer_destroy(function.constants);
}

unsafe bool native_decode_text(ref DBuffer output, text literal) {
    if literal.length < 2 || byte_at_or_zero(literal, 0) != 34 ||
        byte_at_or_zero(literal, literal.length - 1) != 34 { return false; }
    usize index = 1;
    while index + 1 < literal.length {
        u8 octet = byte_at_or_zero(literal, index); index = index + 1;
        if octet != 92 { d_put_byte(output, octet); continue; }
        octet = byte_at_or_zero(literal, index); index = index + 1;
        if octet == 117 {
            if byte_at_or_zero(literal, index) != 123 { return false; }
            index = index + 1;
            usize scalar = 0; usize digits = 0;
            while index + 1 < literal.length && byte_at_or_zero(literal, index) != 125 {
                usize digit = lsp_hex_value(byte_at_or_zero(literal, index));
                if digit >= 16 || digits >= 6 { return false; }
                scalar = scalar * 16 + digit; digits = digits + 1; index = index + 1;
            }
            if digits == 0 || byte_at_or_zero(literal, index) != 125 ||
                (scalar >= 55296 && scalar <= 57343) { return false; }
            if !lsp_put_utf8(output, scalar) { return false; }
            index = index + 1;
        } else {
            if octet == 110 { octet = 10; }
            else if octet == 114 { octet = 13; }
            else if octet == 116 { octet = 9; }
            else if octet == 48 { octet = 0; }
            else if octet != 34 && octet != 92 { return false; }
            d_put_byte(output, octet);
        }
    }
    return output.ok;
}
