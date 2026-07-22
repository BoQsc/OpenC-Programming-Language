import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool flow_function_unsafe(
    text source,
    ptr byte syntax_data,
    usize function_node
) {
    usize start = read_record_field(syntax_data, function_node, 1);
    usize name_start = read_record_field(syntax_data, function_node, 3);
    usize cursor = start;
    while cursor + 6 <= name_start {
        if starts_with_ascii(source, cursor, "unsafe") { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_inside_unsafe(
    text source,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    usize node
) {
    if flow_function_unsafe(source, syntax_data, function_node) { return true; }
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 24 &&
            semantic_node_contains(syntax_data, record, node) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe bool flow_node_operator(
    text source,
    ptr byte syntax_data,
    usize node,
    text expected
) {
    return span_equals_ascii(
        source,
        read_record_field(syntax_data, node, 3),
        read_record_field(syntax_data, node, 4),
        expected
    );
}

unsafe void flow_check_unsafe_function(
    text source,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize source_record,
    usize function_node,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        bool candidate = kind == 43 ||
            (kind == 35 &&
             (flow_node_operator(source, syntax_data, record, "&") ||
              flow_node_operator(source, syntax_data, record, "*")));
        if candidate && record != function_node && semantic_node_contains(
            syntax_data, function_node, record
        ) && !flow_inside_unsafe(
            source, syntax_data, syntax, function_node, record
        ) {
            usize rule = 0;
            if kind == 35 && flow_node_operator(
                source, syntax_data, record, "&"
            ) { rule = flow_rule_pointer_address(); }
            if kind == 35 && flow_node_operator(
                source, syntax_data, record, "*"
            ) { rule = flow_rule_pointer_deref(); }
            if kind == 43 { rule = flow_rule_reinterpret(); }
            if rule != 0 {
                flow_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2),
                    flow_phase_unsafe(), rule
                );
            }
        }
        record = record + 1;
    }
}

unsafe usize flow_root_expression(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize parent
) {
    usize selected = syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if flow_expression_kind(kind) &&
            semantic_node_contains(syntax_data, parent, record) {
            usize length = read_record_field(syntax_data, record, 2);
            if selected == syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}
