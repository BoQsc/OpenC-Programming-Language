import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool c_emit_source_record(
    ref IrContext base,
    ref DBuffer output,
    usize module_index,
    usize source_record,
    usize entry_module,
    ref BuildTimings timings,
    bool validate_acceptance,
    ptr byte validation_source_ms,
    ptr byte parsed_source_cache
) {
    usize phase_started = process.monotonic_milliseconds();
    text source;
    status loaded = project_read_source_record(
        base.project_source, base.project_root, base.source_data,
        source_record, out source
    );
    if !loaded.ok { return false; }
    usize source_length = text.byte_length(source);
    ResolutionParsedSource parsed = resolution_cached_parsed_source(
        parsed_source_cache, source_record
    );
    bool parsed_source_reused = parsed.reusable;
    PackedBuffer tokens = parsed.tokens;
    ptr byte token_data = parsed.token_data;
    PackedBuffer syntax = parsed.syntax;
    ptr byte syntax_data = parsed.syntax_data;
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = 0 };
    ptr byte diagnostic_data = null;
    if !parsed_source_reused {
        tokens = PackedBuffer{
            length = 0, capacity = source_length + 2
        };
        diagnostics = PackedBuffer{
            length = 0, capacity = source_length * 4 + 8
        };
        token_data = memory.alloc(
            tokens.capacity * record_stride()
        );
        diagnostic_data = memory.alloc(
            diagnostics.capacity * record_stride()
        );
        lex_source(
            source, token_data, tokens,
            diagnostic_data, diagnostics
        );
        syntax = PackedBuffer{
            length = 0, capacity = tokens.length * 6 + 8
        };
        syntax_data = memory.alloc(
            syntax.capacity * record_stride()
        );
        parse_source_syntax(
            source, token_data, tokens, syntax_data, syntax,
            diagnostic_data, diagnostics
        );
    }
    if diagnostics.length != 0 {
        io.error("error[OPENC-BACKEND-SYNTAX]: refusing to lower malformed source\n");
        if !parsed_source_reused {
            memory.free(syntax_data);
            memory.free(diagnostic_data);
            memory.free(token_data);
        }
        return false;
    }
    timings.lex_parse_ms = timings.lex_parse_ms +
        process.monotonic_milliseconds() - phase_started;
    timings.syntax_nodes = timings.syntax_nodes + syntax.length;
    PackedBuffer blocks = PackedBuffer{
        length = 0, capacity = syntax.length / 2 + 32
    };
    PackedBuffer instructions = PackedBuffer{
        length = 0, capacity = syntax.length + 64
    };
    PackedBuffer operands = PackedBuffer{
        length = 0, capacity = syntax.length * 2 + 64
    };
    ptr byte block_data = memory.alloc(
        blocks.capacity * record_stride()
    );
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
        (base.symbols.length + 1) * size_of(usize)
    );
    ptr byte typed_expression_cache = memory.alloc(
        (syntax.length + 1) * 4 * size_of(usize)
    );
    // Spelling-only caching is not scope-safe when locals are shadowed.
    usize spelling_cache_capacity = 0;
    ptr byte spelling_cache = null;
    ptr byte call_argument_first = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte call_argument_last = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte argument_next = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte profile_type_seen = null;
    if base.profile_type_queries_enabled {
        profile_type_seen = memory.alloc(
            (syntax.length + 1) * size_of(usize)
        );
        if profile_type_seen != null {
            usize profile_node = 0;
            while profile_node <= syntax.length {
                write_usize(
                    profile_type_seen,
                    profile_node * size_of(usize), 0
                );
                profile_node = profile_node + 1;
            }
        }
    }
    ptr byte resolved_type_ref_cache = memory.alloc(
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
        (base.symbols.length + 1) * size_of(usize)
    );
    ir_initialize_parent_caches(
        syntax, block_parent_cache, control_parent_cache
    );
    usize cache_node = 0;
    while cache_node <= syntax.length {
        usize base = cache_node * 4 * size_of(usize);
        write_usize(typed_expression_cache, base, 0);
        write_usize(typed_expression_cache, base + size_of(usize), 0);
        write_usize(
            typed_expression_cache,
            base + 2 * size_of(usize),
            syntax.length + 1
        );
        write_usize(
            typed_expression_cache,
            base + 3 * size_of(usize),
            syntax.length + 1
        );
        cache_node = cache_node + 1;
    }
    usize spelling_entry = 0;
    while spelling_entry < spelling_cache_capacity {
        write_record_field(spelling_cache, spelling_entry, 4, 0);
        spelling_entry = spelling_entry + 1;
    }
    ptr byte break_data = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte continue_data = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    // Start from the already indexed, immutable project context.  This keeps
    // the per-source initializer proportional to source-local state instead
    // of rebuilding the complete IrContext field by field.
    IrContext context = c_parallel_base(base);
    context.source = source;
    context.token_data = ir_pointer_alias(token_data);
    context.tokens = tokens;
    context.syntax_data = ir_pointer_alias(syntax_data);
    context.syntax = syntax;
    context.module_index = module_index;
    context.source_record = source_record;
    context.function_result = semantic_type_void();
    context.name_cache = null;
    context.spelling_cache = ir_pointer_alias(spelling_cache);
    context.spelling_cache_capacity = spelling_cache_capacity;
    context.call_cache = null;
    context.call_argument_first = ir_pointer_alias(call_argument_first);
    context.call_argument_last = ir_pointer_alias(call_argument_last);
    context.argument_next = ir_pointer_alias(argument_next);
    context.type_cache = null;
    context.profile_type_seen = ir_pointer_alias(profile_type_seen);
    context.resolved_type_ref_cache = ir_pointer_alias(
        resolved_type_ref_cache
    );
    context.left_expression_cache = null;
    context.right_expression_cache = null;
    context.typed_expression_cache = ir_pointer_alias(
        typed_expression_cache
    );
    context.block_parent_cache = ir_pointer_alias(block_parent_cache);
    context.control_parent_cache = ir_pointer_alias(control_parent_cache);
    context.statement_nodes = ir_pointer_alias(statement_nodes);
    context.block_statement_first = ir_pointer_alias(block_statement_first);
    context.statement_next = ir_pointer_alias(statement_next);
    context.control_block_first = ir_pointer_alias(control_block_first);
    context.block_next = ir_pointer_alias(block_next);
    context.control_child_first = ir_pointer_alias(control_child_first);
    context.control_child_next = ir_pointer_alias(control_child_next);
    context.initializer_field_first = ir_pointer_alias(
        initializer_field_first
    );
    context.initializer_field_next = ir_pointer_alias(initializer_field_next);
    context.initializer_field_owner = ir_pointer_alias(
        initializer_field_owner
    );
    context.array_element_first = ir_pointer_alias(array_element_first);
    context.array_element_next = ir_pointer_alias(array_element_next);
    context.block_nodes = ir_pointer_alias(block_nodes);
    context.control_nodes = ir_pointer_alias(control_nodes);
    context.expression_nodes = ir_pointer_alias(expression_nodes);
    context.call_nodes = ir_pointer_alias(call_nodes);
    context.expression_start_heads = ir_pointer_alias(expression_start_heads);
    context.expression_start_capacity = source_length + 1;
    context.expression_start_next = ir_pointer_alias(expression_start_next);
    context.expression_next_start = ir_pointer_alias(expression_next_start);
    context.function_at_position = ir_pointer_alias(function_at_position);
    context.name_nodes = ir_pointer_alias(name_nodes);
    context.type_ref_nodes = ir_pointer_alias(type_ref_nodes);
    context.declaration_symbol_cache = ir_pointer_alias(
        declaration_symbol_cache
    );
    context.top_symbols = ir_pointer_alias(top_symbols);
    context.local_values = ir_pointer_alias(local_values);
    context.block_data = ir_pointer_alias(block_data);
    context.blocks = blocks;
    context.instruction_data = ir_pointer_alias(instruction_data);
    context.instruction_detail = ir_pointer_alias(instruction_detail);
    context.instructions = instructions;
    context.operand_data = ir_pointer_alias(operand_data);
    context.operands = operands;
    context.break_data = ir_pointer_alias(break_data);
    context.continue_data = ir_pointer_alias(continue_data);
    ir_initialize_local_values(context);
    phase_started = process.monotonic_milliseconds();
    usize index_started = phase_started;
    ir_initialize_node_indexes(context);
    timings.index_nodes_ms = timings.index_nodes_ms +
        process.monotonic_milliseconds() - phase_started;
    phase_started = process.monotonic_milliseconds();
    ir_initialize_parent_position_caches(context);
    timings.index_parents_ms = timings.index_parents_ms +
        process.monotonic_milliseconds() - phase_started;
    ir_initialize_control_adjacency(context);
    phase_started = process.monotonic_milliseconds();
    ir_initialize_statement_adjacency(context);
    timings.index_statements_ms = timings.index_statements_ms +
        process.monotonic_milliseconds() - phase_started;
    ir_initialize_initializer_fields(context);
    ir_initialize_array_elements(context);
    ir_initialize_declaration_symbols(context);
    phase_started = process.monotonic_milliseconds();
    ir_initialize_function_positions(context);
    timings.index_function_positions_ms =
        timings.index_function_positions_ms +
        process.monotonic_milliseconds() - phase_started;
    timings.index_ms = timings.index_ms +
        process.monotonic_milliseconds() - index_started;
    if validate_acceptance {
        // Acceptance treats every declared local as semantically available;
        // lowering later replaces these sentinels with concrete SSA values.
        usize acceptance_symbol = 0;
        while acceptance_symbol < context.symbols.length {
            write_usize(
                context.local_values,
                acceptance_symbol * size_of(usize), 1
            );
            acceptance_symbol = acceptance_symbol + 1;
        }
        usize acceptance_started = process.monotonic_milliseconds();
        usize found = acceptance_validate_context(context, timings);
        timings.validation_type_queries = timings.validation_type_queries +
            context.profile_type_queries;
        timings.validation_type_cache_hits =
            timings.validation_type_cache_hits +
            context.profile_type_cache_hits;
        timings.validation_type_uncached =
            timings.validation_type_uncached +
            context.profile_type_uncached;
        timings.validation_type_distinct_uncached =
            timings.validation_type_distinct_uncached +
            context.profile_type_distinct_uncached;
        timings.validation_type_repeated_uncached =
            timings.validation_type_repeated_uncached +
            context.profile_type_repeated_uncached;
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
        usize acceptance_elapsed =
            process.monotonic_milliseconds() - acceptance_started;
        timings.validation_acceptance_ms =
            timings.validation_acceptance_ms + acceptance_elapsed;
        if validation_source_ms != null {
            write_usize(
                validation_source_ms,
                source_record * size_of(usize),
                read_usize(
                    validation_source_ms,
                    source_record * size_of(usize)
                ) + acceptance_elapsed
            );
        }
        timings.validation_acceptance_errors =
            timings.validation_acceptance_errors + found;
        base.types = context.types;
        ir_initialize_local_values(context);
        if found != 0 {
            if parsed_source_reused {
                context.syntax_data = null;
                context.token_data = null;
            }
            c_release_source_context(context, diagnostic_data);
            return true;
        }
    }
    usize node = 0;
    while node < syntax.length {
        if read_record_field(syntax_data, node, 0) == 2 {
            usize body = ir_largest_direct_block(context, node);
            usize owner = ir_owner_symbol(
                context, node,
                resolution_symbol_function(), 0
            );
            // A semicolon-only declaration has no IR body. It is valid input,
            // but its implementation must be supplied by another source or an
            // external/native provider. Do not accidentally associate it with
            // a later declaration's block and report an internal compiler bug.
            if body >= syntax.length || byte_at_or_zero(
                    source,
                    read_record_field(syntax_data, body, 1)
                ) != 123 {
                node = node + 1;
                continue;
            }
            if owner == 0 {
                io.print("OPENC-C-BACKEND-INTERNAL source=");
                io.print(source_record);
                io.print(" node="); io.print(node);
                io.print(" body="); io.print(body);
                io.print(" owner="); io.println(owner);
                if parsed_source_reused {
                    context.syntax_data = null;
                    context.token_data = null;
                }
                c_release_source_context(context, diagnostic_data);
                return false;
            }
            c_lower_and_emit_function(
                context, output, timings, source_record, node,
                owner, entry_module
            );
        }
        node = node + 1;
    }
    base.next_value = context.next_value;
    base.types = context.types;
    if parsed_source_reused {
        context.syntax_data = null;
        context.token_data = null;
    }
    c_release_source_context(context, diagnostic_data);
    return true;
}
