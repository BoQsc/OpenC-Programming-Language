// A source-indexed cache may be shared by function jobs only when each writer
// is confined to its immutable, nonoverlapping declaration span. The opt-in
// path checks this before the write; a miss never mutates shared storage and
// is rejected after the function returns. The default path has no owner.
unsafe bool ir_function_cache_read_allowed(
    ref IrContext context, usize node
) {
    if context.cache_write_owner_encoded == 0 { return true; }
    usize owner = context.cache_write_owner_encoded - 1;
    if node >= context.syntax.length || owner >= context.syntax.length {
        return false;
    }
    if node == owner { return true; }
    usize owner_start = read_record_field(context.syntax_data, owner, 1);
    usize owner_length = read_record_field(context.syntax_data, owner, 2);
    usize node_start = read_record_field(context.syntax_data, node, 1);
    usize node_length = read_record_field(context.syntax_data, node, 2);
    // Half-open ownership excludes a zero-length node at the boundary shared
    // by adjacent declarations, even though semantic_node_contains accepts it.
    return owner_length != 0 && node_length != 0 &&
        owner_start <= node_start &&
        node_start - owner_start < owner_length &&
        node_length <= owner_length - (node_start - owner_start);
}

unsafe bool ir_function_cache_write_allowed(
    ref IrContext context, usize node
) {
    if ir_function_cache_read_allowed(context, node) {
        return true;
    }
    context.cache_write_violations = context.cache_write_violations + 1;
    return false;
}

// Every function cache lane is keyed by syntax node. Reject overlapping or
// unsorted declarations before a source-indexed lane is lent to functions.
unsafe bool ir_function_cache_spans_disjoint(ref IrContext context) {
    usize previous_end = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 2 {
            usize start = read_record_field(context.syntax_data, node, 1);
            usize length = read_record_field(context.syntax_data, node, 2);
            if length == 0 || start < previous_end ||
                start > context.source.length ||
                length > context.source.length - start { return false; }
            previous_end = start + length;
        }
        node = node + 1;
    }
    return true;
}

// Complete the lazily built call-argument links before publishing the indexed
// source. Parent caches are already filled for every syntax node by indexing.
unsafe bool ir_prepare_function_index_caches(ref IrContext context) {
    if context.block_parent_cache == null ||
        context.control_parent_cache == null ||
        context.call_argument_first == null ||
        context.call_argument_last == null ||
        context.argument_next == null ||
        (context.call_count != 0 && context.call_nodes == null) {
        return false;
    }
    usize node = 0;
    while node < context.syntax.length {
        if read_usize(
            context.block_parent_cache, node * size_of(usize)
        ) > context.syntax.length || read_usize(
            context.control_parent_cache, node * size_of(usize)
        ) > context.syntax.length { return false; }
        node = node + 1;
    }
    usize call_index = 0;
    while call_index < context.call_count {
        usize call = read_usize(
            context.call_nodes, call_index * size_of(usize)
        );
        if call >= context.syntax.length { return false; }
        ir_index_call_arguments(context, call);
        usize argument_count = read_record_field(context.syntax_data, call, 4);
        if argument_count != 0 {
            usize last = read_usize(
                context.call_argument_last, call * size_of(usize)
            );
            usize encoded = read_usize(
                context.call_argument_first, call * size_of(usize)
            );
            usize argument = 0;
            while argument < argument_count {
                if encoded == 0 || encoded > context.syntax.length {
                    return false;
                }
                if argument + 1 == argument_count && encoded != last {
                    return false;
                }
                encoded = read_usize(
                    context.argument_next, (encoded - 1) * size_of(usize)
                );
                argument = argument + 1;
            }
            if encoded != 0 { return false; }
        }
        call_index = call_index + 1;
    }
    return true;
}

unsafe usize ir_function_index_cache_fingerprint(ref IrContext context) {
    // Diagnostic checksum only; the readiness and writer-path audit are the
    // actual no-write argument. Values are syntax-node IDs, so this bounded
    // sum does not approach usize overflow under the compiler's RAM cap.
    usize hash = 0;
    usize node = 0;
    while node <= context.syntax.length {
        usize offset = node * size_of(usize);
        hash = hash + read_usize(context.block_parent_cache, offset);
        hash = hash + 3 * read_usize(context.control_parent_cache, offset);
        hash = hash + 5 * read_usize(context.call_argument_first, offset);
        hash = hash + 7 * read_usize(context.call_argument_last, offset);
        hash = hash + 11 * read_usize(context.argument_next, offset);
        node = node + 1;
    }
    return hash;
}

// Only call after ir_initialize_* and acceptance_validate_context return.
// The source, syntax, adjacency, and declaration indices remain owned by the
// enclosing source record and are borrowed until its final function returns.
unsafe void ir_prepared_source(
    ref IrContext source,
    ref IrPreparedSource prepared
) {
    IrContext view = source;
    view.function_node = 0;
    view.function_symbol = 0;
    view.function_result = 0;
    view.function_local_first = 0;
    view.function_local_end = 0;
    view.cache_write_owner_encoded = 0;
    view.cache_write_violations = 0;
    view.type_data = null;
    view.types = PackedBuffer{ length = 0, capacity = 0 };
    view.symbol_export_cache = null;
    view.native_layout_size_cache = null;
    view.native_layout_alignment_cache = null;
    view.native_layout_state_cache = null;
    view.native_layout_cache_entries = 0;
    view.local_values = null;
    view.block_data = null;
    view.blocks = PackedBuffer{ length = 0, capacity = 0 };
    view.instruction_data = null;
    view.instruction_detail = null;
    view.instructions = PackedBuffer{ length = 0, capacity = 0 };
    view.operand_data = null;
    view.operands = PackedBuffer{ length = 0, capacity = 0 };
    view.break_data = null;
    view.break_depth = 0;
    view.continue_data = null;
    view.continue_depth = 0;
    view.current_block = 0;
    view.next_value = 0;
    view.profile_statement_candidates = 0;
    view.profile_parent_candidates = 0;
    view.profile_expression_positions = 0;
    view.profile_syntax_candidates = 0;
    view.profile_symbol_candidates = 0;
    view.profile_type_queries = 0;
    view.profile_type_cache_hits = 0;
    view.profile_type_uncached = 0;
    view.profile_type_distinct_uncached = 0;
    view.profile_type_repeated_uncached = 0;
    view.profile_type_failures = 0;
    view.profile_type_name_uncached = 0;
    view.profile_type_literal_uncached = 0;
    view.profile_type_unary_uncached = 0;
    view.profile_type_binary_uncached = 0;
    view.profile_type_assignment_uncached = 0;
    view.profile_type_call_uncached = 0;
    view.profile_type_other_uncached = 0;
    prepared.view = view;
    prepared.view.project_source = source.project_source;
    prepared.view.project_root = source.project_root;
    prepared.view.source = source.source;
    prepared.view.module_data = source.module_data;
    prepared.view.modules = source.modules;
    prepared.view.source_data = source.source_data;
    prepared.view.type_data = view.type_data;
    prepared.view.types = view.types;
    prepared.view.symbol_data = source.symbol_data;
    prepared.view.detail_data = source.detail_data;
    prepared.view.symbols = source.symbols;
    prepared.view.token_data = source.token_data;
    prepared.view.tokens = source.tokens;
    prepared.view.syntax_data = source.syntax_data;
    prepared.view.syntax = source.syntax;
    prepared.view.module_index = source.module_index;
    prepared.view.source_record = source.source_record;
    prepared.view.function_node = view.function_node;
    prepared.view.function_symbol = view.function_symbol;
    prepared.view.function_result = view.function_result;
    prepared.view.function_local_first = view.function_local_first;
    prepared.view.function_local_end = view.function_local_end;
    prepared.view.cache_write_owner_encoded = view.cache_write_owner_encoded;
    prepared.view.cache_write_violations = view.cache_write_violations;
    prepared.view.name_cache = source.name_cache;
    prepared.view.spelling_cache = source.spelling_cache;
    prepared.view.spelling_cache_capacity = source.spelling_cache_capacity;
    prepared.view.call_cache = source.call_cache;
    prepared.view.call_argument_first = source.call_argument_first;
    prepared.view.call_argument_last = source.call_argument_last;
    prepared.view.argument_next = source.argument_next;
    prepared.view.type_cache = source.type_cache;
    prepared.view.resolved_type_ref_cache = source.resolved_type_ref_cache;
    prepared.view.left_expression_cache = source.left_expression_cache;
    prepared.view.right_expression_cache = source.right_expression_cache;
    prepared.view.block_parent_cache = source.block_parent_cache;
    prepared.view.control_parent_cache = source.control_parent_cache;
    prepared.view.statement_nodes = source.statement_nodes;
    prepared.view.statement_count = source.statement_count;
    prepared.view.block_statement_first = source.block_statement_first;
    prepared.view.statement_next = source.statement_next;
    prepared.view.control_block_first = source.control_block_first;
    prepared.view.block_next = source.block_next;
    prepared.view.control_child_first = source.control_child_first;
    prepared.view.control_child_next = source.control_child_next;
    prepared.view.initializer_field_first = source.initializer_field_first;
    prepared.view.initializer_field_next = source.initializer_field_next;
    prepared.view.initializer_field_owner = source.initializer_field_owner;
    prepared.view.array_element_first = source.array_element_first;
    prepared.view.array_element_next = source.array_element_next;
    prepared.view.block_nodes = source.block_nodes;
    prepared.view.block_count = source.block_count;
    prepared.view.control_nodes = source.control_nodes;
    prepared.view.control_count = source.control_count;
    prepared.view.expression_nodes = source.expression_nodes;
    prepared.view.expression_count = source.expression_count;
    prepared.view.call_nodes = source.call_nodes;
    prepared.view.call_count = source.call_count;
    prepared.view.expression_start_heads = source.expression_start_heads;
    prepared.view.expression_start_capacity = source.expression_start_capacity;
    prepared.view.expression_start_next = source.expression_start_next;
    prepared.view.expression_next_start = source.expression_next_start;
    prepared.view.function_at_position = source.function_at_position;
    prepared.view.name_nodes = source.name_nodes;
    prepared.view.name_count = source.name_count;
    prepared.view.type_ref_nodes = source.type_ref_nodes;
    prepared.view.type_ref_count = source.type_ref_count;
    prepared.view.declaration_symbol_cache = source.declaration_symbol_cache;
    prepared.view.top_symbols = source.top_symbols;
    prepared.view.top_symbol_count = source.top_symbol_count;
    prepared.view.function_bucket_heads = source.function_bucket_heads;
    prepared.view.function_bucket_capacity = source.function_bucket_capacity;
    prepared.view.function_bucket_next = source.function_bucket_next;
    prepared.view.function_parameter_first = source.function_parameter_first;
    prepared.view.function_parameter_count = source.function_parameter_count;
    prepared.view.parameter_next = source.parameter_next;
    prepared.view.function_local_range_first = source.function_local_range_first;
    prepared.view.function_local_range_end = source.function_local_range_end;
    prepared.view.type_aggregate_symbols = source.type_aggregate_symbols;
    prepared.view.aggregate_field_first = source.aggregate_field_first;
    prepared.view.field_next = source.field_next;
    prepared.view.enum_item_value = source.enum_item_value;
    prepared.view.symbol_export_cache = view.symbol_export_cache;
    prepared.view.native_layout_size_cache = view.native_layout_size_cache;
    prepared.view.native_layout_alignment_cache = view.native_layout_alignment_cache;
    prepared.view.native_layout_state_cache = view.native_layout_state_cache;
    prepared.view.native_layout_cache_entries = view.native_layout_cache_entries;
    prepared.view.local_values = view.local_values;
    prepared.view.block_data = view.block_data;
    prepared.view.blocks = view.blocks;
    prepared.view.instruction_data = view.instruction_data;
    prepared.view.instruction_detail = view.instruction_detail;
    prepared.view.instructions = view.instructions;
    prepared.view.operand_data = view.operand_data;
    prepared.view.operands = view.operands;
    prepared.view.break_data = view.break_data;
    prepared.view.break_depth = view.break_depth;
    prepared.view.continue_data = view.continue_data;
    prepared.view.continue_depth = view.continue_depth;
    prepared.view.current_block = view.current_block;
    prepared.view.next_value = view.next_value;
    prepared.view.profile_statement_candidates = view.profile_statement_candidates;
    prepared.view.profile_parent_candidates = view.profile_parent_candidates;
    prepared.view.profile_expression_positions = view.profile_expression_positions;
    prepared.view.profile_syntax_candidates = view.profile_syntax_candidates;
    prepared.view.profile_symbol_candidates = view.profile_symbol_candidates;
    prepared.view.profile_type_queries_enabled = source.profile_type_queries_enabled;
    prepared.view.profile_type_seen = source.profile_type_seen;
    prepared.view.profile_type_queries = view.profile_type_queries;
    prepared.view.profile_type_cache_hits = view.profile_type_cache_hits;
    prepared.view.profile_type_uncached = view.profile_type_uncached;
    prepared.view.profile_type_distinct_uncached = view.profile_type_distinct_uncached;
    prepared.view.profile_type_repeated_uncached = view.profile_type_repeated_uncached;
    prepared.view.profile_type_failures = view.profile_type_failures;
    prepared.view.profile_type_name_uncached = view.profile_type_name_uncached;
    prepared.view.profile_type_literal_uncached = view.profile_type_literal_uncached;
    prepared.view.profile_type_unary_uncached = view.profile_type_unary_uncached;
    prepared.view.profile_type_binary_uncached = view.profile_type_binary_uncached;
    prepared.view.profile_type_assignment_uncached = view.profile_type_assignment_uncached;
    prepared.view.profile_type_call_uncached = view.profile_type_call_uncached;
    prepared.view.profile_type_other_uncached = view.profile_type_other_uncached;
    prepared.view.suppress_acceptance_diagnostics = source.suppress_acceptance_diagnostics;
}

unsafe IrFunctionScratch ir_function_scratch(ref IrContext source) {
    return IrFunctionScratch{
        function_node = source.function_node,
        function_symbol = source.function_symbol,
        function_result = source.function_result,
        function_local_first = source.function_local_first,
        function_local_end = source.function_local_end,
        cache_write_owner_encoded = source.cache_write_owner_encoded,
        cache_write_violations = source.cache_write_violations,
        type_data = source.type_data,
        types = source.types,
        symbol_export_cache = source.symbol_export_cache,
        native_layout_size_cache = source.native_layout_size_cache,
        native_layout_alignment_cache = source.native_layout_alignment_cache,
        native_layout_state_cache = source.native_layout_state_cache,
        native_layout_cache_entries = source.native_layout_cache_entries,
        local_values = source.local_values,
        block_data = source.block_data,
        blocks = source.blocks,
        instruction_data = source.instruction_data,
        instruction_detail = source.instruction_detail,
        instructions = source.instructions,
        operand_data = source.operand_data,
        operands = source.operands,
        break_data = source.break_data,
        break_depth = source.break_depth,
        continue_data = source.continue_data,
        continue_depth = source.continue_depth,
        current_block = source.current_block,
        next_value = source.next_value,
        profile_statement_candidates = source.profile_statement_candidates,
        profile_parent_candidates = source.profile_parent_candidates,
        profile_expression_positions = source.profile_expression_positions,
        profile_syntax_candidates = source.profile_syntax_candidates,
        profile_symbol_candidates = source.profile_symbol_candidates,
        profile_type_queries = source.profile_type_queries,
        profile_type_cache_hits = source.profile_type_cache_hits,
        profile_type_uncached = source.profile_type_uncached,
        profile_type_distinct_uncached = source.profile_type_distinct_uncached,
        profile_type_repeated_uncached = source.profile_type_repeated_uncached,
        profile_type_failures = source.profile_type_failures,
        profile_type_name_uncached = source.profile_type_name_uncached,
        profile_type_literal_uncached = source.profile_type_literal_uncached,
        profile_type_unary_uncached = source.profile_type_unary_uncached,
        profile_type_binary_uncached = source.profile_type_binary_uncached,
        profile_type_assignment_uncached = source.profile_type_assignment_uncached,
        profile_type_call_uncached = source.profile_type_call_uncached,
        profile_type_other_uncached = source.profile_type_other_uncached
    };
}

unsafe void ir_bind_prepared_function(
    ref IrPreparedSource prepared,
    ref IrFunctionScratch scratch,
    ref IrContext context
) {
    // Fieldwise handoff avoids unsupported bulk copying of the large view.
    context.project_source = prepared.view.project_source;
    context.project_root = prepared.view.project_root;
    context.source = prepared.view.source;
    context.module_data = prepared.view.module_data;
    context.modules = prepared.view.modules;
    context.source_data = prepared.view.source_data;
    context.symbol_data = prepared.view.symbol_data;
    context.detail_data = prepared.view.detail_data;
    context.symbols = prepared.view.symbols;
    context.token_data = prepared.view.token_data;
    context.tokens = prepared.view.tokens;
    context.syntax_data = prepared.view.syntax_data;
    context.syntax = prepared.view.syntax;
    context.module_index = prepared.view.module_index;
    context.source_record = prepared.view.source_record;
    context.statement_nodes = prepared.view.statement_nodes;
    context.statement_count = prepared.view.statement_count;
    context.block_statement_first = prepared.view.block_statement_first;
    context.statement_next = prepared.view.statement_next;
    context.control_block_first = prepared.view.control_block_first;
    context.block_next = prepared.view.block_next;
    context.control_child_first = prepared.view.control_child_first;
    context.control_child_next = prepared.view.control_child_next;
    context.initializer_field_first = prepared.view.initializer_field_first;
    context.initializer_field_next = prepared.view.initializer_field_next;
    context.initializer_field_owner = prepared.view.initializer_field_owner;
    context.array_element_first = prepared.view.array_element_first;
    context.array_element_next = prepared.view.array_element_next;
    context.block_nodes = prepared.view.block_nodes;
    context.block_count = prepared.view.block_count;
    context.control_nodes = prepared.view.control_nodes;
    context.control_count = prepared.view.control_count;
    context.expression_nodes = prepared.view.expression_nodes;
    context.expression_count = prepared.view.expression_count;
    context.call_nodes = prepared.view.call_nodes;
    context.call_count = prepared.view.call_count;
    context.expression_start_heads = prepared.view.expression_start_heads;
    context.expression_start_capacity = prepared.view.expression_start_capacity;
    context.expression_start_next = prepared.view.expression_start_next;
    context.expression_next_start = prepared.view.expression_next_start;
    context.function_at_position = prepared.view.function_at_position;
    context.name_nodes = prepared.view.name_nodes;
    context.name_count = prepared.view.name_count;
    context.type_ref_nodes = prepared.view.type_ref_nodes;
    context.type_ref_count = prepared.view.type_ref_count;
    context.declaration_symbol_cache = prepared.view.declaration_symbol_cache;
    context.top_symbols = prepared.view.top_symbols;
    context.top_symbol_count = prepared.view.top_symbol_count;
    context.function_bucket_heads = prepared.view.function_bucket_heads;
    context.function_bucket_capacity = prepared.view.function_bucket_capacity;
    context.function_bucket_next = prepared.view.function_bucket_next;
    context.function_parameter_first = prepared.view.function_parameter_first;
    context.function_parameter_count = prepared.view.function_parameter_count;
    context.parameter_next = prepared.view.parameter_next;
    context.function_local_range_first = prepared.view.function_local_range_first;
    context.function_local_range_end = prepared.view.function_local_range_end;
    context.type_aggregate_symbols = prepared.view.type_aggregate_symbols;
    context.aggregate_field_first = prepared.view.aggregate_field_first;
    context.field_next = prepared.view.field_next;
    context.enum_item_value = prepared.view.enum_item_value;
    context.profile_type_queries_enabled = prepared.view.profile_type_queries_enabled;
    context.suppress_acceptance_diagnostics = prepared.view.suppress_acceptance_diagnostics;
    context.function_node = scratch.function_node;
    context.function_symbol = scratch.function_symbol;
    context.function_result = scratch.function_result;
    context.function_local_first = scratch.function_local_first;
    context.function_local_end = scratch.function_local_end;
    context.cache_write_owner_encoded = scratch.cache_write_owner_encoded;
    context.cache_write_violations = scratch.cache_write_violations;
    context.type_data = scratch.type_data;
    context.types = scratch.types;
    context.name_cache = prepared.view.name_cache;
    context.spelling_cache = prepared.view.spelling_cache;
    context.spelling_cache_capacity = prepared.view.spelling_cache_capacity;
    context.call_cache = prepared.view.call_cache;
    context.call_argument_first = prepared.view.call_argument_first;
    context.call_argument_last = prepared.view.call_argument_last;
    context.argument_next = prepared.view.argument_next;
    context.type_cache = prepared.view.type_cache;
    context.profile_type_seen = prepared.view.profile_type_seen;
    context.resolved_type_ref_cache = prepared.view.resolved_type_ref_cache;
    context.left_expression_cache = prepared.view.left_expression_cache;
    context.right_expression_cache = prepared.view.right_expression_cache;
    context.block_parent_cache = prepared.view.block_parent_cache;
    context.control_parent_cache = prepared.view.control_parent_cache;
    context.symbol_export_cache = scratch.symbol_export_cache;
    context.native_layout_size_cache = scratch.native_layout_size_cache;
    context.native_layout_alignment_cache = scratch.native_layout_alignment_cache;
    context.native_layout_state_cache = scratch.native_layout_state_cache;
    context.native_layout_cache_entries = scratch.native_layout_cache_entries;
    context.local_values = scratch.local_values;
    context.block_data = scratch.block_data;
    context.blocks = scratch.blocks;
    context.instruction_data = scratch.instruction_data;
    context.instruction_detail = scratch.instruction_detail;
    context.instructions = scratch.instructions;
    context.operand_data = scratch.operand_data;
    context.operands = scratch.operands;
    context.break_data = scratch.break_data;
    context.break_depth = scratch.break_depth;
    context.continue_data = scratch.continue_data;
    context.continue_depth = scratch.continue_depth;
    context.current_block = scratch.current_block;
    context.next_value = scratch.next_value;
    context.profile_statement_candidates = scratch.profile_statement_candidates;
    context.profile_parent_candidates = scratch.profile_parent_candidates;
    context.profile_expression_positions = scratch.profile_expression_positions;
    context.profile_syntax_candidates = scratch.profile_syntax_candidates;
    context.profile_symbol_candidates = scratch.profile_symbol_candidates;
    context.profile_type_queries = scratch.profile_type_queries;
    context.profile_type_cache_hits = scratch.profile_type_cache_hits;
    context.profile_type_uncached = scratch.profile_type_uncached;
    context.profile_type_distinct_uncached = scratch.profile_type_distinct_uncached;
    context.profile_type_repeated_uncached = scratch.profile_type_repeated_uncached;
    context.profile_type_failures = scratch.profile_type_failures;
    context.profile_type_name_uncached = scratch.profile_type_name_uncached;
    context.profile_type_literal_uncached = scratch.profile_type_literal_uncached;
    context.profile_type_unary_uncached = scratch.profile_type_unary_uncached;
    context.profile_type_binary_uncached = scratch.profile_type_binary_uncached;
    context.profile_type_assignment_uncached = scratch.profile_type_assignment_uncached;
    context.profile_type_call_uncached = scratch.profile_type_call_uncached;
    context.profile_type_other_uncached = scratch.profile_type_other_uncached;
}

unsafe void ir_capture_function_scratch(
    ref IrFunctionScratch scratch,
    ref IrContext context
) {
    // Buffers are reused; their capacities remain source-owned until the
    // enclosing source record releases them. Capture any pointer replacement
    // as well as evolving lengths before the next function binds this worker.
    scratch.function_node = context.function_node;
    scratch.function_symbol = context.function_symbol;
    scratch.function_result = context.function_result;
    scratch.function_local_first = context.function_local_first;
    scratch.function_local_end = context.function_local_end;
    scratch.cache_write_owner_encoded = context.cache_write_owner_encoded;
    scratch.cache_write_violations = context.cache_write_violations;
    scratch.type_data = context.type_data;
    scratch.types = context.types;
    scratch.symbol_export_cache = context.symbol_export_cache;
    scratch.native_layout_size_cache = context.native_layout_size_cache;
    scratch.native_layout_alignment_cache = context.native_layout_alignment_cache;
    scratch.native_layout_state_cache = context.native_layout_state_cache;
    scratch.native_layout_cache_entries = context.native_layout_cache_entries;
    scratch.local_values = context.local_values;
    scratch.block_data = context.block_data;
    scratch.blocks = context.blocks;
    scratch.instruction_data = context.instruction_data;
    scratch.instruction_detail = context.instruction_detail;
    scratch.instructions = context.instructions;
    scratch.operand_data = context.operand_data;
    scratch.operands = context.operands;
    scratch.break_data = context.break_data;
    scratch.break_depth = context.break_depth;
    scratch.continue_data = context.continue_data;
    scratch.continue_depth = context.continue_depth;
    scratch.current_block = context.current_block;
    scratch.next_value = context.next_value;
    scratch.profile_statement_candidates = context.profile_statement_candidates;
    scratch.profile_parent_candidates = context.profile_parent_candidates;
    scratch.profile_expression_positions = context.profile_expression_positions;
    scratch.profile_syntax_candidates = context.profile_syntax_candidates;
    scratch.profile_symbol_candidates = context.profile_symbol_candidates;
    scratch.profile_type_queries = context.profile_type_queries;
    scratch.profile_type_cache_hits = context.profile_type_cache_hits;
    scratch.profile_type_uncached = context.profile_type_uncached;
    scratch.profile_type_distinct_uncached = context.profile_type_distinct_uncached;
    scratch.profile_type_repeated_uncached = context.profile_type_repeated_uncached;
    scratch.profile_type_failures = context.profile_type_failures;
    scratch.profile_type_name_uncached = context.profile_type_name_uncached;
    scratch.profile_type_literal_uncached = context.profile_type_literal_uncached;
    scratch.profile_type_unary_uncached = context.profile_type_unary_uncached;
    scratch.profile_type_binary_uncached = context.profile_type_binary_uncached;
    scratch.profile_type_assignment_uncached = context.profile_type_assignment_uncached;
    scratch.profile_type_call_uncached = context.profile_type_call_uncached;
    scratch.profile_type_other_uncached = context.profile_type_other_uncached;
}
