import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct FlowFrontendObservation {
    bool ok;
    usize total_source_length;
    usize frontend_errors;
}

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
    ref PackedBuffer errors,
    ref BuildTimings timings
) {
    usize source_started = process.monotonic_milliseconds();
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
    timings.validation_flow_parse_ms =
        timings.validation_flow_parse_ms +
        process.monotonic_milliseconds() - source_started;

    usize source_symbol_first = 0;
    while source_symbol_first < symbols.length && read_record_field(
        symbol_data, source_symbol_first, 1
    ) != source_record {
        source_symbol_first = source_symbol_first + 1;
    }
    usize source_symbol_end = source_symbol_first;
    while source_symbol_end < symbols.length && read_record_field(
        symbol_data, source_symbol_end, 1
    ) == source_record {
        source_symbol_end = source_symbol_end + 1;
    }
    // Pointer arithmetic can only be recognized from a resolved symbol whose
    // semantic type is a raw pointer.  Prove that such a symbol exists once
    // per source before entering the per-function flow loop.  This avoids an
    // otherwise quadratic syntax walk for pointer-free projects while keeping
    // the decision semantic (rather than relying on source-text spelling).
    bool project_has_pointer_symbol = false;
    usize pointer_symbol = 0;
    while pointer_symbol < symbols.length &&
        !project_has_pointer_symbol {
        usize pointer_type = read_record_field(
            symbol_data, pointer_symbol, 4
        );
        project_has_pointer_symbol = read_record_field(
            type_data, pointer_type, 0
        ) == 13;
        pointer_symbol = pointer_symbol + 1;
    }
    ptr byte function_owner_data = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    scope memory.free(function_owner_data);
    ptr byte ownership_relevant_data = memory.alloc(
        (symbols.length + 2) * size_of(usize)
    );
    scope memory.free(ownership_relevant_data);
    ptr byte call_nodes = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    scope memory.free(call_nodes);
    usize call_count = 0;
    usize call_node = 0;
    while call_node < syntax.length {
        if read_record_field(syntax_data, call_node, 0) == 38 {
            write_usize(
                call_nodes, call_count * size_of(usize), call_node
            );
            call_count = call_count + 1;
        }
        call_node = call_node + 1;
    }
    usize cache_index = 0;
    while cache_index <= syntax.length {
        write_usize(
            function_owner_data, cache_index * size_of(usize), 0
        );
        cache_index = cache_index + 1;
    }
    cache_index = 0;
    while cache_index <= symbols.length + 1 {
        write_usize(
            ownership_relevant_data, cache_index * size_of(usize), 0
        );
        cache_index = cache_index + 1;
    }
    bool source_has_own = flow_span_contains_ascii(
        source, 0, source_length, "own"
    );
    usize indexed_symbol = source_symbol_first;
    while indexed_symbol < source_symbol_end {
        usize indexed_kind = read_record_field(
            symbol_data, indexed_symbol, 0
        );
        usize declaration = read_record_field(
            detail_data, indexed_symbol, 1
        );
        if indexed_kind == resolution_symbol_function() &&
            declaration < syntax.length {
            write_usize(
                function_owner_data,
                declaration * size_of(usize), indexed_symbol + 1
            );
        }
        usize indexed_owner = read_record_field(
            detail_data, indexed_symbol, 2
        );
        if indexed_owner != 0 &&
            (indexed_kind == resolution_symbol_variable() ||
             indexed_kind == resolution_symbol_parameter()) {
            bool relevant = flow_symbol_resource_type(
                type_data, symbol_data, indexed_symbol
            );
            if !relevant && source_has_own &&
                indexed_kind == resolution_symbol_parameter() {
                relevant = flow_parameter_own(
                    project_source, project_root, source_data,
                    symbol_data, detail_data, indexed_symbol
                );
            }
            if relevant {
                write_usize(
                    ownership_relevant_data,
                    indexed_owner * size_of(usize), 1
                );
            }
        }
        indexed_symbol = indexed_symbol + 1;
    }

    usize function_node = 0;
    while function_node < syntax.length {
        if read_record_field(syntax_data, function_node, 0) == 2 {
            usize body = flow_largest_direct_block(
                syntax_data, syntax, function_node
            );
            if body < syntax.length &&
                read_record_field(syntax_data, body, 2) > 1 {
                usize analysis_started = process.monotonic_milliseconds();
                usize function_owner = read_usize(
                    function_owner_data,
                    function_node * size_of(usize)
                );
                flow_analyze_initialization(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, function_owner,
                    source_symbol_first, source_symbol_end,
                    source, error_data, errors
                );
                timings.validation_flow_initialization_ms =
                    timings.validation_flow_initialization_ms +
                    process.monotonic_milliseconds() - analysis_started;
                if flow_function_has_word(
                    source, syntax_data, function_node, "out"
                ) {
                    analysis_started = process.monotonic_milliseconds();
                    flow_analyze_status_out(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, function_node, source,
                        error_data, errors
                    );
                    timings.validation_flow_status_out_ms =
                        timings.validation_flow_status_out_ms +
                        process.monotonic_milliseconds() - analysis_started;
                }
                analysis_started = process.monotonic_milliseconds();
                flow_analyze_ownership(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node,
                    function_owner, source_symbol_first, source_symbol_end,
                    ownership_relevant_data, source,
                    error_data, errors
                );
                timings.validation_flow_ownership_ms =
                    timings.validation_flow_ownership_ms +
                    process.monotonic_milliseconds() - analysis_started;
                if flow_function_has_word(
                    source, syntax_data, function_node, "ref"
                ) {
                    analysis_started = process.monotonic_milliseconds();
                    flow_analyze_borrows(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        function_node, source, error_data, errors
                    );
                    timings.validation_flow_borrows_ms =
                        timings.validation_flow_borrows_ms +
                        process.monotonic_milliseconds() - analysis_started;
                }
                if flow_function_has_word(
                    source, syntax_data, function_node, "scope"
                ) {
                    analysis_started = process.monotonic_milliseconds();
                    flow_analyze_cleanup(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, function_node, source,
                        error_data, errors
                    );
                    timings.validation_flow_cleanup_ms =
                        timings.validation_flow_cleanup_ms +
                        process.monotonic_milliseconds() - analysis_started;
                }
                analysis_started = process.monotonic_milliseconds();
                flow_analyze_pointer_facts(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    function_node, source, error_data, errors
                );
                timings.validation_flow_pointer_facts_ms =
                    timings.validation_flow_pointer_facts_ms +
                    process.monotonic_milliseconds() - analysis_started;
                bool function_unsafe = flow_function_unsafe(
                    source, syntax_data, function_node
                );
                analysis_started = process.monotonic_milliseconds();
                if !function_unsafe {
                    flow_check_unsafe_function(
                        source, syntax_data, syntax, source_record,
                        function_node, error_data, errors
                    );
                }
                timings.validation_flow_unsafe_function_ms =
                    timings.validation_flow_unsafe_function_ms +
                    process.monotonic_milliseconds() - analysis_started;
                analysis_started = process.monotonic_milliseconds();
                if !function_unsafe && project_has_pointer_symbol {
                    flow_check_pointer_arithmetic(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        function_node, source, error_data, errors
                    );
                }
                timings.validation_flow_pointer_arithmetic_ms =
                    timings.validation_flow_pointer_arithmetic_ms +
                    process.monotonic_milliseconds() - analysis_started;
                // The historical precheck parsed this source a second time
                // solely to perform this remaining distinct scope-action
                // rule (its unsafe and pointer checks are already above).
                // Keep the rule while sharing this function's token/syntax
                // arenas so public validation does not churn a duplicate set
                // of large allocations for every source file.
                analysis_started = process.monotonic_milliseconds();
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
                timings.validation_flow_scope_actions_ms =
                    timings.validation_flow_scope_actions_ms +
                    process.monotonic_milliseconds() - analysis_started;
                analysis_started = process.monotonic_milliseconds();
                if !function_unsafe {
                    flow_check_unsafe_calls(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, function_node, source,
                        call_nodes, call_count,
                        error_data, errors
                    );
                }
                timings.validation_flow_unsafe_calls_ms =
                    timings.validation_flow_unsafe_calls_ms +
                    process.monotonic_milliseconds() - analysis_started;
            }
        }
        function_node = function_node + 1;
    }
}
