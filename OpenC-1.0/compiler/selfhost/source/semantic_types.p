import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize semantic_resolve_type(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize source_record,
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte type_data,
    ref PackedBuffer types,
    usize start,
    usize length
) {
    usize end = start + length;
    usize token = semantic_token_at_or_after(token_data, tokens, start);
    bool leading_const = false;
    if token < tokens.length && span_equals_ascii(
        source,
        read_record_field(token_data, token, 1),
        read_record_field(token_data, token, 2),
        "const"
    ) {
        leading_const = true;
        token = token + 1;
    }
    usize constructor = 0;
    if token < tokens.length {
        usize token_start_value = read_record_field(token_data, token, 1);
        usize token_length_value = read_record_field(token_data, token, 2);
        if span_equals_ascii(source, token_start_value, token_length_value, "ref") {
            constructor = 12; token = token + 1;
        } else if span_equals_ascii(source, token_start_value, token_length_value, "ptr") {
            constructor = 13; token = token + 1;
        } else if span_equals_ascii(source, token_start_value, token_length_value, "optional") {
            constructor = 14; token = token + 1;
        } else if span_equals_ascii(source, token_start_value, token_length_value, "storage") {
            constructor = 15; token = token + 1;
        }
    }
    bool constructor_const = false;
    if (constructor == 12 || constructor == 13) && token < tokens.length &&
        span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "const"
        ) {
        constructor_const = true;
        token = token + 1;
    }
    if token >= tokens.length { return semantic_type_error(); }
    usize base_start = read_record_field(token_data, token, 1);
    usize base_end = base_start + read_record_field(token_data, token, 2);
    token = token + 1;
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < end &&
        !span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "["
        ) {
        base_end = read_record_field(token_data, token, 1) +
            read_record_field(token_data, token, 2);
        token = token + 1;
    }
    usize base_length = base_end - base_start;
    usize result = semantic_builtin_type(source, base_start, base_length);
    if result == semantic_type_error() {
        result = semantic_find_named(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, types,
            source, base_start, base_length
        );
        if result == semantic_type_error() {
            usize module_index = semantic_source_module(
                module_data, modules, source_record
            );
            result = semantic_declare_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types,
                module_index, source_record, source,
                base_start, base_length, false, false
            );
        }
    }
    bool const_qualified = leading_const || constructor_const;
    if constructor == 12 || constructor == 13 || constructor == 14 || constructor == 15 {
        result = semantic_derived_type(
            type_data, types, constructor, result, 0,
            const_qualified, false
        );
    } else if const_qualified {
        result = semantic_derived_type(
            type_data, types,
            read_record_field(type_data, result, 0), result, 0,
            true, true
        );
    }
    if token < tokens.length &&
        span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "["
        ) {
        token = token + 1;
        bool slice = token < tokens.length && span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            "]"
        );
        if slice {
            result = semantic_derived_type(
                type_data, types, 11, result, 0, false, false
            );
        } else {
            usize array_length = semantic_array_length(
                source, token_data, tokens, token, end
            );
            result = semantic_derived_type(
                type_data, types, 10, result, array_length, false, false
            );
        }
    }
    return result;
}

unsafe bool semantic_node_contains(
    ptr byte syntax_data,
    usize parent,
    usize child
) {
    usize parent_start = read_record_field(syntax_data, parent, 1);
    usize parent_end = parent_start + read_record_field(syntax_data, parent, 2);
    usize child_start = read_record_field(syntax_data, child, 1);
    usize child_end = child_start + read_record_field(syntax_data, child, 2);
    return child_start >= parent_start && child_end <= parent_end;
}

unsafe bool semantic_inside_when(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize node
) {
    usize record = 0;
    while record < syntax.length {
        if record != node && read_record_field(syntax_data, record, 0) == 8 &&
            semantic_node_contains(syntax_data, record, node) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe usize semantic_find_prefix_type(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration
) {
    usize start = read_record_field(syntax_data, declaration, 1);
    usize name_start = read_record_field(syntax_data, declaration, 3);
    usize record = 0;
    while record < syntax.length {
        usize node_start = read_record_field(syntax_data, record, 1);
        usize node_end = node_start + read_record_field(syntax_data, record, 2);
        if read_record_field(syntax_data, record, 0) == 26 &&
            node_start >= start && node_end <= name_start {
            return record;
        }
        record = record + 1;
    }
    return syntax.length;
}

unsafe bool semantic_prefix_has(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    usize start,
    usize end,
    text expected
) {
    usize token = semantic_token_at_or_after(token_data, tokens, start);
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < end {
        if span_equals_ascii(
            source,
            read_record_field(token_data, token, 1),
            read_record_field(token_data, token, 2),
            expected
        ) { return true; }
        token = token + 1;
    }
    return false;
}

unsafe bool semantic_same_name_record(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    usize symbol,
    text source,
    usize name_start,
    usize name_length
) {
    text prior_source;
    status prior_status = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1),
        out prior_source
    );
    if !prior_status.ok { return false; }
    return semantic_spans_equal(
        source, name_start, name_length,
        prior_source,
        read_record_field(symbol_data, symbol, 2),
        read_record_field(symbol_data, symbol, 3)
    );
}
