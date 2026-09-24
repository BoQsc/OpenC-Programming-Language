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
        type_id >= context.native_layout_cache_entries ||
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
