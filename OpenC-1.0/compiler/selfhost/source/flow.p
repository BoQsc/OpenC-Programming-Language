import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct FlowCounts {
    usize functions;
    usize blocks;
    usize edges;
    usize cleanups;
}

struct FlowCfg {
    usize blocks;
    usize edges;
    bool terminal;
    usize break_depth;
    usize continue_depth;
}

usize flow_phase_name() { return 1; }
usize flow_phase_type() { return 2; }
usize flow_phase_flow() { return 3; }
usize flow_phase_ownership() { return 4; }
usize flow_phase_borrow() { return 5; }
usize flow_phase_unsafe() { return 6; }

usize flow_rule_safe_init() { return 1; }
usize flow_rule_status_duplicate() { return 2; }
usize flow_rule_status_code() { return 3; }
usize flow_rule_out_status() { return 4; }
usize flow_rule_out_carrier() { return 5; }
usize flow_rule_out_function_status() { return 6; }
usize flow_rule_out_return() { return 7; }
usize flow_rule_own_exit() { return 8; }
usize flow_rule_own_overwrite() { return 9; }
usize flow_rule_resource_duplicate_owner() { return 10; }
usize flow_rule_scope_owner_state() { return 11; }
usize flow_rule_own_cleanup_reserved() { return 12; }
usize flow_rule_own_double_discharge() { return 13; }
usize flow_rule_own_use_destroy() { return 14; }
usize flow_rule_own_use_move() { return 15; }
usize flow_rule_lifetime_use_destroy() { return 16; }
usize flow_rule_borrow_move() { return 17; }
usize flow_rule_borrow_conflict() { return 18; }
usize flow_rule_scope_action() { return 19; }
usize flow_rule_scope_nofail() { return 20; }
usize flow_rule_pointer_onepast() { return 21; }
usize flow_rule_pointer_address() { return 22; }
usize flow_rule_pointer_deref() { return 23; }
usize flow_rule_pointer_arithmetic() { return 24; }
usize flow_rule_reinterpret() { return 25; }
usize flow_rule_unsafe_required() { return 26; }
usize flow_rule_unsafe_call() { return 27; }

text flow_phase_text(usize phase) {
    if phase == flow_phase_name() { return "name"; }
    if phase == flow_phase_type() { return "type"; }
    if phase == flow_phase_flow() { return "flow"; }
    if phase == flow_phase_ownership() { return "ownership"; }
    if phase == flow_phase_borrow() { return "borrow"; }
    return "unsafe";
}

text flow_rule_text(usize rule) {
    if rule == flow_rule_safe_init() { return "OPENC-SAFE-INIT-001"; }
    if rule == flow_rule_status_duplicate() { return "OPENC-STATUS-FIELD-DUPLICATE-001"; }
    if rule == flow_rule_status_code() { return "OPENC-STATUS-CODE-001"; }
    if rule == flow_rule_out_status() { return "OPENC-OUT-STATUS-001"; }
    if rule == flow_rule_out_carrier() { return "OPENC-OUT-CARRIER-001"; }
    if rule == flow_rule_out_function_status() { return "OPENC-OUT-FUNCTION-STATUS-001"; }
    if rule == flow_rule_out_return() { return "OPENC-OUT-RETURN-001"; }
    if rule == flow_rule_own_exit() { return "OPENC-OWN-EXIT-001"; }
    if rule == flow_rule_own_overwrite() { return "OPENC-OWN-OVERWRITE-001"; }
    if rule == flow_rule_resource_duplicate_owner() { return "OPENC-RESOURCE-INIT-DUPLICATE-OWNER-001"; }
    if rule == flow_rule_scope_owner_state() { return "OPENC-SCOPE-OWNER-STATE-001"; }
    if rule == flow_rule_own_cleanup_reserved() { return "OPENC-OWN-CLEANUP-RESERVED-001"; }
    if rule == flow_rule_own_double_discharge() { return "OPENC-OWN-DOUBLE-DISCHARGE-001"; }
    if rule == flow_rule_own_use_destroy() { return "OPENC-OWN-USE-AFTER-DESTROY-001"; }
    if rule == flow_rule_own_use_move() { return "OPENC-OWN-USE-AFTER-MOVE-001"; }
    if rule == flow_rule_lifetime_use_destroy() { return "OPENC-LIFETIME-USE-AFTER-DESTROY-001"; }
    if rule == flow_rule_borrow_move() { return "OPENC-BORROW-MOVE-001"; }
    if rule == flow_rule_borrow_conflict() { return "OPENC-BORROW-CONFLICT-001"; }
    if rule == flow_rule_scope_action() { return "OPENC-SCOPE-ACTION-001"; }
    if rule == flow_rule_scope_nofail() { return "OPENC-SCOPE-NOFAIL-001"; }
    if rule == flow_rule_pointer_onepast() { return "OPENC-PTR-ONEPAST-001"; }
    if rule == flow_rule_pointer_address() { return "OPENC-PTR-ADDRESS-UNSAFE-001"; }
    if rule == flow_rule_pointer_deref() { return "OPENC-PTR-DEREF-UNSAFE-001"; }
    if rule == flow_rule_pointer_arithmetic() { return "OPENC-PTR-ARITH-UNSAFE-001"; }
    if rule == flow_rule_reinterpret() { return "OPENC-REINTERPRET-UNSAFE-001"; }
    if rule == flow_rule_unsafe_required() { return "OPENC-UNSAFE-REQUIRED-001"; }
    return "OPENC-UNSAFE-CALL-001";
}

unsafe void flow_record_error(
    ptr byte error_data,
    ref PackedBuffer errors,
    usize source_record,
    usize start,
    usize length,
    usize phase,
    usize rule
) {
    usize record = errors.length;
    write_record_field(error_data, record, 0, source_record);
    write_record_field(error_data, record, 1, start);
    write_record_field(error_data, record, 2, length);
    write_record_field(error_data, record, 3, rule);
    write_record_field(error_data, record, 4, phase);
    errors.length = errors.length + 1;
}

bool flow_statement_kind(usize kind) {
    return kind >= 11 && kind <= 25;
}

bool flow_expression_kind(usize kind) {
    return kind >= 27 && kind <= 51;
}

unsafe usize flow_smallest_block_parent(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize child
) {
    usize selected = syntax.length;
    usize selected_length = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if record != child && read_record_field(syntax_data, record, 0) == 11 &&
            semantic_node_contains(syntax_data, record, child) {
            usize length = read_record_field(syntax_data, record, 2);
            if length < selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_largest_direct_block(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize parent
) {
    usize selected = syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 11 &&
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

unsafe usize flow_control_parent(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize child
) {
    usize first = resolution_smallest_parent(
        syntax_data, syntax, child, 14, 15, 16
    );
    usize second = resolution_smallest_parent(
        syntax_data, syntax, child, 17, 18, 19
    );
    usize third = resolution_smallest_parent(
        syntax_data, syntax, child, 24, 25, 999
    );
    usize selected = first;
    if second < syntax.length &&
        (selected >= syntax.length ||
         read_record_field(syntax_data, second, 2) <
         read_record_field(syntax_data, selected, 2)) {
        selected = second;
    }
    if third < syntax.length &&
        (selected >= syntax.length ||
         read_record_field(syntax_data, third, 2) <
         read_record_field(syntax_data, selected, 2)) {
        selected = third;
    }
    return selected;
}

unsafe usize flow_next_direct_statement(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize block,
    usize after_start,
    usize after_record
) {
    usize selected = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize selected_record = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        if flow_statement_kind(kind) && record != block &&
            flow_smallest_block_parent(syntax_data, syntax, record) == block &&
            (kind != 11 || flow_control_parent(
                syntax_data, syntax, record
            ) >= syntax.length) &&
            (start > after_start || (start == after_start && record > after_record)) &&
            (selected == syntax.length || start < selected_start ||
             (start == selected_start && record < selected_record)) {
            selected = record;
            selected_start = start;
            selected_record = record;
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize flow_direct_control_count(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize parent,
    usize requested_kind
) {
    usize count = 0;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == requested_kind &&
            semantic_node_contains(syntax_data, parent, record) {
            usize nearest = resolution_smallest_parent(
                syntax_data, syntax, record, 14, 15, 16
            );
            usize switch_parent = resolution_smallest_parent(
                syntax_data, syntax, record, 17, 24, 25
            );
            usize chosen = nearest;
            if switch_parent < syntax.length &&
                (chosen >= syntax.length ||
                 read_record_field(syntax_data, switch_parent, 2) <
                 read_record_field(syntax_data, chosen, 2)) {
                chosen = switch_parent;
            }
            if chosen == parent { count = count + 1; }
        }
        record = record + 1;
    }
    return count;
}

unsafe void flow_build_block_counts(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize block,
    ref FlowCfg cfg
) {
    usize previous_start = 0;
    usize previous_record = 0;
    bool first = true;
    while true {
        usize requested_start = previous_start;
        usize requested_record = previous_record;
        if first {
            requested_start = 0;
            requested_record = 0;
        }
        usize statement = flow_next_direct_statement(
            syntax_data, syntax, block,
            requested_start,
            requested_record
        );
        if statement >= syntax.length { break; }
        if cfg.terminal {
            cfg.blocks = cfg.blocks + 1;
            cfg.terminal = false;
        }
        usize kind = read_record_field(syntax_data, statement, 0);
        if kind == 11 {
            flow_build_block_counts(syntax_data, syntax, statement, cfg);
        } else if kind == 14 {
            usize block_count = flow_direct_control_count(
                syntax_data, syntax, statement, 11
            );
            cfg.blocks = cfg.blocks + 2;
            if block_count > 1 { cfg.blocks = cfg.blocks + 1; }
            cfg.edges = cfg.edges + 2;
            usize record = 0;
            usize seen = 0;
            while record < syntax.length {
                if read_record_field(syntax_data, record, 0) == 11 &&
                    semantic_node_contains(syntax_data, statement, record) &&
                    block_count > seen {
                    usize control = resolution_smallest_parent(
                        syntax_data, syntax, record, 14, 15, 16
                    );
                    if control == statement {
                        cfg.terminal = false;
                        flow_build_block_counts(
                            syntax_data, syntax, record, cfg
                        );
                        if !cfg.terminal { cfg.edges = cfg.edges + 1; }
                        seen = seen + 1;
                    }
                }
                record = record + 1;
            }
            cfg.terminal = false;
        } else if kind == 15 {
            cfg.blocks = cfg.blocks + 3;
            cfg.edges = cfg.edges + 3;
            usize body = flow_largest_direct_block(
                syntax_data, syntax, statement
            );
            cfg.break_depth = cfg.break_depth + 1;
            cfg.continue_depth = cfg.continue_depth + 1;
            cfg.terminal = false;
            if body < syntax.length {
                flow_build_block_counts(syntax_data, syntax, body, cfg);
            }
            if !cfg.terminal { cfg.edges = cfg.edges + 1; }
            cfg.break_depth = cfg.break_depth - 1;
            cfg.continue_depth = cfg.continue_depth - 1;
            cfg.terminal = false;
        } else if kind == 16 {
            cfg.blocks = cfg.blocks + 4;
            cfg.edges = cfg.edges + 5;
            usize body = flow_largest_direct_block(
                syntax_data, syntax, statement
            );
            cfg.break_depth = cfg.break_depth + 1;
            cfg.continue_depth = cfg.continue_depth + 1;
            cfg.terminal = false;
            if body < syntax.length {
                flow_build_block_counts(syntax_data, syntax, body, cfg);
            }
            cfg.break_depth = cfg.break_depth - 1;
            cfg.continue_depth = cfg.continue_depth - 1;
            cfg.terminal = false;
        } else if kind == 17 {
            usize cases = flow_direct_control_count(
                syntax_data, syntax, statement, 18
            ) + flow_direct_control_count(
                syntax_data, syntax, statement, 19
            );
            cfg.blocks = cfg.blocks + 1 + cases;
            cfg.edges = cfg.edges + cases;
            cfg.break_depth = cfg.break_depth + 1;
            usize record = 0;
            while record < syntax.length {
                usize child_kind = read_record_field(
                    syntax_data, record, 0
                );
                if (child_kind == 18 || child_kind == 19) &&
                    semantic_node_contains(
                        syntax_data, statement, record
                    ) {
                    usize body = flow_largest_direct_block(
                        syntax_data, syntax, record
                    );
                    cfg.terminal = false;
                    if body < syntax.length {
                        flow_build_block_counts(
                            syntax_data, syntax, body, cfg
                        );
                    }
                    if !cfg.terminal { cfg.edges = cfg.edges + 1; }
                }
                record = record + 1;
            }
            cfg.break_depth = cfg.break_depth - 1;
            cfg.terminal = false;
        } else if kind == 22 {
            cfg.edges = cfg.edges + 1;
            cfg.terminal = true;
        } else if kind == 20 {
            if cfg.break_depth != 0 { cfg.edges = cfg.edges + 1; }
            cfg.terminal = true;
        } else if kind == 21 {
            if cfg.continue_depth != 0 { cfg.edges = cfg.edges + 1; }
            cfg.terminal = true;
        }
        previous_start = read_record_field(syntax_data, statement, 1);
        previous_record = statement;
        first = false;
    }
}

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
        if record != function_node && semantic_node_contains(
            syntax_data, function_node, record
        ) && !flow_inside_unsafe(
            source, syntax_data, syntax, function_node, record
        ) {
            usize kind = read_record_field(syntax_data, record, 0);
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

unsafe usize flow_emit_cleanups(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    usize function_index
) {
    usize count = 0;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 23 &&
            semantic_node_contains(syntax_data, function_node, record) {
            usize action = flow_root_expression(syntax_data, syntax, record);
            if action < syntax.length {
                io.print("CLEANUP ");
                io.print(function_index);
                io.print(" ");
                io.print(count);
                io.print(" ");
                io.print(read_record_field(syntax_data, action, 1));
                io.print(" ");
                io.println(read_record_field(syntax_data, action, 2));
                count = count + 1;
            }
        }
        record = record + 1;
    }
    return count;
}

unsafe usize flow_source_frontend_errors(text source) {
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
    lex_source(
        source, token_data, tokens, diagnostic_data, diagnostics
    );
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
    return diagnostics.length;
}

unsafe usize flow_name_symbol(
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
    usize name,
    text source
) {
    return resolution_find_name(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        name, source
    );
}

unsafe usize flow_call_selection(
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
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length ||
        read_record_field(syntax_data, callee, 0) != 27 {
        return symbols.length;
    }
    usize first = flow_name_symbol(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        callee, source
    );
    if first >= symbols.length { return symbols.length; }
    ResolutionCallSelection selection = resolution_select_call(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, symbol_data, detail_data, symbols,
        token_data, tokens, syntax_data, syntax,
        module_index, source_record, call, source, first
    );
    if selection.ambiguous { return symbols.length; }
    return selection.symbol;
}

unsafe usize flow_call_declared_target(
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
    usize call,
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length { return symbols.length; }
    return flow_name_symbol(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        callee, source
    );
}

unsafe bool flow_call_is_memory_free(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize call,
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length { return false; }
    usize start = read_record_field(syntax_data, callee, 1);
    usize length = read_record_field(syntax_data, callee, 2);
    return span_equals_ascii(source, start, length, "memory.free") ||
        span_equals_ascii(source, start, length, "system.memory.free");
}

unsafe bool flow_symbol_unsafe(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    usize symbol
) {
    if read_record_field(symbol_data, symbol, 0) !=
        resolution_symbol_function() { return false; }
    text declaration_source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1), out declaration_source
    );
    if !loaded.ok { return false; }
    usize packed = read_record_field(detail_data, symbol, 4);
    usize start = resolution_span_start(packed);
    usize name_start = read_record_field(symbol_data, symbol, 2);
    usize cursor = start;
    while cursor + 6 <= name_start {
        if starts_with_ascii(declaration_source, cursor, "unsafe") {
            return true;
        }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_parameter_own(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    usize parameter
) {
    text declaration_source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, parameter, 1), out declaration_source
    );
    if !loaded.ok { return false; }
    usize packed = read_record_field(detail_data, parameter, 4);
    usize start = resolution_span_start(packed);
    usize name_start = read_record_field(symbol_data, parameter, 2);
    usize cursor = start;
    while cursor + 3 <= name_start {
        if starts_with_ascii(declaration_source, cursor, "own") {
            return true;
        }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_symbol_resource_type(
    ptr byte type_data,
    ptr byte symbol_data,
    usize symbol
) {
    usize type_id = read_record_field(symbol_data, symbol, 4);
    return semantic_type_resource(type_data, type_id);
}

unsafe usize flow_call_argument_name(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize call,
    usize requested
) {
    usize callee = read_record_field(syntax_data, call, 3);
    usize selected = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize index = 0;
    while true {
        selected = syntax.length;
        selected_start = cast(usize, 4294967295);
        usize record = 0;
        while record < syntax.length {
            if record != callee &&
                read_record_field(syntax_data, record, 0) == 27 &&
                semantic_node_contains(syntax_data, call, record) {
                usize start = read_record_field(syntax_data, record, 1);
                usize callee_start = read_record_field(
                    syntax_data, callee, 1
                );
                if start > callee_start && start < selected_start {
                    bool already = false;
                    usize earlier = 0;
                    while earlier < syntax.length {
                        if earlier != record && earlier != callee &&
                            read_record_field(syntax_data, earlier, 0) == 27 &&
                            semantic_node_contains(syntax_data, call, earlier) &&
                            read_record_field(syntax_data, earlier, 1) > callee_start &&
                            read_record_field(syntax_data, earlier, 1) < start {
                            already = true;
                        }
                        earlier = earlier + 1;
                    }
                    if (index == 0 && !already) || index != 0 {
                        selected = record;
                        selected_start = start;
                    }
                }
            }
            record = record + 1;
        }
        if index == requested { return selected; }
        if selected >= syntax.length { return syntax.length; }
        index = index + 1;
    }
    return syntax.length;
}

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
        if semantic_node_contains(syntax_data, function_node, record) &&
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
            if selected >= symbols.length ||
                read_record_field(symbol_data, selected, 4) !=
                    semantic_type_status() {
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
                            usize owner = flow_name_symbol(
                                project_source, project_root,
                                module_data, modules, source_data,
                                symbol_data, detail_data, symbols,
                                syntax_data, syntax,
                                module_index, source_record, argument, source
                            );
                            if owner < symbols.length &&
                                flow_state_get(state_data, owner) != 0 {
                                flow_move_owner(
                                    state_data, owner, source_record, argument,
                                    syntax_data, error_data, errors
                                );
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

unsafe void flow_observe_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_index,
    usize source_record,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors,
    ref FlowCounts counts
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
                FlowCfg cfg = FlowCfg{
                    blocks = 2, edges = 0, terminal = false,
                    break_depth = 0, continue_depth = 0
                };
                flow_build_block_counts(
                    syntax_data, syntax, body, cfg
                );
                if !cfg.terminal { cfg.edges = cfg.edges + 1; }
                io.print("FUNCTION ");
                io.print(counts.functions);
                io.print(" ");
                io.print(module_index);
                io.print(" ");
                io.print(source_index);
                io.print(" ");
                io.print(read_record_field(syntax_data, function_node, 1));
                io.print(" ");
                io.print(read_record_field(syntax_data, function_node, 2));
                io.print(" ");
                project_emit_hex(project_slice(
                    source,
                    read_record_field(syntax_data, function_node, 3),
                    read_record_field(syntax_data, function_node, 4)
                ));
                io.print(" ");
                io.print(cfg.blocks);
                io.print(" ");
                io.println(cfg.edges);

                usize cleanups = flow_emit_cleanups(
                    syntax_data, syntax, function_node, counts.functions
                );
                counts.blocks = counts.blocks + cfg.blocks;
                counts.edges = counts.edges + cfg.edges;
                counts.cleanups = counts.cleanups + cleanups;

                flow_analyze_initialization(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                flow_analyze_status_out(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                flow_analyze_ownership(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                flow_analyze_borrows(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                flow_analyze_cleanup(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                flow_analyze_pointer_facts(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                // These are the owned unsafe-boundary analyzers; the
                // precheck pass models the type-check diagnostics.
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
                flow_check_unsafe_calls(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                counts.functions = counts.functions + 1;
            }
        }
        function_node = function_node + 1;
    }
}

// Run the owned flow/safety analyzers without emitting observation records.
// The canonical-IR command uses this entry point so semantic rejection is a
// property of the self-hosted compiler, rather than a parity-harness fallback.
unsafe void flow_validate_source(
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
        syntax_data, syntax, diagnostic_data, diagnostics
    );

    usize function_node = 0;
    while function_node < syntax.length {
        if read_record_field(syntax_data, function_node, 0) == 2 {
            usize body = flow_largest_direct_block(
                syntax_data, syntax, function_node
            );
            if body < syntax.length &&
                read_record_field(syntax_data, body, 2) > 1 {
                flow_analyze_initialization(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                flow_analyze_status_out(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                flow_analyze_ownership(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                flow_analyze_borrows(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                flow_analyze_cleanup(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                flow_analyze_pointer_facts(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
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
                flow_check_unsafe_calls(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
            }
        }
        function_node = function_node + 1;
    }
}

unsafe void flow_emit_errors(
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte error_data,
    ref PackedBuffer errors
) {
    usize error = 0;
    while error < errors.length {
        usize source_record = read_record_field(error_data, error, 0);
        usize error_module = semantic_source_module(
            module_data, modules, source_record
        );
        usize source_first = read_record_field(
            module_data, error_module, 2
        );
        io.print("ERROR ");
        io.print(error);
        io.print(" ");
        io.print(flow_phase_text(
            read_record_field(error_data, error, 4)
        ));
        io.print(" ");
        io.print(flow_rule_text(
            read_record_field(error_data, error, 3)
        ));
        io.print(" ");
        io.print(error_module);
        io.print(" ");
        io.print(source_record - source_first);
        io.print(" ");
        io.print(read_record_field(error_data, error, 1));
        io.print(" ");
        io.println(read_record_field(error_data, error, 2));
        error = error + 1;
    }
}

unsafe i32 observe_semantic_flow_safety(text project_path) {
    io.println("OPENC-SEMANTIC-FLOW-SAFETY-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 0 1");
        return 1;
    }
    usize project_length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{
        length = 0, capacity = project_length + 1
    };
    PackedBuffer sources = PackedBuffer{
        length = 0, capacity = project_length + 1
    };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    if !project_parse_json(
        project_source, module_data, modules, source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 0 1");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize frontend_errors = 0;
    usize module_index = 0;
    while module_index < modules.length {
        io.print("MODULE ");
        io.print(module_index);
        io.print(" ");
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print(" ");
        io.println(read_record_field(module_data, module_index, 3));
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status source_status = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !source_status.ok {
                io.print("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ");
                io.print(module_index);
                io.print(" ");
                io.println(source_index);
                io.print("SUMMARY ");
                io.print(modules.length);
                io.println(" 0 0 0 0 0 1");
                return 1;
            }
            total_source_length = total_source_length +
                text.byte_length(source);
            frontend_errors = frontend_errors +
                flow_source_frontend_errors(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if frontend_errors != 0 {
        io.print("FRONTEND_ERROR ");
        io.println(frontend_errors);
        io.print("SUMMARY ");
        io.print(modules.length);
        io.print(" ");
        io.print(sources.length);
        io.print(" 0 0 0 0 ");
        io.println(frontend_errors);
        return 1;
    }

    usize capacity = total_source_length * 4 + project_length + 256;
    PackedBuffer types = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer symbols = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer errors = PackedBuffer{ length = 0, capacity = capacity };
    ptr byte type_data = memory.alloc(types.capacity * record_stride());
    scope memory.free(type_data);
    ptr byte symbol_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(symbol_data);
    ptr byte detail_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(detail_data);
    ptr byte error_data = memory.alloc(errors.capacity * record_stride());
    scope memory.free(error_data);
    semantic_initialize_types(type_data, types);

    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            semantic_predeclare_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            resolution_collect_source_symbols(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types,
                symbol_data, detail_data, symbols
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            flow_precheck_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    FlowCounts counts = FlowCounts{
        functions = 0, blocks = 0, edges = 0, cleanups = 0
    };
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            flow_observe_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    flow_emit_errors(module_data, modules, error_data, errors);
    io.print("SUMMARY ");
    io.print(modules.length);
    io.print(" ");
    io.print(sources.length);
    io.print(" ");
    io.print(counts.functions);
    io.print(" ");
    io.print(counts.blocks);
    io.print(" ");
    io.print(counts.edges);
    io.print(" ");
    io.print(counts.cleanups);
    io.print(" ");
    io.println(errors.length);
    if errors.length != 0 { return 1; }
    return 0;
}
