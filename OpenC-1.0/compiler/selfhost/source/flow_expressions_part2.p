import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool flow_inside_kind(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize node,
    usize kind
) {
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == kind &&
            semantic_node_contains(syntax_data, record, node) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe bool flow_scope_action_nonvoid(
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
    usize action,
    text source
) {
    usize kind = read_record_field(syntax_data, action, 0);
    if kind == 45 { return false; }
    if kind != 38 { return true; }
    if flow_call_is_memory_free(
        syntax_data, syntax, action, source
    ) { return false; }
    usize selected = flow_call_selection(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, symbol_data, detail_data, symbols,
        token_data, tokens, syntax_data, syntax,
        module_index, source_record, action, source
    );
    if selected >= symbols.length { return true; }
    return read_record_field(symbol_data, selected, 4) !=
        semantic_type_void();
}

unsafe bool flow_pointer_binary(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize node,
    text source
) {
    if read_record_field(syntax_data, node, 0) != 36 ||
        !(flow_node_operator(source, syntax_data, node, "+") ||
          flow_node_operator(source, syntax_data, node, "-")) {
        return false;
    }
    usize start = read_record_field(syntax_data, node, 1);
    usize name = 0;
    while name < syntax.length {
        if read_record_field(syntax_data, name, 0) == 27 &&
            read_record_field(syntax_data, name, 1) == start &&
            semantic_node_contains(syntax_data, node, name) {
            usize symbol = flow_name_symbol(
                project_source, project_root,
                module_data, modules, source_data,
                symbol_data, detail_data, symbols,
                syntax_data, syntax, module_index, source_record,
                name, source
            );
            if symbol < symbols.length {
                usize type_id = read_record_field(
                    symbol_data, symbol, 4
                );
                return read_record_field(type_data, type_id, 0) == 13;
            }
        }
        name = name + 1;
    }
    return false;
}

unsafe void flow_check_pointer_arithmetic(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize function_node,
    text source,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        bool candidate = kind == 36 &&
            (flow_node_operator(source, syntax_data, record, "+") ||
             flow_node_operator(source, syntax_data, record, "-"));
        if candidate &&
            semantic_node_contains(syntax_data, function_node, record) &&
            !flow_inside_unsafe(
                source, syntax_data, syntax, function_node, record
            ) && flow_pointer_binary(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, symbol_data, detail_data, symbols,
                syntax_data, syntax, module_index, source_record,
                record, source
            ) {
            flow_record_error(
                error_data, errors, source_record,
                read_record_field(syntax_data, record, 1),
                read_record_field(syntax_data, record, 2),
                flow_phase_unsafe(), flow_rule_pointer_arithmetic()
            );
        }
        record = record + 1;
    }
}

unsafe void flow_check_unsafe_calls(
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
    usize function_node,
    text source,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 38 &&
            semantic_node_contains(syntax_data, function_node, record) &&
            !flow_inside_unsafe(
                source, syntax_data, syntax, function_node, record
            ) {
            usize selected = flow_call_selection(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, symbol_data, detail_data, symbols,
                token_data, tokens, syntax_data, syntax,
                module_index, source_record, record, source
            );
            if selected < symbols.length && flow_symbol_unsafe(
                project_source, project_root, source_data,
                symbol_data, detail_data, selected
            ) {
                flow_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2),
                    flow_phase_unsafe(), flow_rule_unsafe_call()
                );
            }
        }
        record = record + 1;
    }
}
