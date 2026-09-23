import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

unsafe usize acceptance_validate_project(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ref PackedBuffer sources,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte validation_source_ms,
    ref BuildTimings timings
) {
    usize errors = acceptance_validate_module_cycles(
        project_source, project_root,
        module_data, modules, source_data
    );
    acceptance_report_count("module_cycles", sources.length, errors);
    usize function_bucket_capacity = ir_index_capacity(
        symbols.length * 2 + 1
    );
    ptr byte function_bucket_heads = memory.alloc(
        function_bucket_capacity * size_of(usize)
    );
    scope memory.free(function_bucket_heads);
    ptr byte function_bucket_next = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(function_bucket_next);
    ptr byte function_parameter_first = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(function_parameter_first);
    ptr byte function_parameter_count = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(function_parameter_count);
    ptr byte parameter_next = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(parameter_next);
    ptr byte function_local_range_first = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(function_local_range_first);
    ptr byte function_local_range_end = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(function_local_range_end);
    ptr byte type_aggregate_symbols = memory.alloc(
        (types.capacity + 1) * size_of(usize)
    );
    scope memory.free(type_aggregate_symbols);
    ptr byte aggregate_field_first = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(aggregate_field_first);
    ptr byte field_next = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(field_next);
    ptr byte enum_item_value = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(enum_item_value);
    ptr byte symbol_export_cache = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    scope memory.free(symbol_export_cache);
    usize export_symbol = 0;
    while export_symbol <= symbols.length {
        write_usize(
            symbol_export_cache, export_symbol * size_of(usize), 0
        );
        export_symbol = export_symbol + 1;
    }
    ptr byte parameter_last = memory.alloc(
        (symbols.length + 1) * size_of(usize)
    );
    PackedBuffer indexed_modules = PackedBuffer{
        length = modules.length, capacity = modules.capacity
    };
    PackedBuffer indexed_types = PackedBuffer{
        length = types.length, capacity = types.capacity
    };
    PackedBuffer indexed_symbols = PackedBuffer{
        length = symbols.length, capacity = symbols.capacity
    };
    IrContext indexed_context = backend_base_context(
        project_source, project_root, module_data, indexed_modules,
        source_data, type_data, indexed_types,
        symbol_data, detail_data, indexed_symbols, 1
    );
    indexed_context.function_bucket_heads = ir_pointer_alias(
        function_bucket_heads
    );
    indexed_context.function_bucket_capacity = function_bucket_capacity;
    indexed_context.function_bucket_next = ir_pointer_alias(
        function_bucket_next
    );
    indexed_context.function_parameter_first = ir_pointer_alias(
        function_parameter_first
    );
    indexed_context.function_parameter_count = ir_pointer_alias(
        function_parameter_count
    );
    indexed_context.parameter_next = ir_pointer_alias(parameter_next);
    indexed_context.function_local_range_first = ir_pointer_alias(
        function_local_range_first
    );
    indexed_context.function_local_range_end = ir_pointer_alias(
        function_local_range_end
    );
    indexed_context.type_aggregate_symbols = ir_pointer_alias(
        type_aggregate_symbols
    );
    indexed_context.aggregate_field_first = ir_pointer_alias(
        aggregate_field_first
    );
    indexed_context.field_next = ir_pointer_alias(field_next);
    indexed_context.enum_item_value = ir_pointer_alias(enum_item_value);
    indexed_context.symbol_export_cache = ir_pointer_alias(
        symbol_export_cache
    );
    ir_initialize_symbol_indexes(indexed_context, parameter_last);
    memory.free(parameter_last);
    bool checked_duplicates = false;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            usize source_started = process.monotonic_milliseconds();
            text loaded_source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_record, out loaded_source
            );
            text source = "";
            if loaded.ok { source = loaded_source; }
            if !loaded.ok { errors = errors + 1; source_index = source_index + 1; continue; }
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
                source, token_data, tokens, diagnostic_data, diagnostics
            );
            PackedBuffer syntax = PackedBuffer{
                length = 0, capacity = tokens.length * 6 + 8
            };
            ptr byte syntax_data = memory.alloc(
                syntax.capacity * record_stride()
            );
            parse_source_syntax(
                source, token_data, tokens,
                syntax_data, syntax, diagnostic_data, diagnostics
            );
            ptr byte scratch = memory.alloc(
                (symbols.length + syntax.length + 32) * size_of(usize)
            );
            ptr byte name_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte call_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte call_argument_first = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte call_argument_last = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte argument_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte type_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte resolved_type_ref_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte left_expression_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte right_expression_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte block_parent_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte control_parent_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte statement_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte block_statement_first = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte statement_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte control_block_first = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte block_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte control_child_first = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte control_child_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte initializer_field_first = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte initializer_field_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte initializer_field_owner = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte array_element_first = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte array_element_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte block_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte control_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte expression_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte call_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte expression_start_heads = memory.alloc(
                (source_length + 1) * size_of(usize)
            );
            ptr byte expression_start_next = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte expression_next_start = memory.alloc(
                (source_length + 1) * size_of(usize)
            );
            ptr byte function_at_position = memory.alloc(
                (source_length + 1) * size_of(usize)
            );
            ptr byte name_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte type_ref_nodes = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte declaration_symbol_cache = memory.alloc(
                (syntax.length + 1) * size_of(usize)
            );
            ptr byte top_symbols = memory.alloc(
                (symbols.length + 1) * size_of(usize)
            );
            ir_initialize_parent_caches(
                syntax, block_parent_cache, control_parent_cache
            );
            usize cache_node = 0;
            while cache_node <= syntax.length {
                write_usize(
                    name_cache, cache_node * size_of(usize), 0
                );
                write_usize(
                    call_cache, cache_node * size_of(usize), 0
                );
                write_usize(
                    type_cache, cache_node * size_of(usize), 0
                );
                write_usize(
                    left_expression_cache,
                    cache_node * size_of(usize),
                    syntax.length + 1
                );
                write_usize(
                    right_expression_cache,
                    cache_node * size_of(usize),
                    syntax.length + 1
                );
                cache_node = cache_node + 1;
            }
            usize symbol = 0;
            while symbol < symbols.length {
                write_usize(scratch, symbol * size_of(usize), 1);
                symbol = symbol + 1;
            }
            PackedBuffer empty = PackedBuffer{ length = 0, capacity = 0 };
            PackedBuffer modules_value = PackedBuffer{
                length = modules.length, capacity = modules.capacity
            };
            PackedBuffer types_value = PackedBuffer{
                length = types.length, capacity = types.capacity
            };
            PackedBuffer symbols_value = PackedBuffer{
                length = symbols.length, capacity = symbols.capacity
            };
            IrContext context = IrContext{
                project_source = project_source,
                project_root = project_root,
                source = source,
                module_data = ir_pointer_alias(module_data),
                modules = modules_value,
                source_data = ir_pointer_alias(source_data),
                type_data = ir_pointer_alias(type_data),
                types = types_value,
                symbol_data = ir_pointer_alias(symbol_data),
                detail_data = ir_pointer_alias(detail_data),
                symbols = symbols_value,
                token_data = ir_pointer_alias(token_data),
                tokens = tokens,
                syntax_data = ir_pointer_alias(syntax_data),
                syntax = syntax,
                module_index = module_index,
                source_record = source_record,
                function_node = 0,
                function_symbol = 0,
                function_result = semantic_type_void(),
                function_local_first = 0,
                function_local_end = 0,
                name_cache = ir_pointer_alias(name_cache),
                spelling_cache = null,
                spelling_cache_capacity = 0,
                call_cache = ir_pointer_alias(call_cache),
                call_argument_first = ir_pointer_alias(
                    call_argument_first
                ),
                call_argument_last = ir_pointer_alias(call_argument_last),
                argument_next = ir_pointer_alias(argument_next),
                type_cache = ir_pointer_alias(type_cache),
                resolved_type_ref_cache = ir_pointer_alias(
                    resolved_type_ref_cache
                ),
                left_expression_cache = ir_pointer_alias(
                    left_expression_cache
                ),
                right_expression_cache = ir_pointer_alias(
                    right_expression_cache
                ),
                typed_expression_cache = null,
                block_parent_cache = ir_pointer_alias(block_parent_cache),
                control_parent_cache = ir_pointer_alias(
                    control_parent_cache
                ),
                statement_nodes = ir_pointer_alias(statement_nodes),
                statement_count = 0,
                block_statement_first = ir_pointer_alias(
                    block_statement_first
                ),
                statement_next = ir_pointer_alias(statement_next),
                control_block_first = ir_pointer_alias(control_block_first),
                block_next = ir_pointer_alias(block_next),
                control_child_first = ir_pointer_alias(control_child_first),
                control_child_next = ir_pointer_alias(control_child_next),
                initializer_field_first = ir_pointer_alias(
                    initializer_field_first
                ),
                initializer_field_next = ir_pointer_alias(
                    initializer_field_next
                ),
                initializer_field_owner = ir_pointer_alias(
                    initializer_field_owner
                ),
                array_element_first = ir_pointer_alias(array_element_first),
                array_element_next = ir_pointer_alias(array_element_next),
                block_nodes = ir_pointer_alias(block_nodes),
                block_count = 0,
                control_nodes = ir_pointer_alias(control_nodes),
                control_count = 0,
                expression_nodes = ir_pointer_alias(expression_nodes),
                expression_count = 0,
                call_nodes = ir_pointer_alias(call_nodes),
                call_count = 0,
                expression_start_heads = ir_pointer_alias(
                    expression_start_heads
                ),
                expression_start_capacity = source_length + 1,
                expression_start_next = ir_pointer_alias(
                    expression_start_next
                ),
                expression_next_start = ir_pointer_alias(
                    expression_next_start
                ),
                function_at_position = ir_pointer_alias(
                    function_at_position
                ),
                name_nodes = ir_pointer_alias(name_nodes),
                name_count = 0,
                type_ref_nodes = ir_pointer_alias(type_ref_nodes),
                type_ref_count = 0,
                declaration_symbol_cache = ir_pointer_alias(
                    declaration_symbol_cache
                ),
                top_symbols = ir_pointer_alias(top_symbols),
                top_symbol_count = 0,
                function_bucket_heads = ir_pointer_alias(
                    function_bucket_heads
                ),
                function_bucket_capacity = function_bucket_capacity,
                function_bucket_next = ir_pointer_alias(
                    function_bucket_next
                ),
                function_parameter_first = ir_pointer_alias(
                    function_parameter_first
                ),
                function_parameter_count = ir_pointer_alias(
                    function_parameter_count
                ),
                parameter_next = ir_pointer_alias(parameter_next),
                function_local_range_first = ir_pointer_alias(
                    function_local_range_first
                ),
                function_local_range_end = ir_pointer_alias(
                    function_local_range_end
                ),
                type_aggregate_symbols = ir_pointer_alias(
                    type_aggregate_symbols
                ),
                aggregate_field_first = ir_pointer_alias(
                    aggregate_field_first
                ),
                field_next = ir_pointer_alias(field_next),
                enum_item_value = ir_pointer_alias(enum_item_value),
                symbol_export_cache = ir_pointer_alias(
                    symbol_export_cache
                ),
                native_layout_size_cache = null,
                native_layout_alignment_cache = null,
                native_layout_state_cache = null,
                local_values = ir_pointer_alias(scratch),
                block_data = ir_pointer_alias(scratch),
                blocks = empty,
                instruction_data = ir_pointer_alias(scratch),
                instruction_detail = ir_pointer_alias(scratch),
                instructions = empty,
                operand_data = ir_pointer_alias(scratch),
                operands = empty,
                break_data = ir_pointer_alias(scratch),
                break_depth = 0,
                continue_data = ir_pointer_alias(scratch),
                continue_depth = 0,
                current_block = 0,
                next_value = 1,
                profile_statement_candidates = 0,
                profile_parent_candidates = 0,
                profile_expression_positions = 0,
                profile_syntax_candidates = 0,
                profile_symbol_candidates = 0,
                profile_type_queries_enabled = timings.profile_type_queries_enabled,
                profile_type_seen = null,
                profile_type_queries = 0,
                profile_type_cache_hits = 0,
                profile_type_uncached = 0,
                profile_type_distinct_uncached = 0,
                profile_type_repeated_uncached = 0,
                profile_type_failures = 0,
                profile_type_name_uncached = 0,
                profile_type_literal_uncached = 0,
                profile_type_unary_uncached = 0,
                profile_type_binary_uncached = 0,
                profile_type_assignment_uncached = 0,
                profile_type_call_uncached = 0,
                profile_type_other_uncached = 0,
                suppress_acceptance_diagnostics = false
            };
            ir_initialize_node_indexes(context);
            ir_initialize_parent_position_caches(context);
            ir_initialize_control_adjacency(context);
            ir_initialize_statement_adjacency(context);
            ir_initialize_initializer_fields(context);
            ir_initialize_array_elements(context);
            ir_initialize_declaration_symbols(context);
            ir_initialize_function_positions(context);
            if !checked_duplicates {
                usize duplicates = acceptance_validate_duplicate_functions(
                    context
                );
                acceptance_report_count(
                    "duplicate_functions", source_record, duplicates
                );
                errors = errors + duplicates;
                checked_duplicates = true;
            }
            errors = errors + acceptance_validate_context(context, timings);
            timings.validation_type_queries = timings.validation_type_queries +
                context.profile_type_queries;
            timings.validation_type_cache_hits =
                timings.validation_type_cache_hits +
                context.profile_type_cache_hits;
            timings.validation_type_uncached =
                timings.validation_type_uncached +
                context.profile_type_uncached;
            timings.validation_type_failures =
                timings.validation_type_failures +
                context.profile_type_failures;
            timings.validation_type_name_uncached =
                timings.validation_type_name_uncached +
                context.profile_type_name_uncached;
            timings.validation_type_literal_uncached =
                timings.validation_type_literal_uncached +
                context.profile_type_literal_uncached;
            timings.validation_type_unary_uncached =
                timings.validation_type_unary_uncached +
                context.profile_type_unary_uncached;
            timings.validation_type_binary_uncached =
                timings.validation_type_binary_uncached +
                context.profile_type_binary_uncached;
            timings.validation_type_assignment_uncached =
                timings.validation_type_assignment_uncached +
                context.profile_type_assignment_uncached;
            timings.validation_type_call_uncached =
                timings.validation_type_call_uncached +
                context.profile_type_call_uncached;
            timings.validation_type_other_uncached =
                timings.validation_type_other_uncached +
                context.profile_type_other_uncached;
            write_usize(
                validation_source_ms,
                source_record * size_of(usize),
                read_usize(
                    validation_source_ms,
                    source_record * size_of(usize)
                ) + process.monotonic_milliseconds() - source_started
            );
            types = context.types;
            memory.free(top_symbols);
            memory.free(declaration_symbol_cache);
            memory.free(type_ref_nodes);
            memory.free(name_nodes);
            memory.free(expression_next_start);
            memory.free(function_at_position);
            memory.free(expression_start_next);
            memory.free(expression_start_heads);
            memory.free(expression_nodes);
            memory.free(call_nodes);
            memory.free(control_nodes);
            memory.free(block_nodes);
            memory.free(array_element_next);
            memory.free(array_element_first);
            memory.free(initializer_field_owner);
            memory.free(initializer_field_next);
            memory.free(initializer_field_first);
            memory.free(control_child_next);
            memory.free(control_child_first);
            memory.free(block_next);
            memory.free(control_block_first);
            memory.free(statement_next);
            memory.free(block_statement_first);
            memory.free(statement_nodes);
            memory.free(control_parent_cache);
            memory.free(block_parent_cache);
            memory.free(right_expression_cache);
            memory.free(left_expression_cache);
            memory.free(resolved_type_ref_cache);
            memory.free(type_cache);
            memory.free(argument_next);
            memory.free(call_argument_last);
            memory.free(call_argument_first);
            memory.free(call_cache);
            memory.free(name_cache);
            memory.free(scratch);
            memory.free(syntax_data);
            memory.free(diagnostic_data);
            memory.free(token_data);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    return errors;
}
