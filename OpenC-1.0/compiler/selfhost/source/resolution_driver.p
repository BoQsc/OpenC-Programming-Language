import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void resolution_observe_source_constants(
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
        if kind == 7 {
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            usize token = semantic_token_at_or_after(
                token_data, tokens, name_start + name_length
            );
            while token < tokens.length {
                usize token_start_value = read_record_field(token_data, token, 1);
                usize token_length_value = read_record_field(token_data, token, 2);
                if span_equals_ascii(
                    source, token_start_value, token_length_value, "="
                ) { break; }
                token = token + 1;
            }
            usize after = name_start + name_length;
            if token + 1 < tokens.length {
                after = read_record_field(token_data, token + 1, 1);
            }
            usize root = resolution_constant_root(
                syntax_data, syntax, record, after
            );
            if root < syntax.length {
                ResolutionConstant value = resolution_evaluate_expression(
                    source, syntax_data, syntax, root,
                    error_data, errors, source_record
                );
                if value.valid {
                    resolution_emit_constant(
                        project_source, project_root,
                        module_data, modules, source_data, type_data,
                        counts.constants, module_index, source_index,
                        "module_constant", source,
                        read_record_field(syntax_data, record, 1),
                        read_record_field(syntax_data, record, 2),
                        name_start, name_length,
                        value.type_id, value
                    );
                    counts.constants = counts.constants + 1;
                }
            }
        } else if kind == 5 {
            usize enum_symbol = resolution_find_top_unqualified(
                project_source, project_root, source_data,
                symbol_data, detail_data, symbols,
                module_index, source_record, source,
                read_record_field(syntax_data, record, 3),
                read_record_field(syntax_data, record, 4)
            );
            i64 next_value = 0;
            usize item = 0;
            while item < syntax.length {
                if read_record_field(syntax_data, item, 0) == 6 &&
                    semantic_node_contains(syntax_data, record, item) {
                    usize enum_type = semantic_type_error();
                    if enum_symbol < symbols.length {
                        enum_type = read_record_field(
                            symbol_data, enum_symbol, 4
                        );
                    }
                    ResolutionConstant enum_value = ResolutionConstant{
                        valid = true, kind = 1,
                        type_id = enum_type,
                        signed_value = next_value, bool_value = false,
                        value_start = 0, value_length = 0,
                        start = read_record_field(syntax_data, item, 1),
                        length = read_record_field(syntax_data, item, 2)
                    };
                    io.print("CONST ");
                    io.print(counts.constants);
                    io.print(" ");
                    io.print(module_index);
                    io.print(" ");
                    io.print(source_index);
                    io.print(" enum_item ");
                    io.print(read_record_field(syntax_data, item, 1));
                    io.print(" ");
                    io.print(read_record_field(syntax_data, item, 2));
                    io.print(" ");
                    project_emit_hex(project_slice(
                        source,
                        read_record_field(syntax_data, record, 3),
                        read_record_field(syntax_data, record, 4)
                    ));
                    io.print("2e");
                    project_emit_hex(project_slice(
                        source,
                        read_record_field(syntax_data, item, 3),
                        read_record_field(syntax_data, item, 4)
                    ));
                    io.print(" ");
                    semantic_emit_type_display(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, enum_value.type_id
                    );
                    io.print(" integer ");
                    io.println(enum_value.signed_value);
                    counts.constants = counts.constants + 1;
                    next_value = next_value + 1;
                }
                item = item + 1;
            }
        }
        record = record + 1;
    }
}

text resolution_error_rule(usize rule) {
    if rule == 1 { return "OPENC-NAME-UNKNOWN-001"; }
    if rule == 2 { return "OPENC-NAME-AMBIGUOUS-001"; }
    if rule == 3 { return "OPENC-CALL-NOMATCH-001"; }
    if rule == 4 { return "OPENC-CALL-AMBIGUOUS-001"; }
    if rule == 5 { return "OPENC-ARITH-DIVZERO-001"; }
    if rule == 6 { return "OPENC-ARITH-SHIFT-RANGE-001"; }
    if rule == 7 { return "OPENC-ARITH-STATIC-OVERFLOW-001"; }
    if rule == 8 { return "OPENC-CONSTANT-TYPE-001"; }
    return "OPENC-NAME-DUPLICATE-001";
}

unsafe i32 observe_semantic_resolution(text project_path) {
    io.println("OPENC-SEMANTIC-RESOLUTION-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }
    usize project_length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{ length = 0, capacity = project_length + 1 };
    PackedBuffer sources = PackedBuffer{ length = 0, capacity = project_length + 1 };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    if !project_parse_json(
        project_source, module_data, modules, source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
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
                io.print(module_index);
                io.print(" ");
                io.println(source_index);
                io.print("SUMMARY ");
                io.print(modules.length);
                io.println(" 0 0 0 0 1");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    usize capacity = total_source_length * 3 + project_length + 128;
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
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
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
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
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

    ResolutionCounts counts = ResolutionCounts{
        bindings = 0, constants = 0, calls = 0
    };
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_observe_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, types,
                symbol_data, detail_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_observe_source_constants(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, types,
                symbol_data, detail_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

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
        io.print(resolution_error_rule(
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
    io.print("SUMMARY ");
    io.print(modules.length);
    io.print(" ");
    io.print(sources.length);
    io.print(" ");
    io.print(counts.bindings);
    io.print(" ");
    io.print(counts.constants);
    io.print(" ");
    io.print(counts.calls);
    io.print(" ");
    io.println(errors.length);
    if errors.length != 0 { return 1; }
    return 0;
}
