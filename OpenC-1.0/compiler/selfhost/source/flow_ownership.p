import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize flow_state_get(ptr byte state_data, usize symbol) {
    return read_usize(state_data, symbol * size_of(usize));
}

unsafe void flow_state_set(
    ptr byte state_data,
    usize symbol,
    usize state
) {
    write_usize(state_data, symbol * size_of(usize), state);
}

unsafe usize flow_event_next(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    usize after_end,
    usize after_record
) {
    usize selected = syntax.length;
    usize selected_end = cast(usize, 4294967295);
    usize selected_record = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        bool event = kind == 12 || kind == 23 || kind == 37 ||
            kind == 38 || kind == 45 || kind == 22;
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if event && semantic_node_contains(
            syntax_data, function_node, record
        ) && (end > after_end ||
            (end == after_end && record > after_record)) &&
            (selected == syntax.length || end < selected_end ||
             (end == selected_end && record < selected_record)) {
            selected = record;
            selected_end = end;
            selected_record = record;
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_event_name_symbol(
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
    usize event,
    text source
) {
    usize selected_name = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 27 &&
            semantic_node_contains(syntax_data, event, record) {
            usize start = read_record_field(syntax_data, record, 1);
            if start < selected_start {
                selected_name = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    if selected_name >= syntax.length { return symbols.length; }
    return flow_name_symbol(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        selected_name, source
    );
}

unsafe usize flow_event_first_name(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize event
) {
    usize selected = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 27 &&
            semantic_node_contains(syntax_data, event, record) {
            usize start = read_record_field(syntax_data, record, 1);
            if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe void flow_move_owner(
    ptr byte state_data,
    usize symbol,
    usize source_record,
    usize site,
    ptr byte syntax_data,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize state = flow_state_get(state_data, symbol);
    if state == 2 {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, site, 1),
            read_record_field(syntax_data, site, 2),
            flow_phase_ownership(), flow_rule_own_cleanup_reserved()
        );
    } else if state == 1 {
        flow_state_set(state_data, symbol, 3);
    } else if state == 4 {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, site, 1),
            read_record_field(syntax_data, site, 2),
            flow_phase_ownership(), flow_rule_own_use_destroy()
        );
    } else {
        flow_record_error(
            error_data, errors, source_record,
            read_record_field(syntax_data, site, 1),
            read_record_field(syntax_data, site, 2),
            flow_phase_ownership(), flow_rule_own_use_move()
        );
    }
}

unsafe void flow_move_initializer_owners(
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
    usize declaration,
    text source,
    ptr byte state_data,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize initializer = flow_local_initializer_root(
        syntax_data, syntax, declaration
    );
    if initializer >= syntax.length || read_record_field(
        syntax_data, initializer, 0
    ) != 48 { return; }
    usize field = 0;
    while field < syntax.length {
        if read_record_field(syntax_data, field, 0) == 49 &&
            semantic_node_contains(syntax_data, initializer, field) &&
            resolution_smallest_parent(
                syntax_data, syntax, field, 48, 999, 998
            ) == initializer {
            usize start = read_record_field(syntax_data, field, 1);
            if start >= 4 && starts_with_ascii(source, start - 4, "own ") {
                usize name = flow_event_first_name(
                    syntax_data, syntax, field
                );
                if name < syntax.length {
                    usize owner = flow_name_symbol(
                        project_source, project_root,
                        module_data, modules, source_data,
                        symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        name, source
                    );
                    if owner < symbols.length &&
                        flow_state_get(state_data, owner) != 0 {
                        flow_move_owner(
                            state_data, owner, source_record, name,
                            syntax_data, error_data, errors
                        );
                    }
                }
            }
        }
        field = field + 1;
    }
}

unsafe void flow_analyze_ownership(
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
    if function_owner == 0 { return; }
    ptr byte state_data = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(state_data);
    usize symbol = 0;
    while symbol < symbols.length {
        flow_state_set(state_data, symbol, 0);
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(detail_data, symbol, 2) == function_owner &&
            (flow_symbol_resource_type(type_data, symbol_data, symbol) ||
             flow_parameter_own(
                project_source, project_root, source_data,
                symbol_data, detail_data, symbol
             )) {
            if read_record_field(detail_data, symbol, 3) != 1 {
                flow_state_set(state_data, symbol, 1);
            }
        }
        symbol = symbol + 1;
    }

    usize previous_end = 0;
    usize previous_record = 0;
    bool first = true;
    while true {
        usize requested_end = previous_end;
        usize requested_record = previous_record;
        if first { requested_end = 0; requested_record = 0; }
        usize event = flow_event_next(
            syntax_data, syntax, function_node,
            requested_end, requested_record
        );
        if event >= syntax.length { break; }
        usize kind = read_record_field(syntax_data, event, 0);
        if kind == 38 && !flow_inside_kind(
            syntax_data, syntax, event, 23
        ) {
            usize selected = flow_call_selection(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, symbol_data, detail_data, symbols,
                token_data, tokens, syntax_data, syntax,
                module_index, source_record, event, source
            );
            if selected < symbols.length {
                usize parameter = 0;
                while parameter < symbols.length {
                    if read_record_field(symbol_data, parameter, 0) ==
                            resolution_symbol_parameter() &&
                        read_record_field(detail_data, parameter, 2) ==
                            selected + 1 && flow_parameter_own(
                                project_source, project_root, source_data,
                                symbol_data, detail_data, parameter
                            ) {
                        usize argument = flow_call_argument_name(
                            syntax_data, syntax, event, 0
                        );
                        if argument < syntax.length {
                            if flow_span_has_byte(
                                source,
                                read_record_field(
                                    syntax_data, argument, 1
                                ),
                                read_record_field(
                                    syntax_data, argument, 2
                                ), 46
                            ) {
                                flow_record_error(
                                    error_data, errors, source_record,
                                    read_record_field(
                                        syntax_data, argument, 1
                                    ),
                                    read_record_field(
                                        syntax_data, argument, 2
                                    ),
                                    flow_phase_ownership(),
                                    flow_rule_own_use_move()
                                );
                            } else {
                                usize owner = flow_name_symbol(
                                    project_source, project_root,
                                    module_data, modules, source_data,
                                    symbol_data, detail_data, symbols,
                                    syntax_data, syntax,
                                    module_index, source_record,
                                    argument, source
                                );
                                if owner < symbols.length &&
                                    flow_state_get(state_data, owner) != 0 {
                                    flow_move_owner(
                                        state_data, owner, source_record,
                                        argument, syntax_data,
                                        error_data, errors
                                    );
                                }
                            }
                        }
                    }
                    parameter = parameter + 1;
                }
            }
        } else if kind == 12 {
            usize local = resolution_find_owner_symbol(
                symbol_data, detail_data, symbols,
                source_record, event,
                resolution_symbol_variable(), 0
            );
            if local != 0 && flow_symbol_resource_type(
                type_data, symbol_data, local - 1
            ) && flow_span_has_byte(
                source,
                read_record_field(syntax_data, event, 1),
                read_record_field(syntax_data, event, 2), 61
            ) {
                flow_state_set(state_data, local - 1, 1);
            }
            flow_move_initializer_owners(
                project_source, project_root,
                module_data, modules, source_data,
                symbol_data, detail_data, symbols,
                syntax_data, syntax, module_index, source_record,
                event, source, state_data, error_data, errors
            );
        } else if kind == 23 {
            usize action = flow_root_expression(
                syntax_data, syntax, event
            );
            usize argument = syntax.length;
            bool destroy_action = false;
            if action < syntax.length &&
                read_record_field(syntax_data, action, 0) == 45 {
                destroy_action = true;
                argument = flow_event_first_name(
                    syntax_data, syntax, action
                );
            } else if action < syntax.length &&
                read_record_field(syntax_data, action, 0) == 38 {
                argument = flow_call_argument_name(
                    syntax_data, syntax, action, 0
                );
            }
            if argument < syntax.length {
                usize owner = flow_name_symbol(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax,
                    module_index, source_record, argument, source
                );
                if owner < symbols.length {
                    usize owner_state = flow_state_get(
                        state_data, owner
                    );
                    if destroy_action && owner_state == 0 {
                        flow_state_set(state_data, owner, 2);
                    } else if owner_state != 0 && owner_state != 1 {
                        flow_record_error(
                            error_data, errors, source_record,
                            read_record_field(syntax_data, argument, 1),
                            read_record_field(syntax_data, argument, 2),
                            flow_phase_ownership(), flow_rule_scope_owner_state()
                        );
                    } else if owner_state == 1 {
                        flow_state_set(state_data, owner, 2);
                    }
                }
            }
        } else if kind == 45 && !flow_inside_kind(
            syntax_data, syntax, event, 23
        ) {
            usize name = flow_event_first_name(
                syntax_data, syntax, event
            );
            if name < syntax.length {
                usize owner = flow_name_symbol(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax,
                    module_index, source_record, name, source
                );
                if owner < symbols.length &&
                    flow_state_get(state_data, owner) == 2 {
                    flow_record_error(
                        error_data, errors, source_record,
                        read_record_field(syntax_data, event, 1),
                        read_record_field(syntax_data, event, 2),
                        flow_phase_ownership(), flow_rule_own_double_discharge()
                    );
                } else if owner < symbols.length &&
                    flow_state_get(state_data, owner) != 0 {
                    flow_state_set(state_data, owner, 4);
                }
            }
        } else if kind == 22 {
            usize returned_name = flow_event_first_name(
                syntax_data, syntax, event
            );
            if returned_name < syntax.length {
                usize returned_symbol = flow_name_symbol(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax,
                    module_index, source_record, returned_name, source
                );
                if returned_symbol < symbols.length &&
                    flow_state_get(state_data, returned_symbol) != 0 {
                    flow_move_owner(
                        state_data, returned_symbol, source_record,
                        returned_name, syntax_data, error_data, errors
                    );
                }
            }
        } else if kind == 37 {
            usize destination = flow_event_name_symbol(
                project_source, project_root,
                module_data, modules, source_data,
                symbol_data, detail_data, symbols,
                syntax_data, syntax, module_index, source_record,
                event, source
            );
            if destination < symbols.length &&
                flow_state_get(state_data, destination) != 0 {
                usize state = flow_state_get(state_data, destination);
                if state == 1 || state == 2 {
                    usize site = flow_event_first_name(
                        syntax_data, syntax, event
                    );
                    flow_record_error(
                        error_data, errors, source_record,
                        read_record_field(syntax_data, site, 1),
                        read_record_field(syntax_data, site, 2),
                        flow_phase_ownership(), flow_rule_own_overwrite()
                    );
                }
                flow_state_set(state_data, destination, 1);
            }
        }
        previous_end = read_record_field(syntax_data, event, 1) +
            read_record_field(syntax_data, event, 2);
        previous_record = event;
        first = false;
    }

    symbol = 0;
    while symbol < symbols.length {
        if flow_state_get(state_data, symbol) == 1 &&
            read_record_field(detail_data, symbol, 2) == function_owner {
            usize kind = read_record_field(symbol_data, symbol, 0);
            bool exempt = false;
            if kind == resolution_symbol_parameter() {
                exempt = flow_parameter_own(
                    project_source, project_root, source_data,
                    symbol_data, detail_data, symbol
                ) || read_record_field(detail_data, symbol, 3) == 1;
            }
            if !exempt {
                usize packed = read_record_field(detail_data, symbol, 4);
                flow_record_error(
                    error_data, errors, source_record,
                    resolution_span_start(packed),
                    resolution_span_length(packed),
                    flow_phase_ownership(), flow_rule_own_exit()
                );
            }
        }
        symbol = symbol + 1;
    }
}
