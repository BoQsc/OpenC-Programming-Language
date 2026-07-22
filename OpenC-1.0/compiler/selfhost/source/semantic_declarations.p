import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void semantic_emit_type_table(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ref PackedBuffer types
) {
    usize type_id = 0;
    while type_id < types.length {
        usize kind = read_record_field(type_data, type_id, 0);
        usize flags = read_record_field(type_data, type_id, 4);
        io.print("TYPE ");
        io.print(type_id);
        io.print(" ");
        io.print(semantic_type_kind_name(kind));
        io.print(" ");
        semantic_emit_type_display(
            project_source, project_root,
            module_data, modules, source_data,
            type_data, type_id
        );
        io.print(" ");
        if kind >= 10 || (flags / 8) % 2 == 1 {
            io.print(read_record_field(type_data, type_id, 1));
        } else {
            io.print("0");
        }
        io.print(" ");
        if kind == 10 { io.print(read_record_field(type_data, type_id, 2)); }
        else { io.print("0"); }
        io.print(" ");
        if type_id < 18 { io.print(read_record_field(type_data, type_id, 3)); }
        else { io.print("0"); }
        io.print(" ");
        io.print(flags % 2);
        io.print(" ");
        io.println((flags / 2) % 2);
        type_id = type_id + 1;
    }
}

unsafe void semantic_predeclare_parsed_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types,
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax
) {
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if (kind == 3 || kind == 4 || kind == 5) &&
            !semantic_inside_when(syntax_data, syntax, record) {
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            semantic_declare_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types,
                module_index, source_record, source,
                name_start, name_length, true, kind == 4
            );
            semantic_declare_named(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, types,
                module_index, source_record, source,
                name_start, name_length, false, kind == 4
            );
        }
        record = record + 1;
    }
}

unsafe void semantic_predeclare_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out source
    );
    if !source_status.ok { return; }
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
        source, token_data, tokens, syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    semantic_predeclare_parsed_source(
        project_source, project_root, module_data, modules,
        source_data, module_index, source_record, type_data, types,
        source, token_data, tokens, syntax_data, syntax
    );
}

unsafe void semantic_emit_source_declarations(
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
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors,
    ref SemanticCounts counts
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record,
        out source
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
        if kind == 2 || kind == 3 || kind == 4 || kind == 5 || kind == 7 {
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            usize type_id = semantic_type_error();
            usize type_node = semantic_find_prefix_type(syntax_data, syntax, record);
            if kind == 2 || kind == 7 {
                type_id = semantic_resolve_type(
                    project_source, project_root,
                    module_data, modules, source_data, source_record,
                    source, token_data, tokens,
                    type_data, types,
                    read_record_field(syntax_data, type_node, 1),
                    read_record_field(syntax_data, type_node, 2)
                );
            } else {
                type_id = semantic_find_named(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, types,
                    source, name_start, name_length
                );
            }
            if kind != 2 {
                usize prior = 0;
                while prior < symbols.length {
                    if read_record_field(symbol_data, prior, 0) == module_index &&
                        semantic_same_name_record(
                            project_source, project_root, source_data,
                            symbol_data, prior,
                            source, name_start, name_length
                        ) {
                        semantic_record_error(
                            error_data, errors, source_record,
                            read_record_field(syntax_data, record, 1),
                            read_record_field(syntax_data, record, 2), 1
                        );
                        break;
                    }
                    prior = prior + 1;
                }
            }
            usize symbol_record = symbols.length;
            write_record_field(symbol_data, symbol_record, 0, module_index);
            write_record_field(symbol_data, symbol_record, 1, source_record);
            write_record_field(symbol_data, symbol_record, 2, name_start);
            write_record_field(symbol_data, symbol_record, 3, name_length);
            write_record_field(symbol_data, symbol_record, 4, kind);
            symbols.length = symbols.length + 1;

            io.print("DECL ");
            io.print(counts.declarations);
            io.print(" ");
            io.print(module_index);
            io.print(" ");
            io.print(source_index);
            io.print(" ");
            if kind == 2 { io.print("function"); }
            if kind == 3 { io.print("struct"); }
            if kind == 4 { io.print("resource"); }
            if kind == 5 { io.print("enum"); }
            if kind == 7 { io.print("constant"); }
            io.print(" ");
            usize node_start = read_record_field(syntax_data, record, 1);
            bool exported = semantic_prefix_has(
                source, token_data, tokens, node_start, name_start, "export"
            );
            if exported { io.print("exported"); }
            else { io.print("private"); }
            io.print(" ");
            project_emit_hex(project_slice(source, name_start, name_length));
            io.print(" ");
            io.print(node_start);
            io.print(" ");
            io.print(read_record_field(syntax_data, record, 2));
            io.print(" ");
            semantic_emit_type_display(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, type_id
            );
            io.print(" ");
            if kind == 2 && semantic_prefix_has(
                source, token_data, tokens,
                node_start,
                read_record_field(syntax_data, type_node, 1),
                "unsafe"
            ) { io.print("1"); } else { io.print("0"); }
            io.print(" ");
            if kind == 2 && semantic_prefix_has(
                source, token_data, tokens,
                node_start,
                read_record_field(syntax_data, type_node, 1),
                "own"
            ) { io.print("1"); } else { io.print("0"); }
            io.print(" ");
            if kind == 4 { io.println("1"); }
            else { io.println("0"); }

            if kind == 2 {
                usize detail = 0;
                usize parameter_index = 0;
                while detail < syntax.length {
                    if read_record_field(syntax_data, detail, 0) == 10 &&
                        semantic_node_contains(syntax_data, record, detail) {
                        usize detail_type = semantic_find_prefix_type(
                            syntax_data, syntax, detail
                        );
                        usize detail_type_id = semantic_resolve_type(
                            project_source, project_root,
                            module_data, modules, source_data, source_record,
                            source, token_data, tokens,
                            type_data, types,
                            read_record_field(syntax_data, detail_type, 1),
                            read_record_field(syntax_data, detail_type, 2)
                        );
                        usize detail_start = read_record_field(syntax_data, detail, 1);
                        usize detail_name_start = read_record_field(syntax_data, detail, 3);
                        io.print("PARAM ");
                        io.print(counts.declarations);
                        io.print(" ");
                        io.print(parameter_index);
                        io.print(" ");
                        bool out_mode = semantic_prefix_has(
                            source, token_data, tokens,
                            detail_start,
                            read_record_field(syntax_data, detail_type, 1),
                            "out"
                        );
                        bool own_mode = semantic_prefix_has(
                            source, token_data, tokens,
                            detail_start,
                            read_record_field(syntax_data, detail_type, 1),
                            "own"
                        );
                        if out_mode && own_mode { io.print("out_own"); }
                        else if out_mode { io.print("out"); }
                        else if own_mode { io.print("own"); }
                        else { io.print("value"); }
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source, detail_name_start,
                            read_record_field(syntax_data, detail, 4)
                        ));
                        io.print(" ");
                        io.print(detail_start);
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 2));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data, detail_type_id
                        );
                        io.println("");
                        parameter_index = parameter_index + 1;
                        counts.parameters = counts.parameters + 1;
                    }
                    detail = detail + 1;
                }
            }
            if kind == 3 || kind == 4 {
                usize detail = 0;
                usize member_index = 0;
                while detail < syntax.length {
                    if read_record_field(syntax_data, detail, 0) == 9 &&
                        semantic_node_contains(syntax_data, record, detail) {
                        usize detail_type = semantic_find_prefix_type(
                            syntax_data, syntax, detail
                        );
                        usize detail_type_id = semantic_resolve_type(
                            project_source, project_root,
                            module_data, modules, source_data, source_record,
                            source, token_data, tokens,
                            type_data, types,
                            read_record_field(syntax_data, detail_type, 1),
                            read_record_field(syntax_data, detail_type, 2)
                        );
                        usize detail_name_start = read_record_field(syntax_data, detail, 3);
                        usize earlier = 0;
                        while earlier < detail {
                            if read_record_field(syntax_data, earlier, 0) == 9 &&
                                semantic_node_contains(syntax_data, record, earlier) &&
                                semantic_spans_equal(
                                    source, detail_name_start,
                                    read_record_field(syntax_data, detail, 4),
                                    source,
                                    read_record_field(syntax_data, earlier, 3),
                                    read_record_field(syntax_data, earlier, 4)
                                ) {
                                semantic_record_error(
                                    error_data, errors, source_record,
                                    read_record_field(syntax_data, detail, 1),
                                    read_record_field(syntax_data, detail, 2), 2
                                );
                                break;
                            }
                            earlier = earlier + 1;
                        }
                        io.print("FIELD ");
                        io.print(counts.declarations);
                        io.print(" ");
                        io.print(member_index);
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source, detail_name_start,
                            read_record_field(syntax_data, detail, 4)
                        ));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 1));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 2));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data, detail_type_id
                        );
                        io.print(" ");
                        bool owning_field = kind == 4 && semantic_prefix_has(
                            source, token_data, tokens,
                            read_record_field(syntax_data, detail, 1),
                            read_record_field(syntax_data, detail_type, 1),
                            "own"
                        );
                        if owning_field || semantic_type_resource(type_data, detail_type_id) {
                            io.println("1");
                        } else { io.println("0"); }
                        member_index = member_index + 1;
                        counts.fields = counts.fields + 1;
                    }
                    detail = detail + 1;
                }
            }
            if kind == 5 {
                usize detail = 0;
                usize member_index = 0;
                while detail < syntax.length {
                    if read_record_field(syntax_data, detail, 0) == 6 &&
                        semantic_node_contains(syntax_data, record, detail) {
                        io.print("ITEM ");
                        io.print(counts.declarations);
                        io.print(" ");
                        io.print(member_index);
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source,
                            read_record_field(syntax_data, detail, 3),
                            read_record_field(syntax_data, detail, 4)
                        ));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 1));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, detail, 2));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data, type_id
                        );
                        io.println("");
                        member_index = member_index + 1;
                        counts.items = counts.items + 1;
                    }
                    detail = detail + 1;
                }
            }
            counts.declarations = counts.declarations + 1;
        }
        record = record + 1;
    }
}
