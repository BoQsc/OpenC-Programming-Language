import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe i32 emit_bootstrap_d_mode(
    text project_path,
    text output_directory,
    bool validate_semantics,
    bool c_backend,
    ref BuildTimings timings
) {
    NativeArtifactOptions options = native_artifact_default_options();
    return emit_bootstrap_d_mode_artifact(
        project_path, output_directory, validate_semantics,
        c_backend, timings, options
    );
}

unsafe i32 emit_bootstrap_d_mode_artifact(
    text project_path,
    text output_directory,
    bool validate_semantics,
    bool c_backend,
    ref BuildTimings timings,
    ref NativeArtifactOptions artifact_options
) {
    usize total_started = process.monotonic_milliseconds();
    usize phase_started = total_started;
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok { return 1; }
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
    ) { return 1; }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !loaded.ok { return 1; }
            total_source_length = total_source_length + text.byte_length(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    timings.project_load_ms =
        process.monotonic_milliseconds() - phase_started;
    timings.source_files = sources.length;
    timings.source_bytes = total_source_length;
    if timings.emission_mode == 2 && artifact_options.source_chunks == 0 {
        timings.auto_source_chunks = true;
        // The opt-in policy keeps tiny projects serial and caps the input
        // size on which it will duplicate native worker state. Four chunks
        // target substantial multi-file work; two cover the middle range.
        if sources.length >= 4 && total_source_length >= 524288 &&
            total_source_length <= 3145728 {
            artifact_options.source_chunks = 4;
        } else if sources.length >= 2 &&
            total_source_length >= 196608 &&
            total_source_length <= 4194304 {
            artifact_options.source_chunks = 2;
        } else {
            artifact_options.source_chunks = 1;
        }
    }

    usize semantic_type_capacity =
        total_source_length / 8 + project_length + 65536;
    usize semantic_symbol_capacity =
        total_source_length / 4 + project_length + 65536;
    usize semantic_error_capacity =
        total_source_length / 4 + project_length + 65536;
    usize output_capacity = total_source_length * 8 + project_length + 65536;
    PackedBuffer types = PackedBuffer{
        length = 0, capacity = semantic_type_capacity
    };
    PackedBuffer symbols = PackedBuffer{
        length = 0, capacity = semantic_symbol_capacity
    };
    PackedBuffer errors = PackedBuffer{
        length = 0, capacity = semantic_error_capacity
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

    // Native lowering reuses the exact parsed records produced by resolution.
    // The cache is proportional to live token/syntax records, not parser
    // capacity estimates, and is released on every return from this build.
    ptr byte parsed_source_cache = null;
    if c_backend && timings.emission_mode != 0 {
        parsed_source_cache = memory.alloc(
            (sources.length + 1) * record_stride()
        );
    }
    scope resolution_release_parse_cache(
        parsed_source_cache, sources.length
    );

    phase_started = process.monotonic_milliseconds();
    module_index = 0;
    while module_index < modules.length {
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        usize index = 0;
        while index < count {
            usize source_record = first + index;
            if parsed_source_cache != null {
                ResolutionParsedSource parsed =
                    resolution_parse_source_retained(
                        project_source, project_root,
                        source_data, source_record
                    );
                if parsed.token_data != null {
                    text source;
                    status source_status = project_read_source_record(
                        project_source, project_root, source_data,
                        source_record, out source
                    );
                    if source_status.ok {
                        semantic_predeclare_parsed_source(
                            project_source, project_root,
                            module_data, modules, source_data,
                            module_index, source_record, type_data, types,
                            source, parsed.token_data, parsed.tokens,
                            parsed.syntax_data, parsed.syntax
                        );
                    }
                }
                resolution_cache_parsed_source(
                    parsed_source_cache, source_record, parsed
                );
                if !parsed.reusable {
                    resolution_release_parsed_source(parsed);
                }
            } else {
                semantic_predeclare_source(
                    project_source, project_root, module_data, modules,
                    source_data, module_index, source_record,
                    type_data, types
                );
            }
            index = index + 1;
        }
        module_index = module_index + 1;
    }
    timings.declarations_ms =
        process.monotonic_milliseconds() - phase_started;
    phase_started = process.monotonic_milliseconds();
    module_index = 0;
    while module_index < modules.length {
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        usize index = 0;
        while index < count {
            usize source_record = first + index;
            if parsed_source_cache != null {
                ResolutionParsedSource parsed =
                    resolution_cached_parsed_source(
                        parsed_source_cache, source_record
                    );
                if parsed.reusable {
                    text source;
                    status source_status = project_read_source_record(
                        project_source, project_root, source_data,
                        source_record, out source
                    );
                    if source_status.ok {
                        resolution_collect_parsed_source_symbols(
                            project_source, project_root,
                            module_data, modules, source_data,
                            module_index, source_record,
                            type_data, types,
                            symbol_data, detail_data, symbols,
                            source, parsed.token_data, parsed.tokens,
                            parsed.syntax_data, parsed.syntax
                        );
                    }
                } else {
                    resolution_collect_source_symbols(
                        project_source, project_root,
                        module_data, modules, source_data,
                        module_index, source_record,
                        type_data, types,
                        symbol_data, detail_data, symbols
                    );
                }
            } else {
                resolution_collect_source_symbols(
                    project_source, project_root, module_data, modules,
                    source_data, module_index, source_record,
                    type_data, types, symbol_data, detail_data, symbols
                );
            }
            index = index + 1;
        }
        module_index = module_index + 1;
    }
    timings.resolution_ms =
        process.monotonic_milliseconds() - phase_started;
    phase_started = process.monotonic_milliseconds();
    usize acceptance_errors = 0;
    bool fuse_native_acceptance = false;
    ptr byte validation_source_ms = memory.alloc(
        (sources.length + 1) * size_of(usize)
    );
    scope memory.free(validation_source_ms);
    if validate_semantics {
        usize validation_source = 0;
        while validation_source <= sources.length {
            write_usize(
                validation_source_ms,
                validation_source * size_of(usize),
                0
            );
            validation_source = validation_source + 1;
        }
        timings.validation_initial_live_bytes =
            compiler_live_allocation_bytes();
        usize flow_started = process.monotonic_milliseconds();
        bool project_has_pointer_symbol = flow_project_has_pointer_symbol(
            type_data, symbol_data, symbols
        );
        bool project_has_unsafe_function =
            flow_project_has_unsafe_function(
                project_source, project_root, source_data,
                symbol_data, detail_data, symbols
            );
        bool parallel_flow = c_backend && timings.emission_mode == 2 &&
            (artifact_options.source_chunks == 2 ||
             artifact_options.source_chunks == 4) &&
            sources.length >= 2 && total_source_length >= 196608;
        if parallel_flow {
            usize flow_worker_count = 2;
            if artifact_options.source_chunks == 4 &&
                sources.length >= 32 && total_source_length >= 1048576 {
                flow_worker_count = 4;
            }
            timings.parallel_flow_workers = flow_worker_count;
            if !flow_validate_project_parallel(
                project_source, project_root, module_data, modules,
                source_data, sources, type_data, symbol_data, detail_data,
                symbols, project_has_pointer_symbol,
                project_has_unsafe_function, parsed_source_cache,
                validation_source_ms, error_data, errors, timings,
                flow_worker_count
            ) {
                timings.validation_ms =
                    process.monotonic_milliseconds() - phase_started;
                timings.total_ms =
                    process.monotonic_milliseconds() - total_started;
                return 1;
            }
        } else {
        module_index = 0;
        while module_index < modules.length {
            usize first = read_record_field(module_data, module_index, 2);
            usize count = read_record_field(module_data, module_index, 3);
            usize index = 0;
            while index < count {
                usize source_record = first + index;
                usize source_started = process.monotonic_milliseconds();
                flow_validate_source(
                    project_source, project_root, module_data, modules,
                    source_data, module_index, source_record,
                    type_data, symbol_data, detail_data, symbols,
                    project_has_pointer_symbol,
                    project_has_unsafe_function,
                    parsed_source_cache,
                    error_data, errors, timings
                );
                write_usize(
                    validation_source_ms,
                    source_record * size_of(usize),
                    process.monotonic_milliseconds() - source_started
                );
                usize validation_live = compiler_live_allocation_bytes();
                if validation_live > timings.validation_peak_live_bytes {
                    timings.validation_peak_live_bytes = validation_live;
                    timings.validation_peak_source_record = source_record;
                }
                timings.validation_file_cache_hits =
                    compiler_file_cache_hits();
                timings.validation_file_cache_misses =
                    compiler_file_cache_misses();
                timings.validation_path_cache_hits =
                    compiler_path_cache_hits();
                timings.validation_path_cache_misses =
                    compiler_path_cache_misses();
                if validation_live > 402653184 {
                    io.error("error[OPENC-VALIDATION-MEMORY-BUDGET]: live allocation payload exceeds 384 MiB; see timing report\n");
                    timings.validation_ms =
                        process.monotonic_milliseconds() - phase_started;
                    timings.total_ms =
                        process.monotonic_milliseconds() - total_started;
                    return 1;
                }
                index = index + 1;
            }
            module_index = module_index + 1;
        }
        }
        timings.validation_flow_ms =
            process.monotonic_milliseconds() - flow_started;
        fuse_native_acceptance = c_backend &&
            timings.emission_mode == 2 && errors.length == 0;
        if !fuse_native_acceptance {
            usize acceptance_started = process.monotonic_milliseconds();
            acceptance_errors = acceptance_validate_project(
                project_source, project_root, module_data, modules,
                source_data, sources, type_data, types,
                symbol_data, detail_data, symbols,
                validation_source_ms, timings
            );
            timings.validation_acceptance_ms =
                process.monotonic_milliseconds() - acceptance_started;
            validation_source = 0;
            while validation_source < sources.length {
                build_timings_record_validation_source(
                    timings,
                    validation_source,
                    read_usize(
                        validation_source_ms,
                        validation_source * size_of(usize)
                    )
                );
                validation_source = validation_source + 1;
            }
        }
    }
    timings.validation_ms =
        process.monotonic_milliseconds() - phase_started;
    if errors.length + acceptance_errors != 0 {
        if errors.length != 0 {
            flow_emit_errors(module_data, modules, error_data, errors);
        }
        if acceptance_errors != 0 {
            io.print("SEMANTIC_ERROR ");
            io.println(acceptance_errors);
        }
        timings.total_ms =
            process.monotonic_milliseconds() - total_started;
        return 1;
    }

    // Public `openc check` uses the production flow and acceptance pipeline
    // but does not need IR lowering, machine-code emission, or a PE image.
    if timings.emission_mode == 3 {
        timings.total_ms =
            process.monotonic_milliseconds() - total_started;
        return 0;
    }

    usize entry = ir_entry_module(
        project_source, project_root, source_data,
        symbol_data, detail_data, symbols, modules.length
    );
    usize next_value = 1;
    IrContext base = backend_base_context(
        project_source, project_root, module_data, modules,
        source_data, type_data, types, symbol_data, detail_data,
        symbols, next_value
    );
    phase_started = process.monotonic_milliseconds();
    if c_backend {
        i32 c_result = c_emit_project(
            base, output_directory, output_capacity, entry, timings,
            fuse_native_acceptance, validation_source_ms,
            parsed_source_cache, artifact_options
        );
        usize lowering_elapsed =
            process.monotonic_milliseconds() - phase_started;
        if fuse_native_acceptance {
            usize validation_source = 0;
            while validation_source < sources.length {
                build_timings_record_validation_source(
                    timings,
                    validation_source,
                    read_usize(
                        validation_source_ms,
                        validation_source * size_of(usize)
                    )
                );
                validation_source = validation_source + 1;
            }
            if timings.parallel_source_chunks != 0 {
                // Worker acceptance timings are summed elapsed times, not
                // wall time; the whole fused stage belongs in this phase.
                timings.validation_ms = timings.validation_flow_ms;
            } else {
                timings.validation_ms = timings.validation_flow_ms +
                    timings.validation_acceptance_ms;
                if lowering_elapsed >= timings.validation_acceptance_ms {
                    lowering_elapsed = lowering_elapsed -
                        timings.validation_acceptance_ms;
                }
            }
        }
        timings.lowering_emit_ms = lowering_elapsed;
        timings.total_ms =
            process.monotonic_milliseconds() - total_started;
        return c_result;
    }
    module_index = 0;
    while module_index < modules.length {
        base.module_index = module_index;
        text module_name = project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        );
        DBuffer output = d_buffer_create(output_capacity);
        d_emit_header(base, output, module_name);
        d_emit_type_declarations(base, output, module_index);

        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            text source;
            status emission_loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_record, out source
            );
            if !emission_loaded.ok { d_buffer_destroy(output); return 1; }
            usize source_length = text.byte_length(source);
            PackedBuffer tokens = PackedBuffer{
                length = 0, capacity = source_length + 2
            };
            PackedBuffer diagnostics = PackedBuffer{
                length = 0, capacity = source_length * 4 + 8
            };
            ptr byte token_data = memory.alloc(
                tokens.capacity * record_stride()
            );
            ptr byte diagnostic_data = memory.alloc(
                diagnostics.capacity * record_stride()
            );
            lex_source(
                source, token_data, tokens,
                diagnostic_data, diagnostics
            );
            PackedBuffer syntax = PackedBuffer{
                length = 0, capacity = tokens.length * 6 + 8
            };
            ptr byte syntax_data = memory.alloc(
                syntax.capacity * record_stride()
            );
            parse_source_syntax(
                source, token_data, tokens, syntax_data, syntax,
                diagnostic_data, diagnostics
            );
            PackedBuffer blocks = PackedBuffer{
                length = 0, capacity = source_length + 32
            };
            PackedBuffer instructions = PackedBuffer{
                length = 0, capacity = source_length * 3 + 64
            };
            PackedBuffer operands = PackedBuffer{
                length = 0, capacity = source_length * 4 + 64
            };
            ptr byte block_data = memory.alloc(blocks.capacity * record_stride());
            ptr byte instruction_data = memory.alloc(
                instructions.capacity * record_stride()
            );
            ptr byte instruction_detail = memory.alloc(
                instructions.capacity * record_stride()
            );
            ptr byte operand_data = memory.alloc(
                operands.capacity * record_stride()
            );
            ptr byte local_values = memory.alloc(
                (symbols.length + 1) * size_of(usize)
            );
            ptr byte name_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte call_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            usize cache_node = 0;
            while cache_node <= syntax.length {
                write_usize(
                    name_cache, cache_node * size_of(usize), 0
                );
                write_usize(
                    call_cache, cache_node * size_of(usize), 0
                );
                cache_node = cache_node + 1;
            }
            ptr byte break_data = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte continue_data = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            IrContext context = IrContext{
                project_source = project_source,
                project_root = project_root,
                source = source,
                module_data = ir_pointer_alias(module_data),
                modules = modules,
                source_data = ir_pointer_alias(source_data),
                type_data = ir_pointer_alias(type_data),
                types = types,
                symbol_data = ir_pointer_alias(symbol_data),
                detail_data = ir_pointer_alias(detail_data),
                symbols = symbols,
                token_data = ir_pointer_alias(token_data),
                tokens = tokens,
                syntax_data = ir_pointer_alias(syntax_data),
                syntax = syntax,
                module_index = module_index,
                source_record = source_record,
                function_node = 0,
                function_symbol = 0,
                function_result = 0,
                function_local_first = 0,
                function_local_end = 0,
                name_cache = ir_pointer_alias(name_cache),
                spelling_cache = null,
                spelling_cache_capacity = 0,
                call_cache = ir_pointer_alias(call_cache),
                call_argument_first = null,
                call_argument_last = null,
                argument_next = null,
                type_cache = null,
                resolved_type_ref_cache = null,
                left_expression_cache = null,
                right_expression_cache = null,
                block_parent_cache = null,
                control_parent_cache = null,
                statement_nodes = null,
                statement_count = 0,
                block_statement_first = null,
                statement_next = null,
                control_block_first = null,
                block_next = null,
                control_child_first = null,
                control_child_next = null,
                initializer_field_first = null,
                initializer_field_next = null,
                initializer_field_owner = null,
                array_element_first = null,
                array_element_next = null,
                block_nodes = null,
                block_count = 0,
                control_nodes = null,
                control_count = 0,
                expression_nodes = null,
                expression_count = 0,
                call_nodes = null,
                call_count = 0,
                expression_start_heads = null,
                expression_start_capacity = 0,
                expression_start_next = null,
                expression_next_start = null,
                function_at_position = null,
                name_nodes = null,
                name_count = 0,
                type_ref_nodes = null,
                type_ref_count = 0,
                declaration_symbol_cache = null,
                top_symbols = null,
                top_symbol_count = 0,
                function_bucket_heads = null,
                function_bucket_capacity = 0,
                function_bucket_next = null,
                function_parameter_first = null,
                function_parameter_count = null,
                parameter_next = null,
                function_local_range_first = null,
                function_local_range_end = null,
                type_aggregate_symbols = null,
                aggregate_field_first = null,
                field_next = null,
                enum_item_value = null,
                symbol_export_cache = null,
                native_layout_size_cache = null,
                native_layout_alignment_cache = null,
                native_layout_state_cache = null,
                local_values = ir_pointer_alias(local_values),
                block_data = ir_pointer_alias(block_data),
                blocks = blocks,
                instruction_data = ir_pointer_alias(instruction_data),
                instruction_detail = ir_pointer_alias(instruction_detail),
                instructions = instructions,
                operand_data = ir_pointer_alias(operand_data),
                operands = operands,
                break_data = ir_pointer_alias(break_data),
                break_depth = 0,
                continue_data = ir_pointer_alias(continue_data),
                continue_depth = 0,
                current_block = 0,
                next_value = next_value,
                profile_statement_candidates = 0,
                profile_parent_candidates = 0,
                profile_expression_positions = 0,
                profile_syntax_candidates = 0,
                profile_symbol_candidates = 0,
                suppress_acceptance_diagnostics = false
            };
            ir_initialize_local_values(context);
            usize node = 0;
            while node < syntax.length {
                if read_record_field(syntax_data, node, 0) == 2 {
                    usize body = ir_largest_direct_block(context, node);
                    usize owner = ir_owner_symbol(
                        context, node,
                        resolution_symbol_function(), 0
                    );
                    if body >= syntax.length || owner == 0 || byte_at_or_zero(
                            source,
                            read_record_field(syntax_data, body, 1)
                        ) != 123 {
                        io.print("OPENC-D-BACKEND-INTERNAL source=");
                        io.print(source_record);
                        io.print(" node=");
                        io.print(node);
                        io.print(" body=");
                        io.print(body);
                        io.print(" syntax=");
                        io.print(syntax.length);
                        io.print(" start=");
                        io.print(read_record_field(syntax_data, body, 1));
                        io.print(" byte=");
                        io.print(cast(usize, byte_at_or_zero(
                            source,
                            read_record_field(syntax_data, body, 1)
                        )));
                        io.print(" length=");
                        io.print(text.byte_length(source));
                        io.print(" owner=");
                        io.println(owner);
                        d_buffer_destroy(output);
                        return 1;
                    }
                    ir_lower_function(context, node, owner - 1);
                    d_emit_function(context, output, owner - 1, entry);
                }
                node = node + 1;
            }
            next_value = context.next_value;
            types = context.types;
            memory.free(continue_data);
            memory.free(break_data);
            memory.free(call_cache);
            memory.free(name_cache);
            memory.free(local_values);
            memory.free(operand_data);
            memory.free(instruction_detail);
            memory.free(instruction_data);
            memory.free(block_data);
            memory.free(syntax_data);
            memory.free(diagnostic_data);
            memory.free(token_data);
            source_index = source_index + 1;
        }
        if module_index == entry {
            d_put(output, "int main(string[] args) {\n");
            d_put(output, "    initializeArguments(args.length > 1 ? args[1 .. $] : []);\n");
            d_put(output, "    try return cast(int) __openc_entry_main();\n");
            d_put(output, "    catch (OpenCCheckedFailure failure) return reportOpenCFailure(failure);\n");
            d_put(output, "    catch (OpenCTargetFault failure) return reportOpenCFailure(failure);\n");
            d_put(output, "}\n");
        }
        if !d_write_buffer(output_directory, module_name, output) {
            d_buffer_destroy(output);
            return 1;
        }
        d_buffer_destroy(output);
        module_index = module_index + 1;
    }

    base.types = types;
    if !d_emit_builtin_module(base, output_directory, "system.file") ||
        !d_emit_builtin_module(base, output_directory, "system.io") ||
        !d_emit_builtin_module(base, output_directory, "system.memory") ||
        !d_emit_builtin_module(base, output_directory, "system.path") ||
        !d_emit_builtin_module(base, output_directory, "system.process") ||
        !d_emit_builtin_module(base, output_directory, "system.text") {
        return 1;
    }
    timings.lowering_emit_ms =
        process.monotonic_milliseconds() - phase_started;
    timings.total_ms =
        process.monotonic_milliseconds() - total_started;
    return 0;
}
