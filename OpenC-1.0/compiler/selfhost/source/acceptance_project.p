import system.file;
import system.memory;
import system.text;

unsafe ResolutionInteger acceptance_enum_explicit(
    ref IrContext context,
    usize item
) {
    usize cursor = read_record_field(context.syntax_data, item, 1) +
        read_record_field(context.syntax_data, item, 2);
    usize source_length = text.byte_length(context.source);
    while cursor < source_length && (byte_at_or_zero(
        context.source, cursor
    ) == 32 || byte_at_or_zero(context.source, cursor) == 9) {
        cursor = cursor + 1;
    }
    if cursor >= source_length || byte_at_or_zero(
        context.source, cursor
    ) != 61 { return ResolutionInteger{ value = 0, valid = false }; }
    cursor = cursor + 1;
    while cursor < source_length && (byte_at_or_zero(
        context.source, cursor
    ) == 32 || byte_at_or_zero(context.source, cursor) == 9) {
        cursor = cursor + 1;
    }
    bool negative = false;
    if cursor < source_length && byte_at_or_zero(
        context.source, cursor
    ) == 45 { negative = true; cursor = cursor + 1; }
    usize start = cursor;
    while cursor < source_length {
        u8 value = byte_at_or_zero(context.source, cursor);
        if value < 48 || value > 57 { break; }
        cursor = cursor + 1;
    }
    if cursor == start {
        return ResolutionInteger{ value = 0, valid = false };
    }
    ResolutionInteger parsed = resolution_parse_integer(
        context.source, start, cursor - start
    );
    if parsed.valid && negative { parsed.value = -parsed.value; }
    return parsed;
}

unsafe usize acceptance_validate_enums(ref IrContext context) {
    usize errors = 0;
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 5 {
            usize left = 0;
            while left < context.syntax.length {
                if read_record_field(context.syntax_data, left, 0) == 6 &&
                    semantic_node_contains(
                        context.syntax_data, declaration, left
                    ) {
                    ResolutionInteger left_value = acceptance_enum_explicit(
                        context, left
                    );
                    if left_value.valid {
                        usize right = left + 1;
                        while right < context.syntax.length {
                            if read_record_field(
                                context.syntax_data, right, 0
                            ) == 6 && semantic_node_contains(
                                context.syntax_data, declaration, right
                            ) {
                                ResolutionInteger right_value =
                                    acceptance_enum_explicit(context, right);
                                if right_value.valid &&
                                    right_value.value == left_value.value {
                                    errors = errors + 1;
                                }
                            }
                            right = right + 1;
                        }
                    }
                }
                left = left + 1;
            }
        }
        declaration = declaration + 1;
    }
    return errors;
}

unsafe usize acceptance_parameter_count(
    ref IrContext context,
    usize function_symbol
) {
    if context.function_parameter_count != null {
        return ir_parameter_count(context, function_symbol);
    }
    usize count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 { count = count + 1; }
        symbol = symbol + 1;
    }
    return count;
}

unsafe usize acceptance_parameter_at(
    ref IrContext context,
    usize function_symbol,
    usize requested
) {
    if context.function_parameter_first != null &&
        context.parameter_next != null {
        return ir_parameter_at(context, function_symbol, requested);
    }
    usize count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 {
            if count == requested { return symbol; }
            count = count + 1;
        }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}

unsafe bool acceptance_same_signature(
    ref IrContext context,
    usize left,
    usize right
) {
    usize count = acceptance_parameter_count(context, left);
    if count != acceptance_parameter_count(context, right) { return false; }
    usize index = 0;
    while index < count {
        usize left_parameter = acceptance_parameter_at(context, left, index);
        usize right_parameter = acceptance_parameter_at(context, right, index);
        if left_parameter >= context.symbols.length ||
            right_parameter >= context.symbols.length || read_record_field(
                context.symbol_data, left_parameter, 4
            ) != read_record_field(
                context.symbol_data, right_parameter, 4
            ) || read_record_field(
                context.detail_data, left_parameter, 3
            ) != read_record_field(
                context.detail_data, right_parameter, 3
            ) { return false; }
        index = index + 1;
    }
    return true;
}

unsafe usize acceptance_validate_duplicate_functions(
    ref IrContext context
) {
    usize errors = 0;
    usize left = 0;
    while left < context.symbols.length {
        if read_record_field(context.symbol_data, left, 0) ==
                resolution_symbol_function() &&
            read_record_field(context.detail_data, left, 2) == 0 {
            usize right = left + 1;
            while right < context.symbols.length {
                if read_record_field(context.symbol_data, right, 0) ==
                        resolution_symbol_function() &&
                    read_record_field(context.detail_data, right, 2) == 0 &&
                    read_record_field(context.detail_data, left, 0) ==
                        read_record_field(context.detail_data, right, 0) &&
                    acceptance_symbol_named(context, left, right) &&
                    acceptance_same_signature(context, left, right) {
                    errors = errors + 1;
                }
                right = right + 1;
            }
        }
        left = left + 1;
    }
    return errors;
}

unsafe bool acceptance_source_imports(
    text source,
    text project_source,
    usize module_start,
    usize module_length
) {
    usize source_length = text.byte_length(source);
    usize cursor = 0;
    while cursor + 6 <= source_length {
        if starts_with_ascii(source, cursor, "import") {
            usize name = cursor + 6;
            while name < source_length && (byte_at_or_zero(source, name) == 32 ||
                byte_at_or_zero(source, name) == 9 ||
                byte_at_or_zero(source, name) == 10 ||
                byte_at_or_zero(source, name) == 13) { name = name + 1; }
            if name + module_length <= source_length && semantic_spans_equal(
                source, name, module_length,
                project_source, module_start, module_length
            ) {
                usize after = name + module_length;
                while after < source_length && (byte_at_or_zero(source, after) == 32 ||
                    byte_at_or_zero(source, after) == 9) { after = after + 1; }
                if after < source_length && byte_at_or_zero(source, after) == 59 {
                    return true;
                }
            }
        }
        cursor = cursor + 1;
    }
    return false;
}
