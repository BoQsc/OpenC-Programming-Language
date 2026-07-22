import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
        if flow_statement_kind(kind) && record != block {
            usize block_parent = flow_smallest_block_parent(
                syntax_data, syntax, record
            );
            if block_parent == block {
                usize control_parent = flow_control_parent(
                    syntax_data, syntax, record
                );
                bool direct_control = control_parent >= syntax.length;
                if !direct_control {
                    direct_control = flow_smallest_block_parent(
                        syntax_data, syntax, control_parent
                    ) != block;
                }
                if direct_control &&
                    (start > after_start ||
                     (start == after_start && record > after_record)) &&
                    (selected == syntax.length || start < selected_start ||
                     (start == selected_start && record < selected_record)) {
                    selected = record;
                    selected_start = start;
                    selected_record = record;
                }
            }
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
