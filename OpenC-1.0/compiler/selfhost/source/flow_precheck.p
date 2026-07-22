import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void flow_precheck_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_record,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    text source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !loaded.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{
        length = 0, capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    usize function_node = 0;
    while function_node < syntax.length {
        if read_record_field(syntax_data, function_node, 0) == 2 {
            usize body = flow_largest_direct_block(
                syntax_data, syntax, function_node
            );
            if body < syntax.length &&
                read_record_field(syntax_data, body, 2) > 1 {
                flow_check_unsafe_function(
                    source, syntax_data, syntax, source_record,
                    function_node, error_data, errors
                );
                flow_check_pointer_arithmetic(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                usize scope_node = 0;
                while scope_node < syntax.length {
                    if read_record_field(
                        syntax_data, scope_node, 0
                    ) == 23 && semantic_node_contains(
                        syntax_data, function_node, scope_node
                    ) {
                        usize action = flow_root_expression(
                            syntax_data, syntax, scope_node
                        );
                        if action < syntax.length &&
                            flow_scope_action_nonvoid(
                                project_source, project_root,
                                module_data, modules, source_data,
                                type_data, symbol_data, detail_data, symbols,
                                token_data, tokens, syntax_data, syntax,
                                module_index, source_record, action, source
                            ) {
                            flow_record_error(
                                error_data, errors, source_record,
                                read_record_field(syntax_data, action, 1),
                                read_record_field(syntax_data, action, 2),
                                flow_phase_type(), flow_rule_scope_nofail()
                            );
                        }
                    }
                    scope_node = scope_node + 1;
                }
            }
        }
        function_node = function_node + 1;
    }
}

unsafe bool flow_span_has_byte(
    text source,
    usize start,
    usize length,
    u8 expected
) {
    usize cursor = start;
    while cursor < start + length {
        if byte_at_or_zero(source, cursor) == expected { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_name_assignment_lhs(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize name
) {
    usize start = read_record_field(syntax_data, name, 1);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 37 &&
            read_record_field(syntax_data, record, 1) == start &&
            semantic_node_contains(syntax_data, record, name) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe bool flow_name_construct_target(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize name
) {
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 44 &&
            semantic_node_contains(syntax_data, record, name) {
            if flow_event_first_name(
                syntax_data, syntax, record
            ) == name { return true; }
        }
        record = record + 1;
    }
    return false;
}

unsafe usize flow_assignment_for_symbol(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize symbol,
    usize before,
    text source
) {
    usize selected = syntax.length;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 37 &&
            read_record_field(syntax_data, record, 1) < before {
            usize start = read_record_field(syntax_data, record, 1);
            usize name = 0;
            while name < syntax.length {
                if read_record_field(syntax_data, name, 0) == 27 &&
                    read_record_field(syntax_data, name, 1) == start &&
                    semantic_node_contains(syntax_data, record, name) {
                    usize found = flow_name_symbol(
                        project_source, project_root,
                        module_data, modules, source_data,
                        symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        name, source
                    );
                    if found == symbol { selected = record; }
                }
                name = name + 1;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_assignment_count_for_symbol(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize symbol,
    usize before,
    text source
) {
    usize count = 0;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 37 &&
            read_record_field(syntax_data, record, 1) < before {
            usize start = read_record_field(syntax_data, record, 1);
            usize name = 0;
            while name < syntax.length {
                if read_record_field(syntax_data, name, 0) == 27 &&
                    read_record_field(syntax_data, name, 1) == start &&
                    semantic_node_contains(syntax_data, record, name) {
                    usize found = flow_name_symbol(
                        project_source, project_root,
                        module_data, modules, source_data,
                        symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        name, source
                    );
                    if found == symbol { count = count + 1; }
                }
                name = name + 1;
            }
        }
        record = record + 1;
    }
    return count;
}
