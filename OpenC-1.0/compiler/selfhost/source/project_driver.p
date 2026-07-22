import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe i32 observe_project(text project_path) {
    io.println("OPENC-PROJECT-OBSERVATION 1");
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
    PackedBuffer imports = PackedBuffer{ length = 0, capacity = project_length + 1 };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    ptr byte import_data = memory.alloc(imports.capacity * record_stride());
    scope memory.free(import_data);

    if !project_parse_json(
        project_source,
        module_data, modules,
        source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    usize graph_modules = project_emit_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize unit_count = 0;
    usize node_count = 0;
    usize error_count = 0;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            text source_path = project_source_record_path(
                project_source, project_root, source_data, source_record
            );
            text source;
            status read_status = project_read_source_record(
                project_source, project_root, source_data, source_record,
                out source
            );
            io.print("UNIT ");
            io.print(module_index);
            io.print(" ");
            io.print(source_index);
            io.print(" ");
            project_emit_hex(source_path);
            io.println("");
            unit_count = unit_count + 1;
            if !read_status.ok {
                io.print("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ");
                io.print(module_index);
                io.print(" ");
                io.println(source_index);
                error_count = error_count + 1;
                source_index = source_index + 1;
                continue;
            }

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
            write_record_field(source_data, source_record, 2, source_length);
            write_record_field(source_data, source_record, 3, syntax.length);
            write_record_field(source_data, source_record, 4, 1);
            io.print("SOURCE ");
            io.print(module_index);
            io.print(" ");
            io.print(source_index);
            io.print(" ");
            io.print(source_length);
            io.print(" ");
            io.println(syntax.length);
            node_count = node_count + syntax.length;
            usize before_imports = imports.length;
            project_record_imports(
                source,
                token_data, tokens,
                module_index, source_index, source_record,
                import_data, imports
            );
            usize import_record = before_imports;
            while import_record < imports.length {
                io.print("IMPORT ");
                io.print(module_index);
                io.print(" ");
                io.print(source_index);
                io.print(" ");
                project_emit_hex(project_import_text(source, import_data, import_record));
                io.println("");
                import_record = import_record + 1;
            }
            error_count = error_count + diagnostics.length;
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
            usize source_record = source_first + source_index;
            if read_record_field(source_data, source_record, 4) == 1 {
                text source;
                status source_status = project_read_source_record(
                    project_source, project_root, source_data, source_record,
                    out source
                );
                if source_status.ok {
                    project_emit_source_diagnostics(source, module_index, source_index);
                }
            }
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if error_count == 0 {
        error_count = error_count + project_emit_graph_errors(
            project_source, project_root,
            module_data, modules,
            source_data,
            import_data, imports
        );
    }
    io.print("SUMMARY ");
    io.print(modules.length);
    io.print(" ");
    io.print(graph_modules);
    io.print(" ");
    io.print(unit_count);
    io.print(" ");
    io.print(imports.length);
    io.print(" ");
    io.print(node_count);
    io.print(" ");
    io.println(error_count);
    if error_count != 0 { return 1; }
    return 0;
}

