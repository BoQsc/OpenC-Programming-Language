import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void project_graph_error(
    text rule,
    usize module_index,
    usize source_index,
    usize source_length
) {
    io.print("ERROR ");
    io.print(rule);
    io.print(" ");
    io.print(module_index);
    io.print(" ");
    io.print(source_index);
    io.print(" 0 ");
    io.print(source_length);
    io.println(" 1 1");
}

unsafe usize project_emit_graph_errors(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte import_data,
    ref PackedBuffer imports
) {
    usize errors = 0;
    usize import_record = 0;
    while import_record < imports.length {
        usize source_record = read_record_field(import_data, import_record, 2);
        text source;
        status import_source_status = project_read_source_record(
            project_source, project_root, source_data, source_record,
            out source
        );
        if !import_source_status.ok {
            import_record = import_record + 1;
            continue;
        }
        text import_name = project_import_text(source, import_data, import_record);
        if project_find_module(
            project_source, module_data, modules, import_name
        ) < 0 && !project_builtin_module(import_name) {
            project_graph_error(
                "OPENC-MODULE-IMPORT-MISSING-001",
                read_record_field(import_data, import_record, 0),
                read_record_field(import_data, import_record, 1),
                read_record_field(source_data, source_record, 2)
            );
            errors = errors + 1;
        }
        usize previous = 0;
        while previous < import_record {
            if read_record_field(import_data, previous, 0) ==
                read_record_field(import_data, import_record, 0) {
                usize previous_source_record = read_record_field(import_data, previous, 2);
                text previous_source;
                status previous_status = project_read_source_record(
                    project_source, project_root, source_data, previous_source_record,
                    out previous_source
                );
                if previous_status.ok {
                    text previous_name = project_import_text(
                        previous_source, import_data, previous
                    );
                    if project_same_short(previous_name, import_name) &&
                        previous_name != import_name {
                        project_graph_error(
                            "OPENC-MODULE-QUALIFIER-AMBIGUOUS-001",
                            read_record_field(import_data, import_record, 0),
                            read_record_field(import_data, import_record, 1),
                            read_record_field(source_data, source_record, 2)
                        );
                        errors = errors + 1;
                        break;
                    }
                }
            }
            previous = previous + 1;
        }
        import_record = import_record + 1;
    }

    import_record = 0;
    while import_record < imports.length {
        usize source_record = read_record_field(import_data, import_record, 2);
        text source;
        status cycle_source_status = project_read_source_record(
            project_source, project_root, source_data, source_record,
            out source
        );
        if !cycle_source_status.ok {
            import_record = import_record + 1;
            continue;
        }
        text import_name = project_import_text(source, import_data, import_record);
        i32 imported_module = project_find_module(
            project_source, module_data, modules, import_name
        );
        if imported_module >= 0 {
            text current_module = project_slice(
                project_source,
                read_record_field(
                    module_data,
                    read_record_field(import_data, import_record, 0),
                    0
                ),
                read_record_field(
                    module_data,
                    read_record_field(import_data, import_record, 0),
                    1
                )
            );
            usize reverse = 0;
            usize last_source = 0;
            bool has_last_source = false;
            while reverse < imports.length {
                if read_record_field(import_data, reverse, 0) ==
                    cast(usize, imported_module) {
                    usize reverse_source_record = read_record_field(import_data, reverse, 2);
                    if !has_last_source || reverse_source_record != last_source {
                        text reverse_source;
                        status reverse_status = project_read_source_record(
                            project_source, project_root, source_data, reverse_source_record,
                            out reverse_source
                        );
                        if reverse_status.ok {
                            if project_import_equals(
                                reverse_source, import_data, reverse, current_module
                            ) {
                                project_graph_error(
                                    "OPENC-MODULE-CYCLE-001",
                                    read_record_field(import_data, import_record, 0),
                                    read_record_field(import_data, import_record, 1),
                                    read_record_field(source_data, source_record, 2)
                                );
                                errors = errors + 1;
                                last_source = reverse_source_record;
                                has_last_source = true;
                            }
                        }
                    }
                }
                reverse = reverse + 1;
            }
        }
        import_record = import_record + 1;
    }
    return errors;
}

unsafe void project_emit_source_diagnostics(
    text source,
    usize module_index,
    usize source_index
) {
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0,
        capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0,
        capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);
    lex_source(
        source,
        token_data, tokens,
        diagnostic_data, diagnostics
    );
    PackedBuffer syntax = PackedBuffer{
        length = 0,
        capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source,
        token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    assign_diagnostic_positions(source, diagnostic_data, diagnostics);
    usize diagnostic = 0;
    while diagnostic < diagnostics.length {
        io.print("ERROR ");
        io.print(diagnostic_rule(read_record_field(diagnostic_data, diagnostic, 0)));
        io.print(" ");
        io.print(module_index);
        io.print(" ");
        io.print(source_index);
        io.print(" ");
        io.print(read_record_field(diagnostic_data, diagnostic, 1));
        io.print(" ");
        io.print(read_record_field(diagnostic_data, diagnostic, 2));
        io.print(" ");
        io.print(read_record_field(diagnostic_data, diagnostic, 3));
        io.print(" ");
        io.println(read_record_field(diagnostic_data, diagnostic, 4));
        diagnostic = diagnostic + 1;
    }
}
