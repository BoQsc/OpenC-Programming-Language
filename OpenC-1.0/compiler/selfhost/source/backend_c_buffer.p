import system.file;
import system.memory;
import system.path;
import system.text;

struct CExternalLinkSpan {
    bool found;
    usize start;
    usize length;
}

unsafe void c_put_qualified_symbol(
    ref IrContext context,
    ref DBuffer buffer,
    usize symbol
) {
    d_put(buffer, "oc_");
    d_put_qualified_symbol(context, buffer, symbol, true);
}

unsafe usize c_named_type_symbol(
    ref IrContext context,
    usize type_id
) {
    if context.type_aggregate_symbols != null &&
        type_id < context.types.length {
        usize encoded = read_usize(
            context.type_aggregate_symbols, type_id * size_of(usize)
        );
        if encoded != 0 { return encoded - 1; }
    }
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if (kind == resolution_symbol_struct() ||
             kind == resolution_symbol_resource() ||
             kind == resolution_symbol_enum()) &&
            read_record_field(context.symbol_data, symbol, 4) == type_id {
            return symbol;
        }
        if (kind == resolution_symbol_struct() ||
             kind == resolution_symbol_resource() ||
             kind == resolution_symbol_enum()) &&
            type_id < context.types.length && read_record_field(
                context.type_data, type_id, 0
            ) == 9 {
            usize candidate = read_record_field(
                context.symbol_data, symbol, 4
            );
            if candidate < context.types.length && read_record_field(
                context.type_data, candidate, 0
            ) == 9 && read_record_field(
                context.type_data, candidate, 1
            ) == read_record_field(
                context.type_data, type_id, 1
            ) && read_record_field(
                context.type_data, candidate, 2
            ) == read_record_field(
                context.type_data, type_id, 2
            ) && read_record_field(
                context.type_data, candidate, 3
            ) == read_record_field(
                context.type_data, type_id, 3
            ) { return symbol; }
        }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}

unsafe void c_put_type(
    ref IrContext context,
    ref DBuffer buffer,
    usize type_id
) {
    if type_id >= context.types.length {
        d_put(buffer, "void");
        return;
    }
    usize kind = read_record_field(context.type_data, type_id, 0);
    if kind == 0 || kind == 1 { d_put(buffer, "void"); return; }
    if kind == 2 {
        usize bits = read_record_field(context.type_data, type_id, 3);
        if bits == 8 { d_put(buffer, "int8_t"); }
        else if bits == 16 { d_put(buffer, "int16_t"); }
        else if bits == 32 { d_put(buffer, "int32_t"); }
        else if bits == 64 { d_put(buffer, "int64_t"); }
        else { d_put(buffer, "intptr_t"); }
        return;
    }
    if kind == 3 {
        usize bits = read_record_field(context.type_data, type_id, 3);
        if bits == 8 { d_put(buffer, "uint8_t"); }
        else if bits == 16 { d_put(buffer, "uint16_t"); }
        else if bits == 32 { d_put(buffer, "uint32_t"); }
        else if bits == 64 { d_put(buffer, "uint64_t"); }
        else { d_put(buffer, "uintptr_t"); }
        return;
    }
    if kind == 4 {
        if read_record_field(context.type_data, type_id, 3) == 32 {
            d_put(buffer, "float");
        } else { d_put(buffer, "double"); }
        return;
    }
    if kind == 5 { d_put(buffer, "bool"); return; }
    if kind == 6 { d_put(buffer, "uint8_t"); return; }
    if kind == 7 { d_put(buffer, "oc_text"); return; }
    if kind == 8 { d_put(buffer, "oc_status"); return; }
    if kind == 9 {
        usize symbol = c_named_type_symbol(context, type_id);
        if symbol < context.symbols.length {
            c_put_qualified_symbol(context, buffer, symbol);
        } else { d_put(buffer, "uintptr_t"); }
        return;
    }
    if kind == 10 || kind == 11 || kind == 14 || kind == 15 {
        d_put(buffer, "oc_type_"); d_put_usize(buffer, type_id);
        return;
    }
    if kind == 12 || kind == 13 {
        c_put_type(
            context, buffer,
            read_record_field(context.type_data, type_id, 1)
        );
        d_put(buffer, "*");
        return;
    }
    d_put(buffer, "uintptr_t");
}

unsafe bool c_type_is_integer(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return false; }
    usize kind = read_record_field(context.type_data, type_id, 0);
    return kind == 2 || kind == 3 || kind == 6;
}

unsafe bool c_type_is_text(ref IrContext context, usize type_id) {
    return type_id < context.types.length && read_record_field(
        context.type_data, type_id, 0
    ) == 7;
}

unsafe bool c_type_is_reference(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return false; }
    usize kind = read_record_field(context.type_data, type_id, 0);
    return kind == 12;
}

unsafe bool c_type_is_pointer_like(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return false; }
    usize kind = read_record_field(context.type_data, type_id, 0);
    return kind == 12 || kind == 13;
}

unsafe bool c_type_is_signed(ref IrContext context, usize type_id) {
    return type_id < context.types.length && read_record_field(
        context.type_data, type_id, 0
    ) == 2;
}

unsafe void c_put_checked_suffix(
    ref IrContext context,
    ref DBuffer buffer,
    usize type_id
) {
    usize kind = read_record_field(context.type_data, type_id, 0);
    usize bits = read_record_field(context.type_data, type_id, 3);
    if kind == 6 { d_put(buffer, "u8"); return; }
    if kind == 2 { d_put(buffer, "i"); }
    else { d_put(buffer, "u"); }
    if bits == 8 { d_put(buffer, "8"); }
    else if bits == 16 { d_put(buffer, "16"); }
    else if bits == 32 { d_put(buffer, "32"); }
    else if bits == 64 { d_put(buffer, "64"); }
    else if kind == 2 { d_put(buffer, "size"); }
    else { d_put(buffer, "size"); }
}

unsafe usize c_local_parameter(
    ref IrContext context,
    usize instruction
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                context.function_symbol + 1 && span_equals_ascii(
                    context.source,
                    read_record_field(context.instruction_detail, instruction, 1),
                    read_record_field(context.instruction_detail, instruction, 2),
                    project_slice(
                        context.source,
                        read_record_field(context.symbol_data, symbol, 2),
                        read_record_field(context.symbol_data, symbol, 3)
                    )
                ) { return symbol; }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}

unsafe usize c_call_parameter(
    ref IrContext context,
    usize instruction,
    usize requested
) {
    if read_record_field(
        context.instruction_detail, instruction, 0
    ) != 3 { return context.symbols.length; }
    usize function_symbol = read_record_field(
        context.instruction_detail, instruction, 1
    );
    return d_parameter_at(context, function_symbol, requested);
}

unsafe usize c_value_type(
    ptr byte value_types,
    usize value
) {
    return read_usize(value_types, value * size_of(usize));
}

unsafe bool c_builtin_is(
    ref IrContext context,
    usize instruction,
    text short_name,
    text qualified_name
) {
    return d_instruction_text_is(context, instruction, short_name) ||
        d_instruction_text_is(context, instruction, qualified_name);
}

unsafe CExternalLinkSpan c_external_link_span(
    ref IrContext context,
    usize function_symbol
) {
    CExternalLinkSpan result = CExternalLinkSpan{
        found = false, start = 0, length = 0
    };
    if function_symbol >= context.symbols.length ||
        read_record_field(context.symbol_data, function_symbol, 0) !=
            resolution_symbol_function() ||
        read_record_field(context.symbol_data, function_symbol, 1) !=
            context.source_record {
        return result;
    }
    usize declaration = read_record_field(
        context.detail_data, function_symbol, 1
    );
    if declaration >= context.syntax.length { return result; }
    usize start = read_record_field(context.syntax_data, declaration, 1);
    usize length = read_record_field(context.syntax_data, declaration, 2);
    if !starts_with_ascii(context.source, start, "external") {
        return result;
    }
    usize cursor = start;
    usize end = start + length;
    while cursor < end && byte_at_or_zero(context.source, cursor) != 34 {
        cursor = cursor + 1;
    }
    if cursor >= end { return result; }
    result.start = cursor + 1;
    cursor = result.start;
    while cursor < end && byte_at_or_zero(context.source, cursor) != 34 {
        cursor = cursor + 1;
    }
    if cursor >= end { return result; }
    result.length = cursor - result.start;
    result.found = result.length != 0;
    return result;
}

unsafe void c_put_io_name(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    ptr byte value_types,
    bool line
) {
    d_put(buffer, "ocb_io_");
    if line { d_put(buffer, "println_"); }
    else { d_put(buffer, "print_"); }
    usize value = d_operand_value(context, instruction, 0);
    usize type_id = c_value_type(value_types, value);
    if c_type_is_text(context, type_id) { d_put(buffer, "text"); }
    else if type_id < context.types.length && read_record_field(
        context.type_data, type_id, 0
    ) == 5 { d_put(buffer, "bool"); }
    else if c_type_is_signed(context, type_id) { d_put(buffer, "i64"); }
    else { d_put(buffer, "u64"); }
}
