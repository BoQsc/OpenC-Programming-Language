import system.file;
import system.io;
import system.memory;
import system.path;
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
                if flow_function_has_word(
                    source, syntax_data, function_node, "out"
                ) {
                    flow_analyze_status_out(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, function_node, source,
                        error_data, errors
                    );
                }
                flow_analyze_ownership(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, symbol_data, detail_data, symbols,
                    token_data, tokens, syntax_data, syntax,
                    module_index, source_record, function_node, source,
                    error_data, errors
                );
                if flow_function_has_word(
                    source, syntax_data, function_node, "ref"
                ) {
                    flow_analyze_borrows(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        syntax_data, syntax, module_index, source_record,
                        function_node, source, error_data, errors
                    );
                }
                if flow_function_has_word(
                    source, syntax_data, function_node, "scope"
                ) {
                    flow_analyze_cleanup(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, function_node, source,
                        error_data, errors
                    );
                }
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
                // The historical precheck parsed this source a second time
                // solely to perform this remaining distinct scope-action
                // rule (its unsafe and pointer checks are already above).
                // Keep the rule while sharing this function's token/syntax
                // arenas so public validation does not churn a duplicate set
                // of large allocations for every source file.
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

unsafe FlowFrontendObservation flow_observe_frontend_sources(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data
) {
    FlowFrontendObservation observation = FlowFrontendObservation{
        ok = true, total_source_length = 0, frontend_errors = 0
    };
    usize module_index = 0;
    while module_index < modules.length {
        io.print("MODULE "); io.print(module_index); io.print(" ");
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print(" ");
        io.println(read_record_field(module_data, module_index, 3));
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status source_status = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !source_status.ok {
                io.print("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ");
                io.print(module_index); io.print(" ");
                io.println(source_index);
                observation.ok = false;
                return observation;
            }
            observation.total_source_length =
                observation.total_source_length +
                text.byte_length(source);
            observation.frontend_errors = observation.frontend_errors +
                flow_source_frontend_errors(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    return observation;
}

unsafe void flow_predeclare_project_sources(
    text project_source, text project_root,
    ptr byte module_data, ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data, ref PackedBuffer types
) {
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_predeclare_source(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_first + source_index,
                type_data, types
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
}

unsafe void flow_collect_project_symbols(
    text project_source, text project_root,
    ptr byte module_data, ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data, ref PackedBuffer types,
    ptr byte symbol_data, ptr byte detail_data,
    ref PackedBuffer symbols
) {
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_collect_source_symbols(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_first + source_index,
                type_data, types, symbol_data, detail_data, symbols
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
}

unsafe void flow_precheck_project_sources(
    text project_source, text project_root,
    ptr byte module_data, ref PackedBuffer modules,
    ptr byte source_data, ptr byte type_data,
    ptr byte symbol_data, ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data, ref PackedBuffer errors
) {
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            flow_precheck_source(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_first + source_index,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
}

unsafe void flow_observe_project_sources(
    text project_source, text project_root,
    ptr byte module_data, ref PackedBuffer modules,
    ptr byte source_data, ptr byte type_data,
    ptr byte symbol_data, ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data, ref PackedBuffer errors,
    ref FlowCounts counts
) {
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            flow_observe_source(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_index,
                source_first + source_index, type_data,
                symbol_data, detail_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
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
    FlowFrontendObservation observation = flow_observe_frontend_sources(
        project_source, project_root, module_data, modules,
        source_data
    );
    if !observation.ok {
        io.print("SUMMARY "); io.print(modules.length);
        io.println(" 0 0 0 0 0 1");
        return 1;
    }
    usize total_source_length = observation.total_source_length;
    usize frontend_errors = observation.frontend_errors;
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

    usize type_capacity =
        total_source_length / 8 + project_length + 65536;
    usize symbol_capacity =
        total_source_length / 4 + project_length + 65536;
    usize error_capacity =
        total_source_length / 4 + project_length + 65536;
    PackedBuffer types = PackedBuffer{
        length = 0, capacity = type_capacity
    };
    PackedBuffer symbols = PackedBuffer{
        length = 0, capacity = symbol_capacity
    };
    PackedBuffer errors = PackedBuffer{
        length = 0, capacity = error_capacity
    };
    ptr byte type_data = memory.alloc(types.capacity * record_stride());
    scope memory.free(type_data);
    ptr byte symbol_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(symbol_data);
    ptr byte detail_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(detail_data);
    ptr byte error_data = memory.alloc(errors.capacity * record_stride());
    scope memory.free(error_data);
    semantic_initialize_types(type_data, types);

    flow_predeclare_project_sources(
        project_source, project_root, module_data, modules,
        source_data, type_data, types
    );
    flow_collect_project_symbols(
        project_source, project_root, module_data, modules,
        source_data, type_data, types,
        symbol_data, detail_data, symbols
    );
    flow_precheck_project_sources(
        project_source, project_root, module_data, modules,
        source_data, type_data, symbol_data, detail_data,
        symbols, error_data, errors
    );
    FlowCounts counts = FlowCounts{
        functions = 0, blocks = 0, edges = 0, cleanups = 0
    };
    flow_observe_project_sources(
        project_source, project_root, module_data, modules,
        source_data, type_data, symbol_data, detail_data,
        symbols, error_data, errors, counts
    );

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
