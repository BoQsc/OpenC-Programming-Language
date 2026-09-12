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

// An out operand needs the address of its storage even when the stored value
// is itself a pointer. Address-valued lvalues already carry their destination
// address; ordinary locals must use their frame slot. Treating every pointer
// as an address loaded an uninitialized `out ptr` value and made raw file reads
// write through address zero.
unsafe void native_output_address(
    ref NativeFunction function,
    usize value,
    usize reg
) {
    if native_value_read(
        function, function.address_values, value
    ) != 0 {
        native_load(function, value, reg);
    } else {
        native_address(function, value, reg);
    }
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
