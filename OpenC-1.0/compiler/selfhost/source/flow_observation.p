import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
                    function_node, 0, 0, symbols.length,
                    source, error_data, errors
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
                    module_index, source_record, function_node,
                    0, 0, symbols.length, null, source,
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
