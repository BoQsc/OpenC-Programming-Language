import system.io;
import system.memory;
import system.text;

unsafe void native_emit_function(
    ref IrContext context, ref DBuffer output, usize symbol, usize entry_module
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
    usize first = context.next_value;
    usize index = 0;
    while index < context.instructions.length {
        usize value = read_record_field(context.instruction_data, index, 1);
        if value != 0 && value < first { first = value; }
        index = index + 1;
    }
    usize scope_count = 0;
    usize maximum_layout_size = 8;
    index = 0;
    while index < context.instructions.length {
        NativeLayout instruction_layout = native_layout(context,
            read_record_field(context.instruction_data, index, 3), 0);
        if instruction_layout.valid && instruction_layout.size > maximum_layout_size {
            maximum_layout_size = instruction_layout.size;
        }
        if read_record_field(context.instruction_data, index, 2) == ir_op_scope_register() {
            scope_count = scope_count + 1;
        }
        index = index + 1;
    }
    // SSA numbers are project-wide, but all function analyses are local. Keep
    // storage proportional to this function instead of reallocating and
    // clearing every value produced by all preceding functions.
    usize value_capacity = context.next_value - first + 1;
    ptr byte value_types = memory.alloc(value_capacity * size_of(usize));
    ptr byte references = memory.alloc(value_capacity * size_of(usize));
    ptr byte order = d_instruction_order(context);
    native_analyze_values(context, first, value_types, references, order);
    ptr byte value_slots = memory.alloc(value_capacity * size_of(usize));
    usize frame_cursor = 1536;
    index = first;
    while index <= context.next_value {
        NativeLayout value_layout = native_layout(context,
            read_usize(value_types,
                (index - first) * size_of(usize)), 0);
        usize value_size = 8;
        usize value_alignment = 8;
        if value_layout.valid {
            if value_layout.size > value_size { value_size = value_layout.size; }
            if value_layout.alignment > value_alignment {
                value_alignment = value_layout.alignment;
            }
        }
        frame_cursor = x64_align_up(frame_cursor, value_alignment);
        write_usize(value_slots,
            (index - first) * size_of(usize), frame_cursor);
        frame_cursor = frame_cursor + value_size;
        index = index + 1;
    }
    usize frame = x64_align_up(frame_cursor, 16) + 8;
    usize code_capacity = context.instructions.length * 1024 +
        maximum_layout_size * 32 + 65536;
    usize constant_capacity = context.source.length * 2 + 256;
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
        code = x64_code_create(code_capacity,
            context.instructions.length * 32 + 32),
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
            native_scalar_instruction(context, function, lowering_instruction);
            if !function.code.ok { failed_instruction = lowering_instruction; }
            index = index + 1;
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
    X64UnwindBuilder unwind = x64_unwind_create(1);
    x64_unwind_add_allocation(unwind, prolog, frame);
    DBuffer unwind_bytes = x64_unwind_encode(unwind);
    if function.code.ok && unwind_bytes.ok && function.constants.ok {
        pe32_put_u32(output, symbol);
        usize entry = 0; if c_function_is_entry(context, symbol, entry_module) { entry = 1; }
        pe32_put_u32(output, entry);
        pe32_put_u32(output, function.code.bytes.length);
        pe32_put_u32(output, unwind_bytes.length);
        pe32_put_u32(output, function.code.relocations.length);
        pe32_put_u32(output, function.constants.length);
        x64_copy_bytes(output, function.code.bytes);
        x64_copy_bytes(output, unwind_bytes);
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
    d_buffer_destroy(unwind_bytes); x64_unwind_destroy(unwind);
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
