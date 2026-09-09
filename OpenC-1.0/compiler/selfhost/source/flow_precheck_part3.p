import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool flow_call_has_direct_out(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize call
) {
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 51 &&
            semantic_node_contains(syntax_data, call, record) &&
            resolution_smallest_parent(
                syntax_data, syntax, record, 38, 999, 998
            ) == call {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe bool flow_call_stable_status_local(
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize source_record,
    usize call
) {
    usize declaration = resolution_smallest_parent(
        syntax_data, syntax, call, 12, 999, 998
    );
    if declaration >= syntax.length { return false; }
    usize symbol = resolution_find_owner_symbol(
        symbol_data, detail_data, symbols,
        source_record, declaration,
        resolution_symbol_variable(), 0
    );
    if symbol == 0 { return false; }
    return read_record_field(symbol_data, symbol - 1, 4) ==
        semantic_type_status();
}

unsafe void flow_analyze_status_out(
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
    usize function_owner = resolution_find_owner_symbol(
        symbol_data, detail_data, symbols,
        source_record, function_node,
        resolution_symbol_function(), 0
    );
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 38 &&
            semantic_node_contains(syntax_data, function_node, record) &&
            flow_call_has_direct_out(syntax_data, syntax, record) {
            usize selected = flow_call_selection(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, symbol_data, detail_data, symbols,
                token_data, tokens, syntax_data, syntax,
                module_index, source_record, record, source
            );
            if selected >= symbols.length {
                selected = flow_call_declared_target(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    record, source
                );
            }
            bool returns_status = selected < symbols.length &&
                read_record_field(symbol_data, selected, 4) ==
                    semantic_type_status();
            if selected >= symbols.length && flow_call_is_status_builtin(
                syntax_data, syntax, record, source
            ) { returns_status = true; }
            if !returns_status {
                flow_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2),
                    flow_phase_type(), flow_rule_out_status()
                );
            }
            if !flow_call_stable_status_local(
                symbol_data, detail_data, symbols,
                syntax_data, syntax, source_record, record
            ) {
                flow_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2),
                    flow_phase_flow(), flow_rule_out_carrier()
                );
            }
        }
        record = record + 1;
    }
    if function_owner == 0 { return; }
    bool has_out = false;
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(detail_data, symbol, 2) == function_owner &&
            read_record_field(detail_data, symbol, 3) == 1 {
            has_out = true;
        }
        symbol = symbol + 1;
    }
    if has_out && read_record_field(
        symbol_data, function_owner - 1, 4
    ) != semantic_type_status() {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, function_node, 1),
            read_record_field(syntax_data, function_node, 2),
            flow_phase_type(), flow_rule_out_function_status()
        );
        record = 0;
        while record < syntax.length {
            if read_record_field(syntax_data, record, 0) == 22 &&
                semantic_node_contains(syntax_data, function_node, record) {
                usize expression = flow_root_expression(
                    syntax_data, syntax, record
                );
                if expression < syntax.length {
                    flow_record_error(
                        error_data, errors, source_record,
                        read_record_field(syntax_data, record, 1),
                        read_record_field(syntax_data, record, 2),
                        flow_phase_type(), flow_rule_out_return()
                    );
                }
            }
            record = record + 1;
        }
    }
}

unsafe void flow_analyze_cleanup(
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
    usize scope_node = 0;
    while scope_node < syntax.length {
        if read_record_field(syntax_data, scope_node, 0) == 23 &&
            semantic_node_contains(syntax_data, function_node, scope_node) {
            usize action = flow_root_expression(
                syntax_data, syntax, scope_node
            );
            if action < syntax.length &&
                read_record_field(syntax_data, action, 0) == 38 {
                usize selected = flow_call_selection(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, action, source
                );
                if selected >= symbols.length &&
                    flow_call_has_direct_out(
                        syntax_data, syntax, action
                    ) {
                    selected = flow_call_declared_target(
                        project_source, project_root,
                        module_data, modules, source_data,
                        symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        action, source
                    );
                }
                if selected >= symbols.length && flow_call_is_memory_free(
                    syntax_data, syntax, action, source
                ) {
                    scope_node = scope_node + 1;
                    continue;
                }
                if selected >= symbols.length {
                    flow_record_error(
                        error_data, errors, source_record,
                        read_record_field(syntax_data, action, 1),
                        read_record_field(syntax_data, action, 2),
                        flow_phase_name(), flow_rule_scope_action()
                    );
                } else {
                    if read_record_field(symbol_data, selected, 4) !=
                        semantic_type_void() {
                        flow_record_error(
                            error_data, errors, source_record,
                            read_record_field(syntax_data, action, 1),
                            read_record_field(syntax_data, action, 2),
                            flow_phase_type(), flow_rule_scope_nofail()
                        );
                    }
                    usize parameter = 0;
                    while parameter < symbols.length {
                        if read_record_field(symbol_data, parameter, 0) ==
                                resolution_symbol_parameter() &&
                            read_record_field(detail_data, parameter, 2) ==
                                selected + 1 &&
                            read_record_field(detail_data, parameter, 3) == 1 {
                            flow_record_error(
                                error_data, errors, source_record,
                                read_record_field(syntax_data, action, 1),
                                read_record_field(syntax_data, action, 2),
                                flow_phase_type(), flow_rule_scope_nofail()
                            );
                        }
                        parameter = parameter + 1;
                    }
                }
            } else if action < syntax.length &&
                read_record_field(syntax_data, action, 0) != 45 {
                flow_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, action, 1),
                    read_record_field(syntax_data, action, 2),
                    flow_phase_name(), flow_rule_scope_action()
                );
            }
        }
        scope_node = scope_node + 1;
    }
}
