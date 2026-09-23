import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct BuildTimings {
    usize emission_mode;
    usize project_load_ms;
    usize declarations_ms;
    usize resolution_ms;
    usize validation_ms;
    usize lowering_emit_ms;
    usize parallel_source_chunks;
    bool native_parallel_launch_completed;
    usize native_workers_wall_ms;
    usize native_merge_ms;
    usize native_critical_chunk_ms;
    usize native_critical_chunk_first;
    usize native_critical_chunk_end;
    usize native_critical_lex_parse_ms;
    usize native_critical_index_ms;
    usize native_critical_acceptance_ms;
    usize native_critical_expression_ms;
    usize native_critical_assignment_ms;
    usize native_critical_calls_ms;
    usize native_critical_ir_lower_ms;
    usize native_critical_emit_ms;
    usize native_critical_type_queries;
    usize native_critical_type_cache_hits;
    usize native_critical_type_uncached;
    usize native_critical_type_failures;
    usize native_critical_assignment_type_queries;
    usize native_critical_assignment_type_cache_hits;
    usize native_critical_assignment_type_uncached;
    usize parallel_flow_workers;
    bool flow_threads_launched;
    bool auto_source_chunks;
    usize backend_ms;
    usize total_ms;
    usize source_files;
    usize source_bytes;
    usize lex_parse_ms;
    usize index_ms;
    usize index_nodes_ms;
    usize index_parents_ms;
    usize index_statements_ms;
    usize index_function_positions_ms;
    usize ir_lower_ms;
    usize c_emit_ms;
    usize syntax_nodes;
    usize functions;
    usize instructions;
    usize output_bytes;
    usize native_code_reserved_bytes;
    usize native_code_used_bytes;
    usize native_relocation_reserved_records;
    usize native_relocation_used_records;
    usize native_constant_reserved_bytes;
    usize native_constant_used_bytes;
    usize slow_function_ms;
    usize slow_function_source;
    usize slow_function_node;
    usize slow_function_symbol;
    usize slow_function_name_start;
    usize slow_function_name_length;
    usize second_function_ms;
    usize second_function_source;
    usize second_function_node;
    usize second_function_symbol;
    usize second_function_name_start;
    usize second_function_name_length;
    usize third_function_ms;
    usize third_function_source;
    usize third_function_node;
    usize third_function_symbol;
    usize third_function_name_start;
    usize third_function_name_length;
    usize slow_statement_candidates;
    usize slow_parent_candidates;
    usize slow_expression_positions;
    usize slow_syntax_candidates;
    usize slow_symbol_candidates;
    usize total_statement_candidates;
    usize total_parent_candidates;
    usize total_expression_positions;
    usize total_syntax_candidates;
    usize total_symbol_candidates;
    usize validation_initial_live_bytes;
    usize validation_peak_live_bytes;
    usize validation_peak_source_record;
    usize validation_file_cache_hits;
    usize validation_file_cache_misses;
    usize validation_path_cache_hits;
    usize validation_path_cache_misses;
    usize validation_flow_ms;
    usize validation_flow_parse_ms;
    usize validation_flow_initialization_ms;
    usize validation_flow_status_out_ms;
    usize validation_flow_ownership_ms;
    usize validation_flow_borrows_ms;
    usize validation_flow_cleanup_ms;
    usize validation_flow_pointer_facts_ms;
    usize validation_flow_unsafe_function_ms;
    usize validation_flow_pointer_arithmetic_ms;
    usize validation_flow_scope_actions_ms;
    usize validation_flow_unsafe_calls_ms;
    usize validation_acceptance_ms;
    usize validation_acceptance_mask_ms;
    usize validation_acceptance_types_ms;
    usize validation_acceptance_expressions_ms;
    usize validation_acceptance_assignments_ms;
    usize validation_acceptance_functions_ms;
    usize validation_acceptance_calls_ms;
    usize validation_acceptance_overload_calls_ms;
    usize validation_acceptance_slice_aliases_ms;
    usize validation_acceptance_call_rules_ms;
    usize validation_acceptance_resources_ms;
    usize validation_acceptance_pointers_ms;
    usize validation_acceptance_errors;
    bool profile_type_queries_enabled;
    usize validation_type_queries;
    usize validation_type_cache_hits;
    usize validation_type_uncached;
    usize validation_type_failures;
    usize validation_assignment_type_queries;
    usize validation_assignment_type_cache_hits;
    usize validation_assignment_type_uncached;
    usize validation_slowest_source_ms;
    usize validation_slowest_source_record;
    usize validation_second_source_ms;
    usize validation_second_source_record;
    usize validation_third_source_ms;
    usize validation_third_source_record;
    usize validation_statement_candidates;
    usize validation_parent_candidates;
    usize validation_expression_positions;
    usize validation_syntax_candidates;
    usize validation_symbol_candidates;
}

BuildTimings build_timings_empty() {
    return BuildTimings{
        emission_mode = 0,
        project_load_ms = 0,
        declarations_ms = 0,
        resolution_ms = 0,
        validation_ms = 0,
        lowering_emit_ms = 0,
        parallel_source_chunks = 0,
        native_parallel_launch_completed = false,
        native_workers_wall_ms = 0,
        native_merge_ms = 0,
        native_critical_chunk_ms = 0,
        native_critical_chunk_first = 0,
        native_critical_chunk_end = 0,
        native_critical_lex_parse_ms = 0,
        native_critical_index_ms = 0,
        native_critical_acceptance_ms = 0,
        native_critical_expression_ms = 0,
        native_critical_assignment_ms = 0,
        native_critical_calls_ms = 0,
        native_critical_ir_lower_ms = 0,
        native_critical_emit_ms = 0,
        native_critical_type_queries = 0,
        native_critical_type_cache_hits = 0,
        native_critical_type_uncached = 0,
        native_critical_type_failures = 0,
        native_critical_assignment_type_queries = 0,
        native_critical_assignment_type_cache_hits = 0,
        native_critical_assignment_type_uncached = 0,
        parallel_flow_workers = 0,
        flow_threads_launched = false,
        auto_source_chunks = false,
        backend_ms = 0,
        total_ms = 0,
        source_files = 0,
        source_bytes = 0,
        lex_parse_ms = 0,
        index_ms = 0,
        index_nodes_ms = 0,
        index_parents_ms = 0,
        index_statements_ms = 0,
        index_function_positions_ms = 0,
        ir_lower_ms = 0,
        c_emit_ms = 0,
        syntax_nodes = 0,
        functions = 0,
        instructions = 0,
        output_bytes = 0,
        native_code_reserved_bytes = 0,
        native_code_used_bytes = 0,
        native_relocation_reserved_records = 0,
        native_relocation_used_records = 0,
        native_constant_reserved_bytes = 0,
        native_constant_used_bytes = 0,
        slow_function_ms = 0,
        slow_function_source = 0,
        slow_function_node = 0,
        slow_function_symbol = 0,
        slow_function_name_start = 0,
        slow_function_name_length = 0,
        second_function_ms = 0,
        second_function_source = 0,
        second_function_node = 0,
        second_function_symbol = 0,
        second_function_name_start = 0,
        second_function_name_length = 0,
        third_function_ms = 0,
        third_function_source = 0,
        third_function_node = 0,
        third_function_symbol = 0,
        third_function_name_start = 0,
        third_function_name_length = 0,
        slow_statement_candidates = 0,
        slow_parent_candidates = 0,
        slow_expression_positions = 0,
        slow_syntax_candidates = 0,
        slow_symbol_candidates = 0,
        total_statement_candidates = 0,
        total_parent_candidates = 0,
        total_expression_positions = 0,
        total_syntax_candidates = 0,
        total_symbol_candidates = 0,
        validation_initial_live_bytes = 0,
        validation_peak_live_bytes = 0,
        validation_peak_source_record = 0,
        validation_file_cache_hits = 0,
        validation_file_cache_misses = 0,
        validation_path_cache_hits = 0,
        validation_path_cache_misses = 0,
        validation_flow_ms = 0,
        validation_flow_parse_ms = 0,
        validation_flow_initialization_ms = 0,
        validation_flow_status_out_ms = 0,
        validation_flow_ownership_ms = 0,
        validation_flow_borrows_ms = 0,
        validation_flow_cleanup_ms = 0,
        validation_flow_pointer_facts_ms = 0,
        validation_flow_unsafe_function_ms = 0,
        validation_flow_pointer_arithmetic_ms = 0,
        validation_flow_scope_actions_ms = 0,
        validation_flow_unsafe_calls_ms = 0,
        validation_acceptance_ms = 0,
        validation_acceptance_mask_ms = 0,
        validation_acceptance_types_ms = 0,
        validation_acceptance_expressions_ms = 0,
        validation_acceptance_assignments_ms = 0,
        validation_acceptance_functions_ms = 0,
        validation_acceptance_calls_ms = 0,
        validation_acceptance_overload_calls_ms = 0,
        validation_acceptance_slice_aliases_ms = 0,
        validation_acceptance_call_rules_ms = 0,
        validation_acceptance_resources_ms = 0,
        validation_acceptance_pointers_ms = 0,
        validation_acceptance_errors = 0,
        profile_type_queries_enabled = false,
        validation_type_queries = 0,
        validation_type_cache_hits = 0,
        validation_type_uncached = 0,
        validation_type_failures = 0,
        validation_assignment_type_queries = 0,
        validation_assignment_type_cache_hits = 0,
        validation_assignment_type_uncached = 0,
        validation_slowest_source_ms = 0,
        validation_slowest_source_record = 0,
        validation_second_source_ms = 0,
        validation_second_source_record = 0,
        validation_third_source_ms = 0,
        validation_third_source_record = 0,
        validation_statement_candidates = 0,
        validation_parent_candidates = 0,
        validation_expression_positions = 0,
        validation_syntax_candidates = 0,
        validation_symbol_candidates = 0
    };
}

void build_timings_record_validation_source(
    ref BuildTimings timings,
    usize source_record,
    usize elapsed_ms
) {
    if elapsed_ms > timings.validation_slowest_source_ms {
        timings.validation_third_source_ms =
            timings.validation_second_source_ms;
        timings.validation_third_source_record =
            timings.validation_second_source_record;
        timings.validation_second_source_ms =
            timings.validation_slowest_source_ms;
        timings.validation_second_source_record =
            timings.validation_slowest_source_record;
        timings.validation_slowest_source_ms = elapsed_ms;
        timings.validation_slowest_source_record = source_record;
    } else if elapsed_ms > timings.validation_second_source_ms {
        timings.validation_third_source_ms =
            timings.validation_second_source_ms;
        timings.validation_third_source_record =
            timings.validation_second_source_record;
        timings.validation_second_source_ms = elapsed_ms;
        timings.validation_second_source_record = source_record;
    } else if elapsed_ms > timings.validation_third_source_ms {
        timings.validation_third_source_ms = elapsed_ms;
        timings.validation_third_source_record = source_record;
    }
}
