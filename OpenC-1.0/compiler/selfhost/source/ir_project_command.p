import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe i32 observe_semantic_ir(text project_path) {
    io.println("OPENC-SEMANTIC-IR-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
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
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize frontend_errors = 0;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status declaration_source_status = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !declaration_source_status.ok {
                io.println("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            frontend_errors = frontend_errors + flow_source_frontend_errors(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if frontend_errors != 0 {
        io.print("FRONTEND_ERROR "); io.println(frontend_errors);
        return 1;
    }

    usize capacity = total_source_length * 8 + project_length + 1024;
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
    BuildTimings validation_timings = build_timings_empty();
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
                type_data, types, symbol_data, detail_data, symbols
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    bool project_has_pointer_symbol = flow_project_has_pointer_symbol(
        type_data, symbol_data, symbols
    );
    bool project_has_unsafe_function = flow_project_has_unsafe_function(
        project_source, project_root, source_data,
        symbol_data, detail_data, symbols
    );
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            flow_precheck_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_record,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            flow_validate_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_record,
                type_data, symbol_data, detail_data, symbols,
                project_has_pointer_symbol,
                project_has_unsafe_function,
                null,
                error_data, errors, validation_timings
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    ptr byte validation_source_ms = memory.alloc(
        (sources.length + 1) * size_of(usize)
    );
    scope memory.free(validation_source_ms);
    usize validation_source = 0;
    while validation_source <= sources.length {
        write_usize(
            validation_source_ms,
            validation_source * size_of(usize),
            0
        );
        validation_source = validation_source + 1;
    }
    usize acceptance_errors = acceptance_validate_project(
        project_source, project_root,
        module_data, modules, source_data, sources,
        type_data, types, symbol_data, detail_data, symbols,
        validation_source_ms, validation_timings
    );
    if errors.length + acceptance_errors != 0 {
        io.print("SEMANTIC_ERROR ");
        io.println(errors.length + acceptance_errors);
        return 1;
    }

    usize entry = ir_entry_module(
        project_source, project_root, source_data,
        symbol_data, detail_data, symbols, modules.length
    );
    io.print("{\"entry_function\":");
    if entry < modules.length { io.print("\"main\""); }
    else { io.print("\"\""); }
    io.print(",\"entry_module\":");
    if entry < modules.length {
        ir_json_slice(
            project_source,
            read_record_field(module_data, entry, 0),
            read_record_field(module_data, entry, 1)
        );
    } else { io.print("\"\""); }
    io.print(",\"modules\":[");

    usize next_value = 1;
    usize emitted_modules = 0;
    module_index = 0;
    while module_index < modules.length {
        if emitted_modules != 0 { io.print(","); }
        io.print("{\"functions\":[");
        IrObserveState state = IrObserveState{
            types = types,
            next_value = next_value,
            emitted_functions = 0
        };
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            if !ir_observe_emit_source(
                project_source, project_root, module_data, modules,
                source_data, type_data, symbol_data, detail_data,
                symbols, module_index, source_record, state
            ) { return 1; }
            source_index = source_index + 1;
        }
        next_value = state.next_value;
        types = state.types;
        io.print("],\"module\":");
        ir_json_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        );
        io.print("}");
        emitted_modules = emitted_modules + 1;
        module_index = module_index + 1;
    }
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.io", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.memory", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.text", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.process", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.path", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.file", emitted_modules
    );
    io.println("],\"schema\":\"openc.core_ir.v1\"}");
    return 0;
}
