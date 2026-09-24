import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void c_close_lowering_types_since(
    ref IrContext base,
    usize first_type
) {
    // Null lowering has a canonical implementation type that source-level
    // semantic analysis does not otherwise need to materialize.
    if first_type == 0 {
        semantic_derived_type(
            base.type_data, base.types, 13,
            semantic_type_void(), 0, true, false
        );

        // Out parameters become addressable reference storage in the IR.
        usize symbol = 0;
        while symbol < base.symbols.length {
            if read_record_field(base.symbol_data, symbol, 0) ==
                    resolution_symbol_parameter() &&
                read_record_field(base.detail_data, symbol, 3) == 1 {
                semantic_derived_type(
                    base.type_data, base.types, 12,
                    read_record_field(base.symbol_data, symbol, 4),
                    0, false, false
                );
            }
            symbol = symbol + 1;
        }
    }

    // Array slicing and owned-storage access can synthesize these forms while
    // lowering even when no declaration spells them explicitly.
    usize semantic_type_count = base.types.length;
    usize type_id = first_type;
    while type_id < semantic_type_count {
        usize kind = read_record_field(base.type_data, type_id, 0);
        if kind == 10 {
            semantic_derived_type(
                base.type_data, base.types, 11,
                read_record_field(base.type_data, type_id, 1),
                0, false, false
            );
        } else if kind == 15 {
            semantic_derived_type(
                base.type_data, base.types, 12,
                read_record_field(base.type_data, type_id, 1),
                0, false, false
            );
        }
        type_id = type_id + 1;
    }

    // Address lowering can point at any semantic or closure-created value.
    // Freeze one pointer form for each such type; do not recurse over the
    // pointers added by this loop.
    usize addressable_type_count = base.types.length;
    type_id = 0;
    while type_id < addressable_type_count {
        semantic_derived_type(
            base.type_data, base.types, 13,
            type_id, 0, false, false
        );
        type_id = type_id + 1;
    }
}

unsafe void c_close_lowering_types(ref IrContext base) {
    c_close_lowering_types_since(base, 0);
}

unsafe i32 c_emit_project(
    ref IrContext base,
    text output_source,
    usize output_capacity,
    usize entry_module,
    ref BuildTimings timings,
    bool validate_acceptance,
    ptr byte validation_source_ms,
    ptr byte parsed_source_cache,
    ref NativeArtifactOptions artifact_options
) {
    // The fused validating path remains sequential and lets lowering create
    // only the derived types it actually needs.  Eagerly closing every type
    // before acceptance doubles the lookup set and defeats cache reuse.
    if !validate_acceptance ||
        (timings.emission_mode == 2 &&
            (artifact_options.source_chunks == 2 ||
             artifact_options.source_chunks == 4)) {
        c_close_lowering_types(base);
    }
    usize native_layout_cache_bytes =
        (base.types.capacity + 1) * size_of(usize);
    ptr byte native_layout_sizes = memory.alloc(native_layout_cache_bytes);
    scope memory.free(native_layout_sizes);
    ptr byte native_layout_alignments = memory.alloc(
        native_layout_cache_bytes);
    scope memory.free(native_layout_alignments);
    ptr byte native_layout_states = memory.alloc(native_layout_cache_bytes);
    scope memory.free(native_layout_states);
    if timings.emission_mode == 2 {
        base.native_layout_size_cache = ir_pointer_alias(
            native_layout_sizes);
        base.native_layout_alignment_cache = ir_pointer_alias(
            native_layout_alignments);
        base.native_layout_state_cache = ir_pointer_alias(
            native_layout_states);
        usize native_layout_index = 0;
        while native_layout_index <= base.types.capacity {
            write_usize(native_layout_states,
                native_layout_index * size_of(usize), 0);
            native_layout_index = native_layout_index + 1;
        }
    }
    DBuffer output = d_buffer_create(output_capacity * 2 + 1048576);
    if timings.emission_mode == 1 {
        d_put(output, "{\"schema\":\"openc.native_backend_audit.v1\",\"scope\":\"all_project_functions\",\"native_backend_complete\":false,\"functions\":[\n");
    } else if timings.emission_mode == 0 {
    d_put(output, "/* OpenC SH-5 deterministic C11 backend output. */\n");
    d_put(output, "#define OPENC_RUNTIME_BUILD 1\n");
    d_put(output, "#include <stdbool.h>\n");
    d_put(output, "#include <stdint.h>\n");
    d_put(output, "#include <stddef.h>\n");
    d_put(output, "#include \"openc_sh5_runtime.h\"\n\n");
    c_emit_forward_types(base, output);
    c_emit_enum_types(base, output);
    c_emit_named_type_bodies(base, output);
    c_emit_compound_types(base, output);
    }

    usize function_bucket_capacity = ir_index_capacity(
        base.symbols.length * 2 + 1
    );
    ptr byte function_bucket_heads = memory.alloc(
        function_bucket_capacity * size_of(usize)
    );
    ptr byte function_bucket_next = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte function_parameter_first = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte function_parameter_count = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte parameter_next = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte function_local_range_first = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte function_local_range_end = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte type_aggregate_symbols = memory.alloc(
        (base.types.capacity + 1) * size_of(usize)
    );
    ptr byte aggregate_field_first = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte field_next = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte enum_item_value = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte symbol_export_cache = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    scope memory.free(symbol_export_cache);
    usize export_symbol = 0;
    while export_symbol <= base.symbols.length {
        write_usize(
            symbol_export_cache, export_symbol * size_of(usize), 0
        );
        export_symbol = export_symbol + 1;
    }
    ptr byte parameter_last = memory.alloc(
        (base.symbols.length + 1) * size_of(usize)
    );
    base.function_bucket_heads = ir_pointer_alias(function_bucket_heads);
    base.function_bucket_capacity = function_bucket_capacity;
    base.function_bucket_next = ir_pointer_alias(function_bucket_next);
    base.function_parameter_first = ir_pointer_alias(
        function_parameter_first
    );
    base.function_parameter_count = ir_pointer_alias(
        function_parameter_count
    );
    base.parameter_next = ir_pointer_alias(parameter_next);
    base.function_local_range_first = ir_pointer_alias(
        function_local_range_first
    );
    base.function_local_range_end = ir_pointer_alias(
        function_local_range_end
    );
    base.type_aggregate_symbols = ir_pointer_alias(
        type_aggregate_symbols
    );
    base.aggregate_field_first = ir_pointer_alias(
        aggregate_field_first
    );
    base.field_next = ir_pointer_alias(field_next);
    base.enum_item_value = ir_pointer_alias(enum_item_value);
    base.symbol_export_cache = ir_pointer_alias(symbol_export_cache);
    ir_initialize_symbol_indexes(base, parameter_last);
    memory.free(parameter_last);
    if validate_acceptance {
        usize global_started = process.monotonic_milliseconds();
        usize found = acceptance_validate_module_cycles(
            base.project_source, base.project_root,
            base.module_data, base.modules, base.source_data
        );
        acceptance_report_count(
            "module_cycles", c_project_source_count(base), found
        );
        timings.validation_acceptance_errors =
            timings.validation_acceptance_errors + found;
        found = acceptance_validate_duplicate_functions(base);
        acceptance_report_count("duplicate_functions", 0, found);
        timings.validation_acceptance_errors =
            timings.validation_acceptance_errors + found;
        timings.validation_acceptance_ms =
            timings.validation_acceptance_ms +
            process.monotonic_milliseconds() - global_started;
    }
    if timings.emission_mode == 0 {
        c_emit_function_prototypes(base, output, entry_module);
    }

    bool emitted_parallel = false;
    if timings.emission_mode == 2 &&
        (artifact_options.source_chunks == 2 ||
            artifact_options.source_chunks == 4) &&
        c_project_source_count(base) >= artifact_options.source_chunks {
        timings.parallel_source_chunks = artifact_options.source_chunks;
        emitted_parallel = c_emit_native_sources_chunked(
            base, output, output_capacity, entry_module, timings,
            validation_source_ms, parsed_source_cache,
            artifact_options.source_chunks
        );
        if !emitted_parallel {
            io.error("error[OPENC-NATIVE-CHUNK-PROOF]: isolated source emission failed\n");
            memory.free(enum_item_value);
            memory.free(field_next);
            memory.free(aggregate_field_first);
            memory.free(type_aggregate_symbols);
            memory.free(function_local_range_end);
            memory.free(function_local_range_first);
            memory.free(parameter_next);
            memory.free(function_parameter_count);
            memory.free(function_parameter_first);
            memory.free(function_bucket_next);
            memory.free(function_bucket_heads);
            d_buffer_destroy(output);
            return 1;
        }
    }
    if timings.emission_mode == 0 && output_capacity >= 262144 && c_project_source_count(base) >= 16 {
        emitted_parallel = c_emit_sources_parallel(
            base, output, output_capacity, entry_module, timings
        );
    }
    if !emitted_parallel {
        usize module_index = 0;
        while module_index < base.modules.length {
            usize source_first = read_record_field(
                base.module_data, module_index, 2
            );
            usize source_count = read_record_field(
                base.module_data, module_index, 3
            );
            usize source_index = 0;
            while source_index < source_count {
                bool emitted = c_emit_source_record(
                    base, output, module_index,
                    source_first + source_index, entry_module, timings,
                    validate_acceptance, validation_source_ms,
                    parsed_source_cache
                );
                resolution_release_cached_parsed_source(
                    parsed_source_cache, source_first + source_index
                );
                if !emitted {
                    io.print("OPENC-C-BACKEND-SOURCE-FAILED module=");
                    io.print(module_index); io.print(" source=");
                    io.println(source_first + source_index);
                    memory.free(field_next);
                    memory.free(enum_item_value);
                    memory.free(aggregate_field_first);
                    memory.free(type_aggregate_symbols);
                    memory.free(function_local_range_end);
                    memory.free(function_local_range_first);
                    memory.free(parameter_next);
                    memory.free(function_parameter_count);
                    memory.free(function_parameter_first);
                    memory.free(function_bucket_next);
                    memory.free(function_bucket_heads);
                    d_buffer_destroy(output);
                    return 1;
                }
                source_index = source_index + 1;
            }
            module_index = module_index + 1;
        }
    }
    if timings.emission_mode == 1 {
        d_put(output, "\n],\"function_count\":");
        d_put_usize(output, timings.functions);
        d_put(output, ",\"instruction_count\":");
        d_put_usize(output, timings.instructions);
        d_put(output, "}\n");
    } else if timings.emission_mode == 0 {
    d_put(output, "int main(int argc, char **argv) {\n");
    d_put(output, "    int result;\n");
    d_put(output, "    ocb_process_initialize(argc, argv);\n");
    d_put(output, "    result = (int)oc_entry_main();\n");
    d_put(output, "    ocb_process_finalize();\n");
    d_put(output, "    return result;\n}\n");
    }
    if timings.validation_acceptance_errors != 0 {
        io.print("SEMANTIC_ERROR ");
        io.println(timings.validation_acceptance_errors);
        memory.free(enum_item_value);
        memory.free(field_next);
        memory.free(aggregate_field_first);
        memory.free(type_aggregate_symbols);
        memory.free(function_local_range_end);
        memory.free(function_local_range_first);
        memory.free(parameter_next);
        memory.free(function_parameter_count);
        memory.free(function_parameter_first);
        memory.free(function_bucket_next);
        memory.free(function_bucket_heads);
        d_buffer_destroy(output);
        return 1;
    }
    if !output.ok {
        io.print("OPENC-C-BACKEND-BUFFER-EXHAUSTED length=");
        io.print(output.length); io.print(" capacity=");
        io.println(output.capacity);
        memory.free(enum_item_value);
        memory.free(field_next);
        memory.free(aggregate_field_first);
        memory.free(type_aggregate_symbols);
        memory.free(function_local_range_end);
        memory.free(function_local_range_first);
        memory.free(parameter_next);
        memory.free(function_parameter_count);
        memory.free(function_parameter_first);
        memory.free(function_bucket_next);
        memory.free(function_bucket_heads);
        d_buffer_destroy(output);
        return 1;
    }
    timings.output_bytes = output.length;
    status written = status{ code = 1 };
    if timings.emission_mode == 2 {
        if artifact_options.kind == native_artifact_coff_object() {
            written = native_write_coff_object(
                base, output, output_source,
                artifact_options.stable_coff_symbols
            );
        } else if artifact_options.kind == native_artifact_static_library() {
            written = native_write_static_library(base, output, output_source);
        } else if artifact_options.kind == native_artifact_import_library() {
            written = native_write_import_library(
                base, artifact_options.dll_name, output_source
            );
        } else {
            written = native_write_image_options(
                base, output, output_source, artifact_options
            );
        }
    } else {
        written = file.write_text(output_source, d_buffer_text(output));
    }
    d_buffer_destroy(output);
    memory.free(enum_item_value);
    memory.free(field_next);
    memory.free(aggregate_field_first);
    memory.free(type_aggregate_symbols);
    memory.free(function_local_range_end);
    memory.free(function_local_range_first);
    memory.free(parameter_next);
    memory.free(function_parameter_count);
    memory.free(function_parameter_first);
    memory.free(function_bucket_next);
    memory.free(function_bucket_heads);
    if !written.ok {
        io.println("OPENC-C-BACKEND-WRITE-FAILED");
        return 1;
    }
    return 0;
}
