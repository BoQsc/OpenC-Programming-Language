import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe ResolutionCallSelection resolution_select_call(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize call,
    text source,
    usize callee_symbol
) {
    bool ambiguous = false;
    usize requested_arguments = read_record_field(syntax_data, call, 4);
    usize callee_start = read_record_field(syntax_data, call, 1);
    usize callee_record = read_record_field(syntax_data, call, 3);
    usize callee_end = read_record_field(syntax_data, callee_record, 1) +
        read_record_field(syntax_data, callee_record, 2);
    usize callee_name_start = read_record_field(syntax_data, callee_record, 1);
    usize callee_name_length = read_record_field(syntax_data, callee_record, 2);
    usize callee_scan = 0;
    while callee_scan < callee_name_length {
        if byte_at_or_zero(source, callee_name_start + callee_scan) == 46 {
            callee_name_start = callee_name_start + callee_scan + 1;
            callee_name_length = callee_name_length - callee_scan - 1;
            callee_scan = 0;
        } else { callee_scan = callee_scan + 1; }
    }
    usize token = resolution_token_after_span(
        token_data, tokens, callee_start, callee_end - callee_start
    );
    if token < tokens.length { token = token + 1; }
    usize argument_starts_capacity = requested_arguments + 1;
    ptr byte argument_data = memory.alloc(argument_starts_capacity * record_stride());
    scope memory.free(argument_data);
    usize argument_count = 0;
    usize depth = 0;
    usize argument_start = callee_end;
    if token < tokens.length {
        argument_start = read_record_field(token_data, token, 1);
    }
    usize call_end = read_record_field(syntax_data, call, 1) +
        read_record_field(syntax_data, call, 2);
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < call_end {
        usize token_start_value = read_record_field(token_data, token, 1);
        usize token_length_value = read_record_field(token_data, token, 2);
        bool open = span_equals_ascii(source, token_start_value, token_length_value, "(") ||
            span_equals_ascii(source, token_start_value, token_length_value, "[") ||
            span_equals_ascii(source, token_start_value, token_length_value, "{");
        bool close = span_equals_ascii(source, token_start_value, token_length_value, ")") ||
            span_equals_ascii(source, token_start_value, token_length_value, "]") ||
            span_equals_ascii(source, token_start_value, token_length_value, "}");
        if close && depth == 0 {
            if requested_arguments != 0 && argument_count < requested_arguments {
                write_record_field(argument_data, argument_count, 0, argument_start);
                write_record_field(argument_data, argument_count, 1, token_start_value);
                argument_count = argument_count + 1;
            }
            break;
        }
        if open { depth = depth + 1; }
        if close && depth != 0 { depth = depth - 1; }
        if depth == 0 && span_equals_ascii(
            source, token_start_value, token_length_value, ","
        ) {
            write_record_field(argument_data, argument_count, 0, argument_start);
            write_record_field(argument_data, argument_count, 1, token_start_value);
            argument_count = argument_count + 1;
            if token + 1 < tokens.length {
                argument_start = read_record_field(token_data, token + 1, 1);
            }
        }
        token = token + 1;
    }

    usize selected = symbols.length;
    usize best_conversions = cast(usize, 4294967295);
    usize candidate = 0;
    while candidate < symbols.length {
        if read_record_field(symbol_data, candidate, 0) == resolution_symbol_function() &&
            read_record_field(detail_data, candidate, 0) ==
                read_record_field(detail_data, callee_symbol, 0) &&
            resolution_symbol_name_equals(
                project_source, project_root, source_data,
                symbol_data, candidate, source,
                callee_name_start, callee_name_length
            ) &&
            resolution_parameter_count(
                symbol_data, detail_data, symbols, candidate
            ) == argument_count {
            bool valid = true;
            usize conversions = 0;
            usize argument = 0;
            while argument < argument_count {
                usize parameter = resolution_nth_parameter(
                    symbol_data, detail_data, symbols, candidate, argument
                );
                usize argument_type = resolution_argument_type(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    source,
                    read_record_field(argument_data, argument, 0),
                    read_record_field(argument_data, argument, 1)
                );
                usize parameter_type = read_record_field(
                    symbol_data, parameter, 4
                );
                if argument_type != parameter_type {
                    if resolution_lossless(
                        type_data, argument_type, parameter_type
                    ) { conversions = conversions + 1; }
                    else { valid = false; }
                }
                argument = argument + 1;
            }
            if valid {
                if selected == symbols.length || conversions < best_conversions {
                    selected = candidate;
                    best_conversions = conversions;
                    ambiguous = false;
                } else if conversions == best_conversions {
                    ambiguous = true;
                }
            }
        }
        candidate = candidate + 1;
    }
    return ResolutionCallSelection{
        symbol = selected,
        ambiguous = ambiguous
    };
}

unsafe ResolutionInteger resolution_parse_integer(
    text source,
    usize start,
    usize length
) {
    bool valid = true;
    usize index = 0;
    usize radix = 10;
    if length > 2 && byte_at_or_zero(source, start) == 48 {
        u8 marker = byte_at_or_zero(source, start + 1);
        if marker == 120 || marker == 88 { radix = 16; index = 2; }
        if marker == 98 || marker == 66 { radix = 2; index = 2; }
    }
    i64 value = 0;
    while index < length {
        u8 octet = byte_at_or_zero(source, start + index);
        if octet == 95 { index = index + 1; continue; }
        usize digit = 0;
        if octet >= 48 && octet <= 57 { digit = cast(usize, octet - 48); }
        else if octet >= 65 && octet <= 70 { digit = cast(usize, octet - 65 + 10); }
        else if octet >= 97 && octet <= 102 { digit = cast(usize, octet - 97 + 10); }
        else {
            return ResolutionInteger{ value = 0, valid = false };
        }
        if digit >= radix {
            return ResolutionInteger{ value = 0, valid = false };
        }
        value = value * cast(i64, radix) + cast(i64, digit);
        index = index + 1;
    }
    return ResolutionInteger{ value = value, valid = valid };
}

bool resolution_expression_kind(usize kind) {
    return kind >= 27 && kind <= 52 && kind != 28;
}

unsafe usize resolution_left_expression(
    ptr byte syntax_data,
    usize parent,
    usize operator_start
) {
    usize parent_start = read_record_field(syntax_data, parent, 1);
    usize selected = parent;
    usize selected_end = parent_start;
    usize record = 0;
    while record < parent {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if resolution_expression_kind(kind) && start == parent_start &&
            end <= operator_start && end >= selected_end {
            selected = record;
            selected_end = end;
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize resolution_right_expression(
    ptr byte syntax_data,
    usize parent,
    usize operator_end
) {
    usize parent_end = read_record_field(syntax_data, parent, 1) +
        read_record_field(syntax_data, parent, 2);
    usize selected = parent;
    usize selected_start = parent_end;
    usize record = 0;
    while record < parent {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if resolution_expression_kind(kind) && start >= operator_end &&
            end == parent_end && start <= selected_start {
            selected = record;
            selected_start = start;
        }
        record = record + 1;
    }
    return selected;
}

