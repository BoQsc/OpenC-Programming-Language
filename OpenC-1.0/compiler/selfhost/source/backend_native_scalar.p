import system.io;
import system.memory;
import system.text;

struct NativeFunction {
    X64Code code;
    DBuffer constants;
    usize first_value;
    usize frame_size;
    bool indirect_return;
    ptr byte value_types;
    ptr byte value_origins;
    ptr byte address_values;
    ptr byte value_slots;
    ptr byte blocks;
    ptr byte branch_patches;
    ptr byte short_patches;
    usize branch_count;
    usize scope_count;
}

struct NativeCompilerConstant {
    bool found;
    usize value;
}

unsafe usize native_slot(ref NativeFunction function, usize value) {
    if value < function.first_value { function.code.ok = false; return 128; }
    return read_usize(function.value_slots,
        (value - function.first_value) * size_of(usize));
}

unsafe usize native_value_read(ref NativeFunction function,
    ptr byte values, usize value) {
    if value < function.first_value { function.code.ok = false; return 0; }
    return read_usize(values,
        (value - function.first_value) * size_of(usize));
}

unsafe void native_value_write(ref NativeFunction function,
    ptr byte values, usize value, usize stored) {
    if value < function.first_value { function.code.ok = false; return; }
    write_usize(values,
        (value - function.first_value) * size_of(usize), stored);
}

unsafe bool native_indirect_aggregate(ref IrContext context, usize type_id) {
    if native_scalar_type(context, type_id) { return false; }
    NativeLayout layout = native_layout(context, type_id, 0);
    return layout.size != 1 && layout.size != 2 && layout.size != 4 && layout.size != 8;
}

struct NativeLayout {
    usize size;
    usize alignment;
    bool valid;
}

unsafe NativeLayout native_layout_uncached(
    ref IrContext context, usize type_id, usize depth
) {
    NativeLayout invalid = NativeLayout{ size = 0, alignment = 1, valid = false };
    if depth > 32 || type_id >= context.types.length { return invalid; }
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind == 1 { return NativeLayout{ size = 0, alignment = 1, valid = true }; }
    if kind == 7 { return NativeLayout{ size = 16, alignment = 8, valid = true }; }
    if kind == 8 { return NativeLayout{ size = 24, alignment = 8, valid = true }; }
    if kind == 11 { return NativeLayout{ size = 16, alignment = 8, valid = true }; }
    if kind == 14 || kind == 15 {
        NativeLayout element = native_layout(context, read_record_field(context.type_data, type_id, 1), depth + 1);
        if !element.valid { return invalid; }
        if kind == 14 { element.size = x64_align_up(1, element.alignment) + element.size; }
        else { element.size = x64_align_up(element.size, 8); element.alignment = 8; }
        return element;
    }
    if kind == 10 {
        NativeLayout element = native_layout(context, read_record_field(context.type_data, type_id, 1), depth + 1);
        if !element.valid { return invalid; }
        element.size = element.size * read_record_field(context.type_data, type_id, 2);
        return element;
    }
    if native_scalar_type(context, type_id) {
        usize width = native_scalar_width(context, type_id);
        return NativeLayout{ size = width, alignment = width, valid = true };
    }
    if kind != 9 { return invalid; }
    usize symbol = c_named_type_symbol(context, type_id);
    if symbol < context.symbols.length && read_record_field(context.symbol_data, symbol, 0) == resolution_symbol_enum() {
        return NativeLayout{ size = 4, alignment = 4, valid = true };
    }
    if symbol >= context.symbols.length || (read_record_field(context.symbol_data,
        symbol, 0) != resolution_symbol_struct() && read_record_field(
        context.symbol_data, symbol, 0) != resolution_symbol_resource()) { return invalid; }
    usize field = ir_first_aggregate_field(context, symbol);
    NativeLayout result = NativeLayout{ size = 0, alignment = 1, valid = true };
    while field < context.symbols.length {
        NativeLayout member = native_layout(context,
            read_record_field(context.symbol_data, field, 4), depth + 1);
        if !member.valid { return invalid; }
        result.size = x64_align_up(result.size, member.alignment) + member.size;
        if member.alignment > result.alignment { result.alignment = member.alignment; }
        field = ir_next_aggregate_field(context, field);
    }
    result.size = x64_align_up(result.size, result.alignment);
    if result.size == 0 { return invalid; }
    return result;
}

unsafe NativeLayout native_layout(
    ref IrContext context, usize type_id, usize depth
) {
    NativeLayout invalid = NativeLayout{
        size = 0, alignment = 1, valid = false
    };
    if type_id >= context.types.length ||
        context.native_layout_state_cache == null {
        return native_layout_uncached(context, type_id, depth);
    }
    usize offset = type_id * size_of(usize);
    usize state = read_usize(context.native_layout_state_cache, offset);
    if state == 2 {
        return NativeLayout{
            size = read_usize(context.native_layout_size_cache, offset),
            alignment = read_usize(
                context.native_layout_alignment_cache, offset),
            valid = true
        };
    }
    if state == 1 || state == 3 { return invalid; }
    write_usize(context.native_layout_state_cache, offset, 1);
    NativeLayout result = native_layout_uncached(context, type_id, depth);
    write_usize(context.native_layout_size_cache, offset, result.size);
    write_usize(
        context.native_layout_alignment_cache, offset, result.alignment);
    usize completed_state = 3;
    if result.valid { completed_state = 2; }
    write_usize(
        context.native_layout_state_cache, offset, completed_state);
    return result;
}

unsafe usize native_field_offset(ref IrContext context, usize type_id, text name) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind == 7 || kind == 11 {
        if name == "data" { return 0; }
        if name == "length" { return 8; }
        return cast(usize, 4294967295);
    }
    if kind == 14 {
        if name == "present" { return 0; }
        NativeLayout element = native_layout(context, read_record_field(context.type_data, type_id, 1), 0);
        usize offset = x64_align_up(1, element.alignment);
        if name == "value" { return offset; }
        if starts_with_ascii(name, 0, "value.") {
            usize nested = native_field_offset(context, read_record_field(context.type_data, type_id, 1),
                project_slice(name, 6, name.length - 6));
            if nested != cast(usize, 4294967295) { return offset + nested; }
        }
        return cast(usize, 4294967295);
    }
    if kind == 8 {
        if name == "code" || name == "ok" { return 0; }
        if name == "message" { return 8; }
        return cast(usize, 4294967295);
    }
    usize segment = 0;
    while segment < name.length && byte_at_or_zero(name, segment) != 46 {
        segment = segment + 1;
    }
    usize symbol = c_named_type_symbol(context, type_id);
    usize field = ir_first_aggregate_field(context, symbol);
    usize field_offset = 0;
    while field < context.symbols.length {
        NativeLayout member = native_layout(context,
            read_record_field(context.symbol_data, field, 4), 0);
        if !member.valid { return cast(usize, 4294967295); }
        field_offset = x64_align_up(field_offset, member.alignment);
        text field_source = d_symbol_source(context, field);
        if project_slice(field_source, read_record_field(context.symbol_data, field, 2),
            read_record_field(context.symbol_data, field, 3)) == project_slice(name, 0, segment) {
            if segment == name.length { return field_offset; }
            usize nested = native_field_offset(context,
                read_record_field(context.symbol_data, field, 4),
                project_slice(name, segment + 1, name.length - segment - 1));
            if nested == cast(usize, 4294967295) { return nested; }
            return field_offset + nested;
        }
        field_offset = field_offset + member.size;
        field = ir_next_aggregate_field(context, field);
    }
    return cast(usize, 4294967295);
}

unsafe void native_value_address(ref IrContext context, ref NativeFunction function,
    usize value, usize reg) {
    usize type_id = native_value_read(function, function.value_types, value);
    if c_type_is_pointer_like(context, type_id) || native_value_read(
        function, function.address_values, value
    ) != 0 { native_load(function, value, reg); }
    else { native_address(function, value, reg); }
}

unsafe void native_sequence_length(ref IrContext context, ref NativeFunction function,
    usize value, usize type_id, usize reg) {
    if read_record_field(context.type_data, type_id, 0) == 10 {
        x64_mov_r64_imm64(function.code, reg,
            cast(u64, read_record_field(context.type_data, type_id, 2)));
    } else {
        native_value_address(context, function, value, reg);
        x64_mov_r64_memory(function.code, reg, reg, 8);
    }
}

unsafe void native_sequence_address(ref IrContext context, ref NativeFunction function,
    usize value, usize type_id, usize reg) {
    native_value_address(context, function, value, reg);
    if read_record_field(context.type_data, type_id, 0) != 10 {
        x64_mov_r64_memory(function.code, reg, reg, 0);
    }
}

// Exact-sized copy from R11 to R10. x64 permits unaligned integer moves, so
// transfer full words before the final byte tail instead of emitting eight
// load/store pairs for every eight-byte aggregate chunk.
unsafe void native_copy_value(ref NativeFunction function, usize size) {
    usize index = 0;
    while index + 8 <= size {
        x64_mov_r64_memory(function.code, 0, 11, index);
        x64_mov_memory_r64(function.code, 10, index, 0);
        index = index + 8;
    }
    while index < size {
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182);
        x64_emit_memory_modrm(function.code, 0, 11, index);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 136);
        x64_emit_memory_modrm(function.code, 0, 10, index);
        index = index + 1;
    }
}

unsafe void native_analyze_values(ref IrContext context, usize first,
    ptr byte value_types, ptr byte reference_storage,
    ptr byte instruction_order) {
    usize ordered = 0;
    while ordered < context.instructions.length {
        usize instruction = read_usize(
            instruction_order, ordered * size_of(usize)
        );
        usize result = read_record_field(
            context.instruction_data, instruction, 1
        );
        usize opcode = read_record_field(
            context.instruction_data, instruction, 2
        );
        if result != 0 {
            write_usize(value_types, (result - first) * size_of(usize),
                read_record_field(context.instruction_data, instruction, 3));
            write_usize(reference_storage,
                (result - first) * size_of(usize), 0);
        }
        if opcode == ir_op_object_construct() && result != 0 {
            write_usize(reference_storage,
                (result - first) * size_of(usize),
                d_operand_value(context, instruction, 0) + 1);
        } else if opcode == ir_op_load() && result != 0 {
            usize source = d_operand_value(context, instruction, 0);
            write_usize(reference_storage,
                (result - first) * size_of(usize),
                read_usize(reference_storage,
                    (source - first) * size_of(usize)));
        } else if opcode == ir_op_store() {
            usize destination = d_operand_value(context, instruction, 0);
            usize source = d_operand_value(context, instruction, 1);
            write_usize(reference_storage,
                (destination - first) * size_of(usize),
                read_usize(reference_storage,
                    (source - first) * size_of(usize)));
        }
        ordered = ordered + 1;
    }
}

unsafe void native_compiler_record_address(ref IrContext context,
    ref NativeFunction function, usize instruction) {
    native_load(function, d_operand_value(context, instruction, 0), 11);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 40));
    x64_emit_rex(function.code, true, 0, 0, 10);
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 175);
    x64_emit_register_modrm(function.code, 0, 10);
    x64_add_r64_r64(function.code, 11, 0);
    native_load(function, d_operand_value(context, instruction, 2), 0);
    x64_shift_r64_imm8(function.code, 4, 0, 3);
    x64_add_r64_r64(function.code, 11, 0);
}

unsafe void native_compiler_text_match(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result,
    bool exact_length) {
    usize expected_operand = 2;
    if exact_length { expected_operand = 3; }
    usize source = d_operand_value(context, instruction, 0);
    usize expected = d_operand_value(context, instruction, expected_operand);
    native_load(function, source, 10);
    native_load(function, expected, 11);
    x64_mov_r64_memory(function.code, 9, 4,
        native_slot(function, expected) + 8);
    usize bad_length = 0;
    if exact_length {
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_cmp_r64_r64(function.code, 0, 9);
        bad_length = native_skip(function.code, 5);
    }
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_r64_memory(function.code, 8, 4,
        native_slot(function, source) + 8);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_start = native_skip(function.code, 7);
    x64_binary_r64_r64(function.code, 41, 8, 0);
    x64_cmp_r64_r64(function.code, 9, 8);
    usize bad_count = native_skip(function.code, 7);
    x64_add_r64_r64(function.code, 10, 0);

    usize word_loop = function.code.bytes.length;
    x64_alu_r64_imm8(function.code, 7, 9, 8);
    usize byte_tail = native_skip(function.code, 2);
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_mov_r64_memory(function.code, 8, 11, 0);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_word = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 10, 8);
    x64_add_r64_imm8(function.code, 11, 8);
    x64_alu_r64_imm8(function.code, 5, 9, 8);
    usize repeat_words = native_jump(function.code);
    x64_patch_u32(function.code, repeat_words,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_words + 4 - word_loop)));
    native_skip_end(function.code, byte_tail);

    usize byte_loop = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201);
    usize equal = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 2);
    x64_emit_u8(function.code, 69); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_byte = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 10, 1);
    x64_add_r64_imm8(function.code, 11, 1);
    x64_alu_r64_imm8(function.code, 5, 9, 1);
    usize repeat_bytes = native_jump(function.code);
    x64_patch_u32(function.code, repeat_bytes,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_bytes + 4 - byte_loop)));
    native_skip_end(function.code, equal);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    usize completed = native_jump(function.code);
    if exact_length { native_skip_end(function.code, bad_length); }
    native_skip_end(function.code, bad_start);
    native_skip_end(function.code, bad_count);
    native_skip_end(function.code, bad_word);
    native_skip_end(function.code, bad_byte);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_skip_end(function.code, completed);
    native_store(function, result, 0);
}

unsafe NativeCompilerConstant native_compiler_constant_call(
    ref IrContext context, usize kind, usize symbol
) {
    usize value = 0;
    if kind != 3 || symbol >= context.symbols.length ||
        !d_symbol_module_name_is(
            context, symbol, "openc.selfhost.main"
        ) { return NativeCompilerConstant{ found = false, value = 0 }; }
    text source = d_symbol_source(context, symbol);
    usize cursor = read_record_field(context.symbol_data, symbol, 2) +
        read_record_field(context.symbol_data, symbol, 3);
    if !starts_with_ascii(source, cursor, "() { return ") {
        return NativeCompilerConstant{ found = false, value = 0 };
    }
    cursor = cursor + 12;
    usize digits = 0;
    while cursor < text.byte_length(source) &&
        is_digit(text.byte_at_unchecked(source, cursor)) {
        value = value * 10 + cast(usize,
            text.byte_at_unchecked(source, cursor) - 48);
        cursor = cursor + 1;
        digits = digits + 1;
    }
    return NativeCompilerConstant{
        found = digits != 0 && starts_with_ascii(source, cursor, "; }"),
        value = value
    };
}

unsafe void native_compiler_project_slice(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result) {
    usize source = d_operand_value(context, instruction, 0);
    native_load(function, source, 10);
    x64_mov_r64_memory(function.code, 8, 4,
        native_slot(function, source) + 8);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    native_load(function, d_operand_value(context, instruction, 2), 9);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, native_slot(function, result), 11);
    x64_mov_memory_r64(function.code, 4,
        native_slot(function, result) + 8, 11);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_start = native_skip(function.code, 7);
    x64_binary_r64_r64(function.code, 41, 8, 0);
    x64_cmp_r64_r64(function.code, 9, 8);
    usize bad_length = native_skip(function.code, 7);
    x64_add_r64_r64(function.code, 10, 0);
    x64_mov_memory_r64(function.code, 4,
        native_slot(function, result), 10);
    x64_mov_memory_r64(function.code, 4,
        native_slot(function, result) + 8, 9);
    native_skip_end(function.code, bad_start);
    native_skip_end(function.code, bad_length);
}

unsafe bool native_compiler_span_is(
    ref DCompilerCallSpan call_span,
    text expected
) {
    return call_span.found && span_equals_ascii(
        call_span.source, call_span.start, call_span.length, expected
    );
}

unsafe bool native_compiler_counter_call(
    ref IrContext context,
    ref DCompilerCallSpan call_span,
    ref NativeFunction function, usize instruction, usize result,
    text name, usize offset) {
    if !native_compiler_span_is(call_span, name) { return false; }
    if d_operand_count(context, instruction) != 0 {
        function.code.ok = false; return true;
    }
    native_data_address(function, offset, 11);
    x64_mov_r64_memory(function.code, 0, 11, 0);
    native_store(function, result, 0);
    return true;
}

// Intrinsics for the compiler's packed-record primitives. These four helpers
// dominate frontend traffic; lowering them to direct memory operations avoids
// several native stack-frame calls for every token, syntax, symbol and IR field.
unsafe bool native_compiler_intrinsic(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result) {
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize one = read_record_field(context.instruction_detail, instruction, 1);
    usize two = read_record_field(context.instruction_detail, instruction, 2);
    DCompilerCallSpan call_span = d_compiler_call_span(
        context, kind, one, two
    );
    if native_compiler_span_is(
        call_span, "compiler_live_allocation_bytes"
    ) {
        if d_operand_count(context, instruction) != 0 {
            function.code.ok = false; return true;
        }
        native_data_address(function, 32, 11);
        x64_mov_r64_memory(function.code, 0, 11, 0);
        native_store(function, result, 0); return true;
    }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_file_cache_hits", 56) { return true; }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_file_cache_misses", 64) { return true; }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_path_cache_hits", 72) { return true; }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_path_cache_misses", 80) { return true; }
    if d_operand_count(context, instruction) == 0 {
        NativeCompilerConstant constant = native_compiler_constant_call(
            context, kind, one
        );
        if constant.found {
            x64_mov_r64_imm64(function.code, 0, cast(u64, constant.value));
            native_store(function, result, 0); return true;
        }
    }
    if native_compiler_span_is(call_span, "project_slice") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_compiler_project_slice(
            context, function, instruction, result);
        return true;
    }
    if native_compiler_span_is(call_span, "starts_with_ascii") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_compiler_text_match(
            context, function, instruction, result, false);
        return true;
    }
    if native_compiler_span_is(call_span, "span_equals_ascii") {
        if d_operand_count(context, instruction) != 4 {
            function.code.ok = false; return true;
        }
        native_compiler_text_match(
            context, function, instruction, result, true);
        return true;
    }
    if native_compiler_span_is(call_span, "record_stride") {
        x64_mov_r64_imm64(function.code, 0, cast(u64, 40));
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "read_usize") {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        x64_mov_r64_memory(function.code, 0, 11, 0);
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "write_usize") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if native_compiler_span_is(call_span, "read_record_field") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_compiler_record_address(context, function, instruction);
        x64_mov_r64_memory(function.code, 0, 11, 0);
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "write_record_field") {
        if d_operand_count(context, instruction) != 4 {
            function.code.ok = false; return true;
        }
        native_compiler_record_address(context, function, instruction);
        native_load(function, d_operand_value(context, instruction, 3), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if native_compiler_span_is(call_span, "byte_at_or_zero") {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        usize value = d_operand_value(context, instruction, 0);
        native_load(function, value, 11);
        x64_mov_r64_memory(function.code, 10, 4,
            native_slot(function, value) + 8);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_cmp_r64_r64(function.code, 0, 10);
        usize in_range = native_skip(function.code, 2);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        usize done = native_jump(function.code);
        native_skip_end(function.code, in_range);
        x64_add_r64_r64(function.code, 11, 0);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
        native_skip_end(function.code, done);
        native_store(function, result, 0); return true;
    }
    return false;
}

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
