import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void c_release_source_context(
    ref IrContext context,
    ptr byte diagnostic_data
) {
    memory.free(context.continue_data);
    memory.free(context.break_data);
    memory.free(context.top_symbols);
    memory.free(context.declaration_symbol_cache);
    memory.free(context.type_ref_nodes);
    memory.free(context.name_nodes);
    memory.free(context.expression_next_start);
    memory.free(context.expression_start_next);
    memory.free(context.expression_start_heads);
    memory.free(context.expression_nodes);
    memory.free(context.control_nodes);
    memory.free(context.block_nodes);
    memory.free(context.control_child_next);
    memory.free(context.control_child_first);
    memory.free(context.block_next);
    memory.free(context.control_block_first);
    memory.free(context.statement_next);
    memory.free(context.block_statement_first);
    memory.free(context.array_element_next);
    memory.free(context.array_element_first);
    memory.free(context.initializer_field_owner);
    memory.free(context.initializer_field_next);
    memory.free(context.initializer_field_first);
    memory.free(context.statement_nodes);
    memory.free(context.control_parent_cache);
    memory.free(context.block_parent_cache);
    memory.free(context.right_expression_cache);
    memory.free(context.left_expression_cache);
    memory.free(context.resolved_type_ref_cache);
    memory.free(context.type_cache);
    memory.free(context.argument_next);
    memory.free(context.call_argument_last);
    memory.free(context.call_argument_first);
    memory.free(context.call_cache);
    memory.free(context.spelling_cache);
    memory.free(context.name_cache);
    memory.free(context.local_values);
    memory.free(context.operand_data);
    memory.free(context.instruction_detail);
    memory.free(context.instruction_data);
    memory.free(context.block_data);
    memory.free(context.syntax_data);
    memory.free(diagnostic_data);
    memory.free(context.token_data);
}

unsafe void c_record_lowered_function(
    ref BuildTimings timings,
    ref IrContext context,
    usize source_record,
    usize node,
    usize symbol,
    usize function_ir_ms
) {
    timings.ir_lower_ms = timings.ir_lower_ms + function_ir_ms;
    timings.total_statement_candidates =
        timings.total_statement_candidates +
        context.profile_statement_candidates;
    timings.total_parent_candidates =
        timings.total_parent_candidates +
        context.profile_parent_candidates;
    timings.total_expression_positions =
        timings.total_expression_positions +
        context.profile_expression_positions;
    timings.total_syntax_candidates =
        timings.total_syntax_candidates +
        context.profile_syntax_candidates;
    timings.total_symbol_candidates =
        timings.total_symbol_candidates +
        context.profile_symbol_candidates;
    usize function_name_start = read_record_field(
        context.symbol_data, symbol, 2
    );
    usize function_name_length = read_record_field(
        context.symbol_data, symbol, 3
    );
    if function_ir_ms > timings.slow_function_ms {
        timings.third_function_ms = timings.second_function_ms;
        timings.third_function_source = timings.second_function_source;
        timings.third_function_node = timings.second_function_node;
        timings.third_function_symbol = timings.second_function_symbol;
        timings.third_function_name_start =
            timings.second_function_name_start;
        timings.third_function_name_length =
            timings.second_function_name_length;
        timings.second_function_ms = timings.slow_function_ms;
        timings.second_function_source = timings.slow_function_source;
        timings.second_function_node = timings.slow_function_node;
        timings.second_function_symbol = timings.slow_function_symbol;
        timings.second_function_name_start =
            timings.slow_function_name_start;
        timings.second_function_name_length =
            timings.slow_function_name_length;
        timings.slow_function_ms = function_ir_ms;
        timings.slow_function_source = source_record;
        timings.slow_function_node = node;
        timings.slow_function_symbol = symbol;
        timings.slow_function_name_start = function_name_start;
        timings.slow_function_name_length = function_name_length;
        timings.slow_statement_candidates =
            context.profile_statement_candidates;
        timings.slow_parent_candidates =
            context.profile_parent_candidates;
        timings.slow_expression_positions =
            context.profile_expression_positions;
        timings.slow_syntax_candidates =
            context.profile_syntax_candidates;
        timings.slow_symbol_candidates =
            context.profile_symbol_candidates;
    } else if function_ir_ms > timings.second_function_ms {
        timings.third_function_ms = timings.second_function_ms;
        timings.third_function_source = timings.second_function_source;
        timings.third_function_node = timings.second_function_node;
        timings.third_function_symbol = timings.second_function_symbol;
        timings.third_function_name_start =
            timings.second_function_name_start;
        timings.third_function_name_length =
            timings.second_function_name_length;
        timings.second_function_ms = function_ir_ms;
        timings.second_function_source = source_record;
        timings.second_function_node = node;
        timings.second_function_symbol = symbol;
        timings.second_function_name_start = function_name_start;
        timings.second_function_name_length = function_name_length;
    } else if function_ir_ms > timings.third_function_ms {
        timings.third_function_ms = function_ir_ms;
        timings.third_function_source = source_record;
        timings.third_function_node = node;
        timings.third_function_symbol = symbol;
        timings.third_function_name_start = function_name_start;
        timings.third_function_name_length = function_name_length;
    }
    timings.functions = timings.functions + 1;
    timings.instructions = timings.instructions +
        context.instructions.length;
}

unsafe void c_lower_and_emit_function(
    ref IrContext context,
    ref DBuffer output,
    ref BuildTimings timings,
    usize source_record,
    usize node,
    usize owner,
    usize entry_module
) {
    context.profile_statement_candidates = 0;
    context.profile_parent_candidates = 0;
    context.profile_expression_positions = 0;
    context.profile_syntax_candidates = 0;
    context.profile_symbol_candidates = 0;
    usize phase_started = process.monotonic_milliseconds();
    ir_lower_function(context, node, owner - 1);
    usize function_ir_ms =
        process.monotonic_milliseconds() - phase_started;
    c_record_lowered_function(
        timings, context, source_record, node, owner - 1,
        function_ir_ms
    );
    phase_started = process.monotonic_milliseconds();
    c_emit_function(context, output, owner - 1, entry_module);
    timings.c_emit_ms = timings.c_emit_ms +
        process.monotonic_milliseconds() - phase_started;
}

unsafe bool c_emit_source_record(
    ref IrContext base,
    ref DBuffer output,
    usize module_index,
    usize source_record,
    usize entry_module,
    ref BuildTimings timings
) {
    usize phase_started = process.monotonic_milliseconds();
    text source;
    status loaded = project_read_source_record(
        base.project_source, base.project_root, base.source_data,
        source_record, out source
    );
    if !loaded.ok { return false; }
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
    timings.lex_parse_ms = timings.lex_parse_ms +
        process.monotonic_milliseconds() - phase_started;
    timings.syntax_nodes = timings.syntax_nodes + syntax.length;
    PackedBuffer blocks = PackedBuffer{
        length = 0, capacity = source_length + 32
    };
    PackedBuffer instructions = PackedBuffer{
        length = 0, capacity = source_length * 3 + 64
    };
    PackedBuffer operands = PackedBuffer{
        length = 0, capacity = source_length * 4 + 64
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
    ptr byte name_cache = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    // Spelling-only caching is not scope-safe when locals are shadowed.
    usize spelling_cache_capacity = 0;
    ptr byte spelling_cache = null;
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
    ptr byte expression_start_heads = memory.alloc(
        (source_length + 1) * size_of(usize)
    );
    ptr byte expression_start_next = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte expression_next_start = memory.alloc(
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
        write_usize(name_cache, cache_node * size_of(usize), 0);
        write_usize(call_cache, cache_node * size_of(usize), 0);
        write_usize(type_cache, cache_node * size_of(usize), 0);
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
    context.name_cache = ir_pointer_alias(name_cache);
    context.spelling_cache = ir_pointer_alias(spelling_cache);
    context.spelling_cache_capacity = spelling_cache_capacity;
    context.call_cache = ir_pointer_alias(call_cache);
    context.call_argument_first = ir_pointer_alias(call_argument_first);
    context.call_argument_last = ir_pointer_alias(call_argument_last);
    context.argument_next = ir_pointer_alias(argument_next);
    context.type_cache = ir_pointer_alias(type_cache);
    context.resolved_type_ref_cache = ir_pointer_alias(
        resolved_type_ref_cache
    );
    context.left_expression_cache = ir_pointer_alias(left_expression_cache);
    context.right_expression_cache = ir_pointer_alias(
        right_expression_cache
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
    context.expression_start_heads = ir_pointer_alias(expression_start_heads);
    context.expression_start_capacity = source_length + 1;
    context.expression_start_next = ir_pointer_alias(expression_start_next);
    context.expression_next_start = ir_pointer_alias(expression_next_start);
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
    ir_initialize_node_indexes(context);
    ir_initialize_control_adjacency(context);
    ir_initialize_statement_adjacency(context);
    ir_initialize_initializer_fields(context);
    ir_initialize_array_elements(context);
    ir_initialize_declaration_symbols(context);
    timings.index_ms = timings.index_ms +
        process.monotonic_milliseconds() - phase_started;
    usize node = 0;
    while node < syntax.length {
        if read_record_field(syntax_data, node, 0) == 2 {
            usize body = ir_largest_direct_block(context, node);
            usize owner = ir_owner_symbol(
                context, node,
                resolution_symbol_function(), 0
            );
            bool external_declaration = starts_with_ascii(
                source,
                read_record_field(syntax_data, node, 1),
                "external"
            );
            if external_declaration && body < syntax.length &&
                byte_at_or_zero(
                    source,
                    read_record_field(syntax_data, body, 1)
                ) != 123 {
                node = node + 1;
                continue;
            }
            if body >= syntax.length || owner == 0 || byte_at_or_zero(
                    source,
                    read_record_field(syntax_data, body, 1)
                ) != 123 {
                io.print("OPENC-C-BACKEND-INTERNAL source=");
                io.print(source_record);
                io.print(" node="); io.print(node);
                io.print(" body="); io.print(body);
                io.print(" owner="); io.println(owner);
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
    c_release_source_context(context, diagnostic_data);
    return true;
}

unsafe void c_close_lowering_types(ref IrContext base) {
    // Null lowering has a canonical implementation type that source-level
    // semantic analysis does not otherwise need to materialize.
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

    // Array slicing and owned-storage access can synthesize these forms while
    // lowering even when no declaration spells them explicitly.
    usize semantic_type_count = base.types.length;
    usize type_id = 0;
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

unsafe i32 c_emit_project(
    ref IrContext base,
    text output_source,
    usize output_capacity,
    usize entry_module,
    ref BuildTimings timings
) {
    c_close_lowering_types(base);
    DBuffer output = d_buffer_create(output_capacity * 2 + 1048576);
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
        (base.types.length + 1) * size_of(usize)
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
    ir_initialize_symbol_indexes(base, parameter_last);
    memory.free(parameter_last);
    c_emit_function_prototypes(base, output, entry_module);

    bool emitted_parallel = false;
    if output_capacity >= 262144 && c_project_source_count(base) >= 16 {
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
                if !c_emit_source_record(
                    base, output, module_index,
                    source_first + source_index, entry_module, timings
                ) {
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
    d_put(output, "int main(int argc, char **argv) {\n");
    d_put(output, "    int result;\n");
    d_put(output, "    ocb_process_initialize(argc, argv);\n");
    d_put(output, "    result = (int)oc_entry_main();\n");
    d_put(output, "    ocb_process_finalize();\n");
    d_put(output, "    return result;\n}\n");
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
    status written = file.write_text(
        output_source, d_buffer_text(output)
    );
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
