unsafe void c_consider_slow_function(
    ref BuildTimings target,
    usize milliseconds,
    usize source_record,
    usize node,
    usize symbol,
    usize name_start,
    usize name_length,
    usize statement_candidates,
    usize parent_candidates,
    usize expression_positions,
    usize syntax_candidates,
    usize symbol_candidates
) {
    if milliseconds > target.slow_function_ms {
        target.third_function_ms = target.second_function_ms;
        target.third_function_source = target.second_function_source;
        target.third_function_node = target.second_function_node;
        target.third_function_symbol = target.second_function_symbol;
        target.third_function_name_start = target.second_function_name_start;
        target.third_function_name_length = target.second_function_name_length;
        target.second_function_ms = target.slow_function_ms;
        target.second_function_source = target.slow_function_source;
        target.second_function_node = target.slow_function_node;
        target.second_function_symbol = target.slow_function_symbol;
        target.second_function_name_start = target.slow_function_name_start;
        target.second_function_name_length = target.slow_function_name_length;
        target.slow_function_ms = milliseconds;
        target.slow_function_source = source_record;
        target.slow_function_node = node;
        target.slow_function_symbol = symbol;
        target.slow_function_name_start = name_start;
        target.slow_function_name_length = name_length;
        target.slow_statement_candidates = statement_candidates;
        target.slow_parent_candidates = parent_candidates;
        target.slow_expression_positions = expression_positions;
        target.slow_syntax_candidates = syntax_candidates;
        target.slow_symbol_candidates = symbol_candidates;
    } else if milliseconds > target.second_function_ms {
        target.third_function_ms = target.second_function_ms;
        target.third_function_source = target.second_function_source;
        target.third_function_node = target.second_function_node;
        target.third_function_symbol = target.second_function_symbol;
        target.third_function_name_start = target.second_function_name_start;
        target.third_function_name_length = target.second_function_name_length;
        target.second_function_ms = milliseconds;
        target.second_function_source = source_record;
        target.second_function_node = node;
        target.second_function_symbol = symbol;
        target.second_function_name_start = name_start;
        target.second_function_name_length = name_length;
    } else if milliseconds > target.third_function_ms {
        target.third_function_ms = milliseconds;
        target.third_function_source = source_record;
        target.third_function_node = node;
        target.third_function_symbol = symbol;
        target.third_function_name_start = name_start;
        target.third_function_name_length = name_length;
    }
}

unsafe void c_merge_worker_timings(
    ref BuildTimings target,
    ref BuildTimings worker
) {
    target.lex_parse_ms = target.lex_parse_ms + worker.lex_parse_ms;
    target.index_ms = target.index_ms + worker.index_ms;
    target.ir_lower_ms = target.ir_lower_ms + worker.ir_lower_ms;
    target.c_emit_ms = target.c_emit_ms + worker.c_emit_ms;
    target.syntax_nodes = target.syntax_nodes + worker.syntax_nodes;
    target.functions = target.functions + worker.functions;
    target.instructions = target.instructions + worker.instructions;
    target.total_statement_candidates =
        target.total_statement_candidates +
        worker.total_statement_candidates;
    target.total_parent_candidates = target.total_parent_candidates +
        worker.total_parent_candidates;
    target.total_expression_positions =
        target.total_expression_positions +
        worker.total_expression_positions;
    target.total_syntax_candidates = target.total_syntax_candidates +
        worker.total_syntax_candidates;
    target.total_symbol_candidates = target.total_symbol_candidates +
        worker.total_symbol_candidates;
    c_consider_slow_function(
        target, worker.slow_function_ms,
        worker.slow_function_source, worker.slow_function_node,
        worker.slow_function_symbol, worker.slow_function_name_start,
        worker.slow_function_name_length,
        worker.slow_statement_candidates, worker.slow_parent_candidates,
        worker.slow_expression_positions, worker.slow_syntax_candidates,
        worker.slow_symbol_candidates
    );
    c_consider_slow_function(
        target, worker.second_function_ms,
        worker.second_function_source, worker.second_function_node,
        worker.second_function_symbol, worker.second_function_name_start,
        worker.second_function_name_length, 0, 0, 0, 0, 0
    );
    c_consider_slow_function(
        target, worker.third_function_ms,
        worker.third_function_source, worker.third_function_node,
        worker.third_function_symbol, worker.third_function_name_start,
        worker.third_function_name_length, 0, 0, 0, 0, 0
    );
}
