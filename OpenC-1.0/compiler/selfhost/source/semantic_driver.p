import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe i32 observe_semantic_declarations(text project_path) {
    io.println("OPENC-SEMANTIC-DECL-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 0 1");
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
        io.println("SUMMARY 0 0 0 0 0 0 1");
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
                io.println(" 0 0 0 0 0 1");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    usize capacity = total_source_length + project_length + 64;
    PackedBuffer types = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer symbols = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer errors = PackedBuffer{ length = 0, capacity = capacity };
    ptr byte type_data = memory.alloc(types.capacity * record_stride());
    scope memory.free(type_data);
    ptr byte symbol_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(symbol_data);
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

    SemanticCounts counts = SemanticCounts{
        declarations = 0,
        parameters = 0,
        fields = 0,
        items = 0
    };
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_emit_source_declarations(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, types,
                symbol_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    semantic_emit_type_table(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, types
    );
    usize error = 0;
    while error < errors.length {
        usize source_record = read_record_field(error_data, error, 0);
        usize error_module = semantic_source_module(
            module_data, modules, source_record
        );
        usize source_first = read_record_field(module_data, error_module, 2);
        io.print("ERROR OPENC-NAME-DUPLICATE-001 ");
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
    io.print(counts.declarations);
    io.print(" ");
    io.print(counts.parameters);
    io.print(" ");
    io.print(counts.fields);
    io.print(" ");
    io.print(counts.items);
    io.print(" ");
    io.println(errors.length);
    if errors.length != 0 { return 1; }
    return 0;
}

