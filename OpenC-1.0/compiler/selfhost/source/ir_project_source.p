import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool ir_observe_emit_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    PackedBuffer symbols,
    usize module_index,
    usize source_record,
    ref IrObserveState state
) {
    text source;
    status emission_source_status = project_read_source_record(
        project_source, project_root, source_data,
        source_record, out source
    );
    if !emission_source_status.ok { return false; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
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
    ptr byte type_cache = memory.alloc(
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
    ptr byte block_nodes = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte control_nodes = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte expression_nodes = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte name_nodes = memory.alloc(
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
        write_usize(name_cache, cache_node * size_of(usize), 0);
        write_usize(call_cache, cache_node * size_of(usize), 0);
        write_usize(type_cache, cache_node * size_of(usize), 0);
        write_usize(
            left_expression_cache, cache_node * size_of(usize),
            syntax.length + 1
        );
        write_usize(
            right_expression_cache, cache_node * size_of(usize),
            syntax.length + 1
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
        types = state.types,
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
        type_cache = ir_pointer_alias(type_cache),
        resolved_type_ref_cache = null,
        left_expression_cache = ir_pointer_alias(left_expression_cache),
        right_expression_cache = ir_pointer_alias(right_expression_cache),
        block_parent_cache = ir_pointer_alias(block_parent_cache),
        control_parent_cache = ir_pointer_alias(control_parent_cache),
        statement_nodes = ir_pointer_alias(statement_nodes),
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
        block_nodes = ir_pointer_alias(block_nodes),
        block_count = 0,
        control_nodes = ir_pointer_alias(control_nodes),
        control_count = 0,
        expression_nodes = ir_pointer_alias(expression_nodes),
        expression_count = 0,
        call_nodes = null,
        call_count = 0,
        expression_start_heads = null,
        expression_start_capacity = 0,
        expression_start_next = null,
        expression_next_start = null,
        function_at_position = null,
        name_nodes = ir_pointer_alias(name_nodes),
        name_count = 0,
        type_ref_nodes = null,
        type_ref_count = 0,
        declaration_symbol_cache = ir_pointer_alias(
            declaration_symbol_cache
        ),
        top_symbols = ir_pointer_alias(top_symbols),
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
        next_value = state.next_value,
        profile_statement_candidates = 0,
        profile_parent_candidates = 0,
        profile_expression_positions = 0,
        profile_syntax_candidates = 0,
        profile_symbol_candidates = 0,
        profile_type_queries_enabled = false,
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
    ir_initialize_local_values(context);
    ir_initialize_node_indexes(context);
    ir_initialize_declaration_symbols(context);
    usize node = 0;
    while node < syntax.length {
        if read_record_field(syntax_data, node, 0) == 2 {
            usize body = ir_largest_direct_block(context, node);
            usize owner = ir_owner_symbol(
                context, node, resolution_symbol_function(), 0
            );
            if body < syntax.length && owner != 0 && byte_at_or_zero(
                    source,
                    read_record_field(syntax_data, body, 1)
                ) == 123 {
                if state.emitted_functions != 0 { io.print(","); }
                ir_emit_function_json(context, node, owner - 1);
                state.emitted_functions = state.emitted_functions + 1;
            }
        }
        node = node + 1;
    }
    state.next_value = context.next_value;
    state.types = context.types;
    memory.free(continue_data);
    memory.free(break_data);
    memory.free(top_symbols);
    memory.free(declaration_symbol_cache);
    memory.free(name_nodes);
    memory.free(expression_nodes);
    memory.free(control_nodes);
    memory.free(block_nodes);
    memory.free(statement_nodes);
    memory.free(control_parent_cache);
    memory.free(block_parent_cache);
    memory.free(right_expression_cache);
    memory.free(left_expression_cache);
    memory.free(type_cache);
    memory.free(call_cache);
    memory.free(name_cache);
    memory.free(local_values);
    memory.free(context.operand_data);
    memory.free(context.instruction_detail);
    memory.free(context.instruction_data);
    memory.free(context.block_data);
    memory.free(syntax_data);
    memory.free(diagnostic_data);
    memory.free(token_data);
    return true;
}
