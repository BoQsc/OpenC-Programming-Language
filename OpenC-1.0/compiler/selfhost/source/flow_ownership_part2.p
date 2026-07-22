import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize flow_local_initializer_name(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration
) {
    usize name_start = read_record_field(syntax_data, declaration, 3);
    usize selected = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 27 &&
            semantic_node_contains(syntax_data, declaration, record) {
            usize start = read_record_field(syntax_data, record, 1);
            if start > name_start && start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_local_initializer_root(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration
) {
    usize name_start = read_record_field(syntax_data, declaration, 3);
    usize selected = syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        if flow_expression_kind(kind) && start > name_start &&
            semantic_node_contains(syntax_data, declaration, record) {
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

unsafe void flow_analyze_borrows(
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
    usize function_owner = resolution_find_owner_symbol(
        symbol_data, detail_data, symbols,
        source_record, function_node,
        resolution_symbol_function(), 0
    );
    if function_owner == 0 { return; }
    ptr byte borrowed_data = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(borrowed_data);
    usize index = 0;
    while index < symbols.length {
        write_usize(borrowed_data, index * size_of(usize), 0);
        index = index + 1;
    }
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_variable() &&
            read_record_field(detail_data, symbol, 2) == function_owner {
            usize type_id = read_record_field(symbol_data, symbol, 4);
            if read_record_field(type_data, type_id, 0) == 12 {
                usize declaration = read_record_field(
                    detail_data, symbol, 1
                );
                usize initializer = flow_local_initializer_root(
                    syntax_data, syntax, declaration
                );
                if initializer < syntax.length &&
                    read_record_field(syntax_data, initializer, 0) == 27 {
                    usize owner = flow_name_symbol(
                        project_source, project_root,
                        module_data, modules, source_data,
                        symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        initializer, source
                    );
                    if owner < symbols.length {
                        usize existing = read_usize(
                            borrowed_data, owner * size_of(usize)
                        );
                        bool mutable_borrow =
                            read_record_field(type_data, type_id, 4) % 2 == 0;
                        if existing != 0 && mutable_borrow {
                            usize packed = read_record_field(
                                detail_data, symbol, 4
                            );
                            flow_record_error(
                                error_data, errors, source_record,
                                resolution_span_start(packed),
                                resolution_span_length(packed),
                                flow_phase_borrow(), flow_rule_borrow_conflict()
                            );
                        }
                        usize borrow_state = 1;
                        if mutable_borrow { borrow_state = 2; }
                        write_usize(
                            borrowed_data, owner * size_of(usize), borrow_state
                        );
                    }
                }
            }
        }
        symbol = symbol + 1;
    }
}

unsafe void flow_analyze_pointer_facts(
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
    usize function_owner = resolution_find_owner_symbol(
        symbol_data, detail_data, symbols,
        source_record, function_node,
        resolution_symbol_function(), 0
    );
    if function_owner == 0 { return; }
    usize node = 0;
    while node < syntax.length {
        if read_record_field(syntax_data, node, 0) == 35 &&
            flow_node_operator(source, syntax_data, node, "*") &&
            semantic_node_contains(syntax_data, function_node, node) {
            usize operand_name = flow_event_first_name(
                syntax_data, syntax, node
            );
            if operand_name < syntax.length {
                usize pointer_symbol = flow_name_symbol(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    operand_name, source
                );
                if pointer_symbol < symbols.length {
                    usize declaration = read_record_field(
                        detail_data, pointer_symbol, 1
                    );
                    usize binary = 0;
                    while binary < syntax.length {
                        if read_record_field(syntax_data, binary, 0) == 36 &&
                            flow_node_operator(source, syntax_data, binary, "+") &&
                            semantic_node_contains(
                                syntax_data, declaration, binary
                            ) {
                            usize literal = 0;
                            while literal < syntax.length {
                                if read_record_field(
                                    syntax_data, literal, 0
                                ) == 29 && semantic_node_contains(
                                    syntax_data, binary, literal
                                ) {
                                    ResolutionInteger amount =
                                        resolution_parse_integer(
                                            source,
                                            read_record_field(
                                                syntax_data, literal, 1
                                            ),
                                            read_record_field(
                                                syntax_data, literal, 2
                                            )
                                        );
                                    if amount.valid {
                                        usize candidate = 0;
                                        while candidate < symbols.length {
                                            if read_record_field(
                                                detail_data, candidate, 2
                                            ) == function_owner {
                                                usize candidate_type =
                                                    read_record_field(
                                                        symbol_data,
                                                        candidate, 4
                                                    );
                                                if read_record_field(
                                                    type_data, candidate_type, 0
                                                ) == 10 &&
                                                    read_record_field(
                                                        type_data,
                                                        candidate_type, 2
                                                    ) == cast(usize, amount.value) {
                                                    flow_record_error(
                                                        error_data, errors,
                                                        source_record,
                                                        read_record_field(
                                                            syntax_data,
                                                            node, 1
                                                        ),
                                                        read_record_field(
                                                            syntax_data,
                                                            node, 2
                                                        ),
                                                        flow_phase_unsafe(),
                                                        flow_rule_pointer_onepast()
                                                    );
                                                }
                                            }
                                            candidate = candidate + 1;
                                        }
                                    }
                                }
                                literal = literal + 1;
                            }
                        }
                        binary = binary + 1;
                    }
                }
            }
        }
        node = node + 1;
    }
}
