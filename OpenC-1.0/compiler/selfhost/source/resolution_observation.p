import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void resolution_observe_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors,
    ref ResolutionCounts counts
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !source_status.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = source_length + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = source_length * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{ length = 0, capacity = tokens.length * 6 + 8 };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );

    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if kind == 27 && !resolution_name_excluded(
            syntax_data, syntax, record
        ) {
            usize symbol = resolution_find_name(
                project_source, project_root,
                module_data, modules, source_data,
                symbol_data, detail_data, symbols,
                syntax_data, syntax, module_index, source_record,
                record, source
            );
            if symbol < symbols.length {
                io.print("BIND ");
                io.print(counts.bindings);
                io.print(" ");
                io.print(module_index);
                io.print(" ");
                io.print(source_index);
                io.print(" ");
                io.print(read_record_field(syntax_data, record, 1));
                io.print(" ");
                io.print(read_record_field(syntax_data, record, 2));
                io.print(" ");
                project_emit_hex(project_slice(
                    source,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2)
                ));
                io.print(" ");
                io.print(resolution_symbol_kind_name(
                    read_record_field(symbol_data, symbol, 0)
                ));
                io.print(" ");
                resolution_emit_symbol_identity(
                    project_source, project_root,
                    module_data, source_data,
                    symbol_data, detail_data, symbol
                );
                usize packed_span = read_record_field(
                    detail_data, symbol, 4
                );
                io.print(" ");
                io.print(resolution_span_start(packed_span));
                io.print(" ");
                io.print(resolution_span_length(packed_span));
                io.print(" ");
                if resolution_name_is_unchecked_operand(
                    syntax_data, syntax, record
                ) {
                    semantic_emit_type_display(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, semantic_type_error()
                    );
                } else {
                    semantic_emit_type_display(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data,
                        read_record_field(symbol_data, symbol, 4)
                    );
                }
                io.println("");
                counts.bindings = counts.bindings + 1;
            } else {
                semantic_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2), 1
                );
            }
        } else if kind == 38 {
            usize callee_record = read_record_field(syntax_data, record, 3);
            if callee_record < syntax.length &&
                read_record_field(syntax_data, callee_record, 0) == 27 {
                usize callee_symbol = resolution_find_name(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    callee_record, source
                );
                if callee_symbol < symbols.length {
                    ResolutionCallSelection selection = resolution_select_call(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, record, source,
                        callee_symbol
                    );
                    usize selected = selection.symbol;
                    bool ambiguous = selection.ambiguous;
                    if selected < symbols.length && !ambiguous {
                        io.print("CALL ");
                        io.print(counts.calls);
                        io.print(" ");
                        io.print(module_index);
                        io.print(" ");
                        io.print(source_index);
                        io.print(" ");
                        io.print(read_record_field(syntax_data, record, 1));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, record, 2));
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source,
                            read_record_field(syntax_data, callee_record, 1),
                            read_record_field(syntax_data, callee_record, 2)
                        ));
                        io.print(" ");
                        resolution_emit_symbol_identity(
                            project_source, project_root,
                            module_data, source_data,
                            symbol_data, detail_data, selected
                        );
                        usize packed_span = read_record_field(
                            detail_data, selected, 4
                        );
                        io.print(" ");
                        io.print(resolution_span_start(packed_span));
                        io.print(" ");
                        io.print(resolution_span_length(packed_span));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data,
                            read_record_field(symbol_data, selected, 4)
                        );
                        io.println("");
                        counts.calls = counts.calls + 1;
                    } else {
                        usize call_rule = 3;
                        if ambiguous { call_rule = 4; }
                        semantic_record_error(
                            error_data, errors, source_record,
                            read_record_field(syntax_data, record, 1),
                            read_record_field(syntax_data, record, 2),
                            call_rule
                        );
                    }
                }
            }
        }
        record = record + 1;
    }
}

