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
    bool c_backend
) {
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

    usize semantic_capacity = total_source_length + project_length + 65536;
    usize output_capacity = total_source_length * 8 + project_length + 65536;
    PackedBuffer types = PackedBuffer{
        length = 0, capacity = semantic_capacity
    };
    PackedBuffer symbols = PackedBuffer{
        length = 0, capacity = semantic_capacity
    };
    PackedBuffer errors = PackedBuffer{
        length = 0, capacity = semantic_capacity
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

    module_index = 0;
    while module_index < modules.length {
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        usize index = 0;
        while index < count {
            usize source_record = first + index;
            semantic_predeclare_source(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_record, type_data, types
            );
            index = index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize first = read_record_field(module_data, module_index, 2);
        usize count = read_record_field(module_data, module_index, 3);
        usize index = 0;
        while index < count {
            usize source_record = first + index;
            resolution_collect_source_symbols(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_record,
                type_data, types, symbol_data, detail_data, symbols
            );
            index = index + 1;
        }
        module_index = module_index + 1;
    }
    usize acceptance_errors = 0;
    if validate_semantics {
        module_index = 0;
        while module_index < modules.length {
            usize first = read_record_field(module_data, module_index, 2);
            usize count = read_record_field(module_data, module_index, 3);
            usize index = 0;
            while index < count {
                usize source_record = first + index;
                flow_precheck_source(
                    project_source, project_root, module_data, modules,
                    source_data, module_index, source_record,
                    type_data, symbol_data, detail_data, symbols,
                    error_data, errors
                );
                flow_validate_source(
                    project_source, project_root, module_data, modules,
                    source_data, module_index, source_record,
                    type_data, symbol_data, detail_data, symbols,
                    error_data, errors
                );
                index = index + 1;
            }
            module_index = module_index + 1;
        }
        acceptance_errors = acceptance_validate_project(
            project_source, project_root, module_data, modules,
            source_data, sources, type_data, types,
            symbol_data, detail_data, symbols
        );
    }
    if errors.length + acceptance_errors != 0 { return 1; }

    usize entry = ir_entry_module(
        project_source, project_root, source_data,
        symbol_data, detail_data, symbols, modules.length
    );
    usize next_value = 1;
    IrContext base = IrContext{
        project_source = project_source,
        project_root = project_root,
        source = "",
        module_data = ir_pointer_alias(module_data),
        modules = modules,
        source_data = ir_pointer_alias(source_data),
        type_data = ir_pointer_alias(type_data),
        types = types,
        symbol_data = ir_pointer_alias(symbol_data),
        detail_data = ir_pointer_alias(detail_data),
        symbols = symbols,
        token_data = null,
        tokens = PackedBuffer{ length = 0, capacity = 0 },
        syntax_data = null,
        syntax = PackedBuffer{ length = 0, capacity = 0 },
        module_index = 0,
        source_record = 0,
        function_node = 0,
        function_symbol = 0,
        function_result = 0,
        function_local_first = 0,
        function_local_end = 0,
        name_cache = null,
        call_cache = null,
        local_values = null,
        block_data = null,
        blocks = PackedBuffer{ length = 0, capacity = 0 },
        instruction_data = null,
        instruction_detail = null,
        instructions = PackedBuffer{ length = 0, capacity = 0 },
        operand_data = null,
        operands = PackedBuffer{ length = 0, capacity = 0 },
        break_data = null,
        break_depth = 0,
        continue_data = null,
        continue_depth = 0,
        current_block = 0,
        next_value = next_value
    };
    if c_backend {
        return c_emit_project(
            base, output_directory, output_capacity, entry
        );
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
                call_cache = ir_pointer_alias(call_cache),
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
                next_value = next_value
            };
            usize node = 0;
            while node < syntax.length {
                if read_record_field(syntax_data, node, 0) == 2 {
                    usize body = flow_largest_direct_block(
                        syntax_data, syntax, node
                    );
                    usize owner = resolution_find_owner_symbol(
                        symbol_data, detail_data, symbols,
                        source_record, node,
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
    return 0;
}
