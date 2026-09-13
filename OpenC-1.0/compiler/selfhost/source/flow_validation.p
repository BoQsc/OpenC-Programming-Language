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

unsafe bool flow_project_has_pointer_symbol(
    ptr byte type_data,
    ptr byte symbol_data,
    ref PackedBuffer symbols
) {
    usize symbol = 0;
    while symbol < symbols.length {
        usize type_id = read_record_field(symbol_data, symbol, 4);
        if read_record_field(type_data, type_id, 0) == 13 { return true; }
        symbol = symbol + 1;
    }
    return false;
}

unsafe bool flow_project_has_unsafe_function(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols
) {
    usize symbol = 0;
    while symbol < symbols.length {
        if flow_symbol_unsafe(
            project_source, project_root, source_data,
            symbol_data, detail_data, symbol
        ) { return true; }
        symbol = symbol + 1;
    }
    return false;
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
    bool project_has_pointer_symbol,
    bool project_has_unsafe_function,
    ptr byte parsed_source_cache,
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
    // Flow diagnostics require stateful symbols or one of the constructs below.
    // Prove their absence before allocating another token/syntax tree for this
    // source.  Every uncertain case retains the complete validator.
    bool source_needs_flow = project_has_unsafe_function ||
        flow_span_contains_ascii(source, 0, source_length, "scope") ||
        flow_span_contains_ascii(source, 0, source_length, "unsafe") ||
        flow_span_contains_ascii(source, 0, source_length, "reinterpret") ||
        flow_span_contains_ascii(source, 0, source_length, "ref") ||
        flow_span_contains_ascii(source, 0, source_length, "out") ||
        flow_span_contains_ascii(source, 0, source_length, "own") ||
        flow_span_contains_ascii(source, 0, source_length, "&");
    if !source_needs_flow && project_has_pointer_symbol {
        source_needs_flow =
            flow_span_contains_ascii(source, 0, source_length, "*") ||
            flow_span_contains_ascii(source, 0, source_length, "+") ||
            flow_span_contains_ascii(source, 0, source_length, "-");
    }
    usize flow_symbol = source_symbol_first;
    while flow_symbol < source_symbol_end && !source_needs_flow {
        usize flow_kind = read_record_field(
            symbol_data, flow_symbol, 0
        );
        usize flow_type = read_record_field(
            symbol_data, flow_symbol, 4
        );
        usize flow_type_kind = read_record_field(type_data, flow_type, 0);
        if flow_kind == resolution_symbol_variable() &&
            read_record_field(detail_data, flow_symbol, 2) != 0 {
            source_needs_flow = true;
        }
        if flow_kind == resolution_symbol_parameter() && (
            read_record_field(detail_data, flow_symbol, 3) == 1 ||
            flow_type_kind == 12 || flow_type_kind == 13 ||
            flow_symbol_resource_type(type_data, symbol_data, flow_symbol)
        ) { source_needs_flow = true; }
        flow_symbol = flow_symbol + 1;
    }
    if !source_needs_flow { return; }
    ResolutionParsedSource parsed = resolution_cached_parsed_source(
        parsed_source_cache, source_record
    );
    bool parsed_source_reused = parsed.reusable;
    PackedBuffer tokens = parsed.tokens;
    ptr byte token_data = parsed.token_data;
    PackedBuffer syntax = parsed.syntax;
    ptr byte syntax_data = parsed.syntax_data;
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = 0 };
    ptr byte diagnostic_data = null;
    if !parsed_source_reused {
        tokens = PackedBuffer{
            length = 0, capacity = source_length + 2
        };
        diagnostics = PackedBuffer{
            length = 0, capacity = source_length * 4 + 8
        };
        token_data = memory.alloc(
            tokens.capacity * record_stride()
        );
        diagnostic_data = memory.alloc(
            diagnostics.capacity * record_stride()
        );
        lex_source(
            source, token_data, tokens,
            diagnostic_data, diagnostics
        );
        syntax = PackedBuffer{
            length = 0, capacity = tokens.length * 6 + 8
        };
        syntax_data = memory.alloc(
            syntax.capacity * record_stride()
        );
        parse_source_syntax(
            source, token_data, tokens,
            syntax_data, syntax, diagnostic_data, diagnostics
        );
    }
    timings.validation_flow_parse_ms =
        timings.validation_flow_parse_ms +
        process.monotonic_milliseconds() - source_started;

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
    bool source_has_pointer_deref = false;
    bool source_has_unsafe_operation = false;
    bool source_has_scope_action = false;
    bool source_has_unsafe_block = false;
    bool call_positions_ordered = true;
    bool function_ranges_ordered = true;
    bool have_call_position = false;
    bool have_function_range = false;
    usize previous_call_position = 0;
    usize previous_function_end = 0;
    usize call_node = 0;
    while call_node < syntax.length {
        usize call_kind = read_record_field(syntax_data, call_node, 0);
        if call_kind == 38 {
            usize call_position = read_record_field(
                syntax_data, call_node, 1
            );
            if have_call_position &&
                call_position < previous_call_position {
                call_positions_ordered = false;
            }
            previous_call_position = call_position;
            have_call_position = true;
            write_usize(
                call_nodes, call_count * size_of(usize), call_node
            );
            call_count = call_count + 1;
        }
        if call_kind == 2 {
            usize function_position = read_record_field(
                syntax_data, call_node, 1
            );
            usize function_end = function_position + read_record_field(
                syntax_data, call_node, 2
            );
            if have_function_range &&
                function_position < previous_function_end {
                function_ranges_ordered = false;
            }
            previous_function_end = function_end;
            have_function_range = true;
        }
        if call_kind == 35 && (
            flow_node_operator(source, syntax_data, call_node, "&") ||
            flow_node_operator(source, syntax_data, call_node, "*")
        ) {
            source_has_unsafe_operation = true;
            if flow_node_operator(
                source, syntax_data, call_node, "*"
            ) { source_has_pointer_deref = true; }
        }
        if call_kind == 43 { source_has_unsafe_operation = true; }
        if call_kind == 23 { source_has_scope_action = true; }
        if call_kind == 24 { source_has_unsafe_block = true; }
        call_node = call_node + 1;
    }
    bool indexed_call_ranges = call_positions_ordered &&
        function_ranges_ordered;
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

    usize function_call_cursor = 0;
    usize function_node = 0;
    while function_node < syntax.length {
        if read_record_field(syntax_data, function_node, 0) == 2 {
            usize function_call_first = 0;
            usize function_call_end = call_count;
            if indexed_call_ranges {
                usize function_start = read_record_field(
                    syntax_data, function_node, 1
                );
                usize function_end = function_start + read_record_field(
                    syntax_data, function_node, 2
                );
                while function_call_cursor < call_count && read_record_field(
                    syntax_data, read_usize(
                        call_nodes,
                        function_call_cursor * size_of(usize)
                    ), 1
                ) < function_start {
                    function_call_cursor = function_call_cursor + 1;
                }
                function_call_first = function_call_cursor;
                while function_call_cursor < call_count && read_record_field(
                    syntax_data, read_usize(
                        call_nodes,
                        function_call_cursor * size_of(usize)
                    ), 1
                ) < function_end {
                    function_call_cursor = function_call_cursor + 1;
                }
                function_call_end = function_call_cursor;
            }
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
                if project_has_pointer_symbol && source_has_pointer_deref {
                    flow_analyze_pointer_facts(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        function_node, source, error_data, errors
                    );
                }
                timings.validation_flow_pointer_facts_ms =
                    timings.validation_flow_pointer_facts_ms +
                    process.monotonic_milliseconds() - analysis_started;
                bool function_unsafe = flow_function_unsafe(
                    source, syntax_data, function_node
                );
                analysis_started = process.monotonic_milliseconds();
                if !function_unsafe && source_has_unsafe_operation {
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
                if source_has_scope_action {
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
                                    type_data, symbol_data, detail_data,
                                    symbols, token_data, tokens, syntax_data,
                                    syntax, module_index, source_record,
                                    action, source
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
                timings.validation_flow_scope_actions_ms =
                    timings.validation_flow_scope_actions_ms +
                    process.monotonic_milliseconds() - analysis_started;
                analysis_started = process.monotonic_milliseconds();
                if !function_unsafe && project_has_unsafe_function &&
                    function_call_end > function_call_first {
                    flow_check_unsafe_calls(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, function_node, source,
                        call_nodes, function_call_first,
                        function_call_end - function_call_first,
                        source_has_unsafe_block,
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
    if !parsed_source_reused {
        memory.free(syntax_data);
        memory.free(diagnostic_data);
        memory.free(token_data);
    }
}
