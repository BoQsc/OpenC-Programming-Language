import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

bool flow_span_contains_ascii(
    text source,
    usize start,
    usize length,
    text expected
) {
    usize cursor = start;
    while cursor + text.byte_length(expected) <= start + length {
        if starts_with_ascii(source, cursor, expected) { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_out_proof_initializes(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    usize use_node,
    text source
) {
    usize use_start = read_record_field(syntax_data, use_node, 1);
    bool prior_out = false;
    usize out_node = 0;
    while out_node < syntax.length {
        if read_record_field(syntax_data, out_node, 0) == 51 &&
            read_record_field(syntax_data, out_node, 1) < use_start &&
            semantic_node_contains(syntax_data, function_node, out_node) {
            prior_out = true;
        }
        out_node = out_node + 1;
    }
    if !prior_out { return false; }
    usize if_node = 0;
    while if_node < syntax.length {
        if read_record_field(syntax_data, if_node, 0) == 14 &&
            semantic_node_contains(syntax_data, function_node, if_node) {
            usize start = read_record_field(syntax_data, if_node, 1);
            usize end = start + read_record_field(syntax_data, if_node, 2);
            usize first_block_start = end;
            usize block = 0;
            while block < syntax.length {
                if read_record_field(syntax_data, block, 0) == 11 &&
                    semantic_node_contains(syntax_data, if_node, block) {
                    usize block_start = read_record_field(
                        syntax_data, block, 1
                    );
                    if block_start < first_block_start {
                        first_block_start = block_start;
                    }
                }
                block = block + 1;
            }
            bool status_proof = flow_span_contains_ascii(
                source, start, first_block_start - start, ".ok"
            );
            bool negated = flow_span_contains_ascii(
                source, start, first_block_start - start, "!"
            );
            if status_proof && semantic_node_contains(
                syntax_data, if_node, use_node
            ) && !negated { return true; }
            if status_proof && negated && end < use_start {
                usize return_node = 0;
                while return_node < syntax.length {
                    if read_record_field(
                        syntax_data, return_node, 0
                    ) == 22 && semantic_node_contains(
                        syntax_data, if_node, return_node
                    ) { return true; }
                    return_node = return_node + 1;
                }
            }
        }
        if_node = if_node + 1;
    }
    return false;
}

unsafe usize flow_init_repeat(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize assignment
) {
    if assignment >= syntax.length { return 1; }
    usize loop_node = resolution_smallest_parent(
        syntax_data, syntax, assignment, 15, 16, 999
    );
    if loop_node >= syntax.length { return 1; }
    usize assignment_start = read_record_field(
        syntax_data, assignment, 1
    );
    usize record = 0;
    bool has_break = false;
    bool early_continue = false;
    while record < syntax.length {
        if semantic_node_contains(syntax_data, loop_node, record) {
            usize kind = read_record_field(syntax_data, record, 0);
            if kind == 20 { has_break = true; }
            if kind == 21 && read_record_field(
                syntax_data, record, 1
            ) < assignment_start { early_continue = true; }
        }
        record = record + 1;
    }
    if early_continue { return 1; }
    if has_break { return 4; }
    return 2;
}

unsafe void flow_analyze_initialization(
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
    usize function_node,
    text source,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize owner = resolution_find_owner_symbol(
        symbol_data, detail_data, symbols,
        source_record, function_node,
        resolution_symbol_function(), 0
    );
    if owner == 0 { return; }
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_variable() &&
            read_record_field(detail_data, symbol, 2) == owner {
            usize declaration = read_record_field(
                detail_data, symbol, 1
            );
            bool initialized = flow_span_has_byte(
                source,
                read_record_field(syntax_data, declaration, 1),
                read_record_field(syntax_data, declaration, 2), 61
            );
            if !initialized {
                usize declaration_end = read_record_field(
                    syntax_data, declaration, 1
                ) + read_record_field(syntax_data, declaration, 2);
                usize name = 0;
                while name < syntax.length {
                    if read_record_field(syntax_data, name, 0) == 27 &&
                        read_record_field(syntax_data, name, 1) >=
                            declaration_end &&
                        semantic_node_contains(
                            syntax_data, function_node, name
                        ) && !resolution_name_excluded(
                            syntax_data, syntax, name
                        ) && !flow_name_assignment_lhs(
                            syntax_data, syntax, name
                        ) && !flow_name_construct_target(
                            syntax_data, syntax, name
                        ) && !flow_inside_kind(
                            syntax_data, syntax, name, 51
                        ) {
                        usize found = flow_name_symbol(
                            project_source, project_root,
                            module_data, modules, source_data,
                            symbol_data, detail_data, symbols,
                            syntax_data, syntax, module_index, source_record,
                            name, source
                        );
                        if found == symbol {
                            usize assignment = flow_assignment_for_symbol(
                                project_source, project_root,
                                module_data, modules, source_data,
                                symbol_data, detail_data, symbols,
                                syntax_data, syntax,
                                module_index, source_record, symbol,
                                read_record_field(syntax_data, name, 1), source
                            );
                            bool definite = assignment < syntax.length &&
                                flow_control_parent(
                                    syntax_data, syntax, assignment
                                ) >= syntax.length;
                            usize assignment_count =
                                flow_assignment_count_for_symbol(
                                    project_source, project_root,
                                    module_data, modules, source_data,
                                    symbol_data, detail_data, symbols,
                                    syntax_data, syntax,
                                    module_index, source_record, symbol,
                                    read_record_field(syntax_data, name, 1),
                                    source
                                );
                            if assignment_count >= 2 { definite = true; }
                            if flow_out_proof_initializes(
                                syntax_data, syntax, function_node,
                                name, source
                            ) { definite = true; }
                            if !definite {
                                usize repeat = flow_init_repeat(
                                    syntax_data, syntax, assignment
                                );
                                usize index = 0;
                                while index < repeat {
                                    flow_record_error(
                                        error_data, errors, source_record,
                                        read_record_field(syntax_data, name, 1),
                                        read_record_field(syntax_data, name, 2),
                                        flow_phase_flow(), flow_rule_safe_init()
                                    );
                                    index = index + 1;
                                }
                            }
                        }
                    }
                    name = name + 1;
                }
            }
        }
        symbol = symbol + 1;
    }
}
