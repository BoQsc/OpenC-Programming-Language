import system.file;
import system.memory;
import system.text;

unsafe void acceptance_mask_external_declarations(ref IrContext context) {
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 2 {
            usize start = read_record_field(
                context.syntax_data, declaration, 1
            );
            if starts_with_ascii(context.source, start, "external") {
                usize child = 0;
                while child < context.syntax.length {
                    if child == declaration || semantic_node_contains(
                        context.syntax_data, declaration, child
                    ) {
                        write_record_field(
                            context.syntax_data, child, 0, 0
                        );
                    }
                    child = child + 1;
                }
            }
        }
        declaration = declaration + 1;
    }
}

unsafe usize acceptance_validate_context(ref IrContext context) {
    acceptance_mask_external_declarations(context);
    usize errors = 0;
    errors = errors + acceptance_validate_type_refs(context);
    errors = errors + acceptance_validate_fields(context);
    errors = errors + acceptance_validate_locals(context);
    errors = errors + acceptance_validate_assignments(context);
    errors = errors + acceptance_validate_binary(context);
    errors = errors + acceptance_validate_conditions(context);
    errors = errors + acceptance_validate_index_ranges(context);
    errors = errors + acceptance_validate_casts(context);
    errors = errors + acceptance_validate_aggregates(context);
    errors = errors + acceptance_validate_functions(context);
    errors = errors + acceptance_validate_scopes(context);
    errors = errors + acceptance_validate_enums(context);
    errors = errors + acceptance_validate_overload_calls(context);
    errors = errors + acceptance_validate_slice_aliases(context);
    errors = errors + acceptance_validate_calls(context);
    errors = errors + acceptance_validate_storage(context);
    errors = errors + acceptance_validate_import_aliases(context);
    errors = errors + acceptance_validate_optional_proofs(context);
    errors = errors + acceptance_validate_pointer_ownership(context);
    errors = errors + acceptance_validate_pointer_order(context);
    return errors;
}

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
    ref PackedBuffer symbols
) {
    usize errors = acceptance_validate_module_cycles(
        project_source, project_root,
        module_data, modules, source_data
    );
    bool checked_duplicates = false;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            text source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_record, out source
            );
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
                expression_start_heads = null,
                expression_start_capacity = 0,
                expression_start_next = null,
                expression_next_start = null,
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
                profile_symbol_candidates = 0
            };
            if !checked_duplicates {
                errors = errors + acceptance_validate_duplicate_functions(
                    context
                );
                checked_duplicates = true;
            }
            errors = errors + acceptance_validate_context(context);
            types = context.types;
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
