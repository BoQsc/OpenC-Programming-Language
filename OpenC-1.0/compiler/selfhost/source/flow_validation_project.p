import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
