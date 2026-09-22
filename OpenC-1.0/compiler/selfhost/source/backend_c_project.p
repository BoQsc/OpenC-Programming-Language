import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void c_release_source_context(
    ref IrContext context,
    ptr byte diagnostic_data
) {
    memory.free(context.continue_data);
    memory.free(context.break_data);
    memory.free(context.top_symbols);
    memory.free(context.declaration_symbol_cache);
    memory.free(context.type_ref_nodes);
    memory.free(context.name_nodes);
    memory.free(context.expression_next_start);
    memory.free(context.expression_start_next);
    memory.free(context.expression_start_heads);
    memory.free(context.function_at_position);
    memory.free(context.call_nodes);
    memory.free(context.expression_nodes);
    memory.free(context.control_nodes);
    memory.free(context.block_nodes);
    memory.free(context.control_child_next);
    memory.free(context.control_child_first);
    memory.free(context.block_next);
    memory.free(context.control_block_first);
    memory.free(context.statement_next);
    memory.free(context.block_statement_first);
    memory.free(context.array_element_next);
    memory.free(context.array_element_first);
    memory.free(context.initializer_field_owner);
    memory.free(context.initializer_field_next);
    memory.free(context.initializer_field_first);
    memory.free(context.statement_nodes);
    memory.free(context.control_parent_cache);
    memory.free(context.block_parent_cache);
    memory.free(context.right_expression_cache);
    memory.free(context.left_expression_cache);
    memory.free(context.resolved_type_ref_cache);
    memory.free(context.type_cache);
    memory.free(context.argument_next);
    memory.free(context.call_argument_last);
    memory.free(context.call_argument_first);
    memory.free(context.call_cache);
    memory.free(context.spelling_cache);
    memory.free(context.name_cache);
    memory.free(context.local_values);
    memory.free(context.operand_data);
    memory.free(context.instruction_detail);
    memory.free(context.instruction_data);
    memory.free(context.block_data);
    memory.free(context.syntax_data);
    memory.free(diagnostic_data);
    memory.free(context.token_data);
}

unsafe void c_record_lowered_function(
    ref BuildTimings timings,
    ref IrContext context,
    usize source_record,
    usize node,
    usize symbol,
    usize function_ir_ms
) {
    timings.ir_lower_ms = timings.ir_lower_ms + function_ir_ms;
    timings.total_statement_candidates =
        timings.total_statement_candidates +
        context.profile_statement_candidates;
    timings.total_parent_candidates =
        timings.total_parent_candidates +
        context.profile_parent_candidates;
    timings.total_expression_positions =
        timings.total_expression_positions +
        context.profile_expression_positions;
    timings.total_syntax_candidates =
        timings.total_syntax_candidates +
        context.profile_syntax_candidates;
    timings.total_symbol_candidates =
        timings.total_symbol_candidates +
        context.profile_symbol_candidates;
    usize function_name_start = read_record_field(
        context.symbol_data, symbol, 2
    );
    usize function_name_length = read_record_field(
        context.symbol_data, symbol, 3
    );
    if function_ir_ms > timings.slow_function_ms {
        timings.third_function_ms = timings.second_function_ms;
        timings.third_function_source = timings.second_function_source;
        timings.third_function_node = timings.second_function_node;
        timings.third_function_symbol = timings.second_function_symbol;
        timings.third_function_name_start =
            timings.second_function_name_start;
        timings.third_function_name_length =
            timings.second_function_name_length;
        timings.second_function_ms = timings.slow_function_ms;
        timings.second_function_source = timings.slow_function_source;
        timings.second_function_node = timings.slow_function_node;
        timings.second_function_symbol = timings.slow_function_symbol;
        timings.second_function_name_start =
            timings.slow_function_name_start;
        timings.second_function_name_length =
            timings.slow_function_name_length;
        timings.slow_function_ms = function_ir_ms;
        timings.slow_function_source = source_record;
        timings.slow_function_node = node;
        timings.slow_function_symbol = symbol;
        timings.slow_function_name_start = function_name_start;
        timings.slow_function_name_length = function_name_length;
        timings.slow_statement_candidates =
            context.profile_statement_candidates;
        timings.slow_parent_candidates =
            context.profile_parent_candidates;
        timings.slow_expression_positions =
            context.profile_expression_positions;
        timings.slow_syntax_candidates =
            context.profile_syntax_candidates;
        timings.slow_symbol_candidates =
            context.profile_symbol_candidates;
    } else if function_ir_ms > timings.second_function_ms {
        timings.third_function_ms = timings.second_function_ms;
        timings.third_function_source = timings.second_function_source;
        timings.third_function_node = timings.second_function_node;
        timings.third_function_symbol = timings.second_function_symbol;
        timings.third_function_name_start =
            timings.second_function_name_start;
        timings.third_function_name_length =
            timings.second_function_name_length;
        timings.second_function_ms = function_ir_ms;
        timings.second_function_source = source_record;
        timings.second_function_node = node;
        timings.second_function_symbol = symbol;
        timings.second_function_name_start = function_name_start;
        timings.second_function_name_length = function_name_length;
    } else if function_ir_ms > timings.third_function_ms {
        timings.third_function_ms = function_ir_ms;
        timings.third_function_source = source_record;
        timings.third_function_node = node;
        timings.third_function_symbol = symbol;
        timings.third_function_name_start = function_name_start;
        timings.third_function_name_length = function_name_length;
    }
    timings.functions = timings.functions + 1;
    timings.instructions = timings.instructions +
        context.instructions.length;
}

unsafe void c_lower_and_emit_function(
    ref IrContext context,
    ref DBuffer output,
    ref BuildTimings timings,
    usize source_record,
    usize node,
    usize owner,
    usize entry_module
) {
    context.profile_statement_candidates = 0;
    context.profile_parent_candidates = 0;
    context.profile_expression_positions = 0;
    context.profile_syntax_candidates = 0;
    context.profile_symbol_candidates = 0;
    usize phase_started = process.monotonic_milliseconds();
    ir_lower_function(context, node, owner - 1);
    usize function_ir_ms =
        process.monotonic_milliseconds() - phase_started;
    c_record_lowered_function(
        timings, context, source_record, node, owner - 1,
        function_ir_ms
    );
    phase_started = process.monotonic_milliseconds();
    if timings.emission_mode == 1 {
        native_audit_function(context, output, owner - 1, timings.functions);
    } else if timings.emission_mode == 2 {
        native_emit_function(context, output, timings, owner - 1, entry_module);
    } else {
        c_emit_function(context, output, owner - 1, entry_module);
    }
    timings.c_emit_ms = timings.c_emit_ms +
        process.monotonic_milliseconds() - phase_started;
}
