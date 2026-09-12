import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
    usize known_function_owner,
    usize source_symbol_first,
    usize source_symbol_end,
    ptr byte ownership_relevant_data,
    text source,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize function_owner = known_function_owner;
    if function_owner == 0 {
        function_owner = resolution_find_owner_symbol(
            symbol_data, detail_data, symbols,
            source_record, function_node,
            resolution_symbol_function(), 0
        );
    }
    if function_owner == 0 { return; }
    bool has_own_word = flow_function_has_word(
        source, syntax_data, function_node, "own"
    );
    bool ownership_relevant = flow_function_has_word(
        source, syntax_data, function_node, "destroy"
    );
    if ownership_relevant_data != null {
        ownership_relevant = ownership_relevant || read_usize(
            ownership_relevant_data,
            function_owner * size_of(usize)
        ) != 0;
    } else {
        usize relevant_symbol = source_symbol_first;
        while relevant_symbol < source_symbol_end && !ownership_relevant {
            if read_record_field(detail_data, relevant_symbol, 2) ==
                    function_owner {
                usize relevant_kind = read_record_field(
                    symbol_data, relevant_symbol, 0
                );
                if relevant_kind == resolution_symbol_variable() &&
                    flow_symbol_resource_type(
                        type_data, symbol_data, relevant_symbol
                    ) {
                    ownership_relevant = true;
                } else if relevant_kind == resolution_symbol_parameter() &&
                    (flow_symbol_resource_type(
                        type_data, symbol_data, relevant_symbol
                    ) || (has_own_word && flow_parameter_own(
                        project_source, project_root, source_data,
                        symbol_data, detail_data, relevant_symbol
                    ))) {
                    ownership_relevant = true;
                }
            }
            relevant_symbol = relevant_symbol + 1;
        }
    }
    if !ownership_relevant { return; }
    ptr byte state_data = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(state_data);
    usize symbol = source_symbol_first;
    while symbol < source_symbol_end {
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

    ptr byte event_data = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    scope memory.free(event_data);
    usize event_count = flow_collect_events(
        syntax_data, syntax, function_node, event_data
    );
    usize event_index = 0;
    while event_index < event_count {
        usize event = read_usize(
            event_data, event_index * size_of(usize)
        );
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
        event_index = event_index + 1;
    }

    symbol = source_symbol_first;
    while symbol < source_symbol_end {
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
