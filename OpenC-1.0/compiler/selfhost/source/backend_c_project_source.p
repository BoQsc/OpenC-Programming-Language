import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool c_emit_prepared_source_functions_inner(
    ref IrContext source_context,
    ref DBuffer output,
    ref BuildTimings timings,
    usize source_record,
    usize entry_module,
    ref IrFunctionScratch scratch
) {
    // The prepared view borrows only source/project facts after acceptance.
    // Exactly one worker owns scratch in this first vertical slice; no
    // acceptance work or buffers are replicated for function jobs yet.
    usize index_started = process.monotonic_milliseconds();
    if !ir_prepare_function_index_caches(source_context) {
        io.print("OPENC-FUNCTION-INDEX-CACHE-NOT-READY source=");
        io.println(source_record);
        return false;
    }
    if !ir_function_cache_spans_disjoint(source_context) {
        io.print("OPENC-FUNCTION-CACHE-SPANS-OVERLAP source=");
        io.println(source_record);
        return false;
    }
    timings.function_index_preparation_ms =
        timings.function_index_preparation_ms +
        process.monotonic_milliseconds() - index_started;
    timings.prepared_function_calls = timings.prepared_function_calls +
        source_context.call_count;
    usize index_fingerprint =
        ir_function_index_cache_fingerprint(source_context);
    IrPreparedSource prepared = IrPreparedSource{ view = source_context };
    ir_prepared_source(source_context, prepared);
    usize frozen_type_count = source_context.types.length;
    usize late_type_misses = 0;
    usize node = 0;
    while node < source_context.syntax.length {
        if read_record_field(source_context.syntax_data, node, 0) == 2 {
            usize body = ir_largest_direct_block(source_context, node);
            usize owner = ir_owner_symbol(
                source_context, node, resolution_symbol_function(), 0
            );
            if body >= source_context.syntax.length || byte_at_or_zero(
                    source_context.source,
                    read_record_field(source_context.syntax_data, body, 1)
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
                return false;
            }
            IrContext function_context = source_context;
            ir_bind_prepared_function(
                prepared, scratch, function_context
            );
            function_context.cache_write_owner_encoded = node + 1;
            function_context.cache_write_violations = 0;
            usize types_before = function_context.types.length;
            c_lower_and_emit_function(
                function_context, output, timings, source_record, node,
                owner, entry_module
            );
            if function_context.cache_write_violations != 0 {
                io.print("OPENC-FUNCTION-CACHE-OWNERSHIP-MISS source=");
                io.print(source_record);
                io.print(" node="); io.print(node);
                io.print(" writes=");
                io.println(function_context.cache_write_violations);
                return false;
            }
            function_context.cache_write_owner_encoded = 0;
            if timings.freeze_function_types &&
                function_context.types.length != types_before {
                if function_context.types.length > types_before {
                    late_type_misses = late_type_misses +
                        function_context.types.length - types_before;
                    if late_type_misses <= 16 {
                        usize type_id = types_before;
                        while type_id < function_context.types.length {
                            io.print("OPENC-FUNCTION-TYPE-LATE source=");
                            io.print(source_record);
                            io.print(" node="); io.print(node);
                            io.print(" type="); io.print(type_id);
                            io.print(" kind="); io.print(read_record_field(
                                function_context.type_data, type_id, 0
                            ));
                            io.print(" element="); io.println(read_record_field(
                                function_context.type_data, type_id, 1
                            ));
                            type_id = type_id + 1;
                        }
                    }
                    timings.late_function_type_misses =
                        timings.late_function_type_misses + late_type_misses;
                    io.print("OPENC-FUNCTION-TYPE-FREEZE-MISS count=");
                    io.println(late_type_misses);
                    return false;
                } else {
                    io.println("OPENC-FUNCTION-TYPE-REGISTRY-SHRANK");
                    return false;
                }
            }
            ir_capture_function_scratch(scratch, function_context);
        }
        node = node + 1;
    }
    ir_bind_prepared_function(prepared, scratch, source_context);
    if ir_function_index_cache_fingerprint(source_context) !=
        index_fingerprint {
        io.print("OPENC-FUNCTION-INDEX-CACHE-MUTATED source=");
        io.println(source_record);
        return false;
    }
    timings.late_function_type_misses =
        timings.late_function_type_misses + late_type_misses;
    if timings.freeze_function_types &&
        (late_type_misses != 0 || source_context.types.length !=
            frozen_type_count) {
        io.print("OPENC-FUNCTION-TYPE-FREEZE-MISS count=");
        io.println(late_type_misses);
        return false;
    }
    return true;
}

unsafe bool c_emit_prepared_source_functions(
    ref IrContext source_context,
    ref DBuffer output,
    ref BuildTimings timings,
    usize source_record,
    usize entry_module
) {
    if timings.freeze_function_types {
        usize freeze_started = process.monotonic_milliseconds();
        timings.prematerialized_function_types =
            timings.prematerialized_function_types +
            ir_prematerialize_ref_call_pointer_types(source_context);
        timings.function_type_prematerialization_ms =
            timings.function_type_prematerialization_ms +
            process.monotonic_milliseconds() - freeze_started;
    }
    IrFunctionScratch scratch = ir_function_scratch(source_context);
    ptr byte source_type_data = source_context.type_data;
    PackedBuffer source_types = source_context.types;
    ptr byte owned_type_data = null;
    if timings.freeze_function_types {
        // Copy live records plus exactly one spare record. A first missed
        // closure stays worker-local and fails after its function; a second
        // append is rejected before write by semantic_add_type. Four such
        // bounded scratch copies reserve at most 2 MiB across source chunks.
        usize max_type_bytes = 524288;
        usize max_slots = max_type_bytes / record_stride();
        if source_types.length == 0 || source_types.length >= max_slots ||
            source_type_data == null {
            io.println("OPENC-FUNCTION-TYPE-COPY-BUDGET");
            return false;
        }
        usize slots = source_types.length + 1;
        owned_type_data = memory.alloc(slots * record_stride());
        if owned_type_data == null || owned_type_data == source_type_data {
            io.println("OPENC-FUNCTION-TYPE-COPY-ALIAS");
            return false;
        }
        usize type_word = 0;
        while type_word < source_types.length * 5 {
            usize offset = type_word * size_of(usize);
            write_usize(
                owned_type_data, offset,
                read_usize(source_type_data, offset)
            );
            type_word = type_word + 1;
        }
        scratch.type_data = ir_pointer_alias(owned_type_data);
        scratch.types = PackedBuffer{
            length = source_types.length, capacity = slots
        };
    }
    scope memory.free(owned_type_data);
    if !timings.owned_function_project_caches {
        bool prepared_passed = c_emit_prepared_source_functions_inner(
            source_context, output, timings, source_record, entry_module,
            scratch
        );
        if timings.freeze_function_types {
            source_context.type_data = source_type_data;
            source_context.types = source_types;
        }
        return prepared_passed;
    }
    // One serial function scratch owns one project-cache snapshot. A future
    // worker may receive its own snapshot only after a global RAM reservation.
    // No full syntax/source arena is copied here.
    usize max_words = 131072;
    if source_context.symbols.length >= max_words ||
        source_context.types.length >= max_words {
        io.println("OPENC-FUNCTION-PROJECT-CACHE-BUDGET");
        return false;
    }
    usize symbol_slots = source_context.symbols.length + 1;
    usize type_slots = source_context.types.length;
    usize words = symbol_slots + 3 * type_slots;
    if words > max_words || type_slots == 0 ||
        type_slots > source_context.native_layout_cache_entries ||
        source_context.symbol_export_cache == null ||
        source_context.native_layout_size_cache == null ||
        source_context.native_layout_alignment_cache == null ||
        source_context.native_layout_state_cache == null {
        io.println("OPENC-FUNCTION-PROJECT-CACHE-BUDGET");
        return false;
    }
    ptr byte source_export = source_context.symbol_export_cache;
    ptr byte source_layout_size = source_context.native_layout_size_cache;
    ptr byte source_layout_alignment =
        source_context.native_layout_alignment_cache;
    ptr byte source_layout_state = source_context.native_layout_state_cache;
    usize source_layout_entries = source_context.native_layout_cache_entries;
    ptr byte owned_export = memory.alloc(symbol_slots * size_of(usize));
    if owned_export == null { return false; }
    scope memory.free(owned_export);
    ptr byte owned_layout_size = memory.alloc(type_slots * size_of(usize));
    if owned_layout_size == null { return false; }
    scope memory.free(owned_layout_size);
    ptr byte owned_layout_alignment = memory.alloc(
        type_slots * size_of(usize)
    );
    if owned_layout_alignment == null { return false; }
    scope memory.free(owned_layout_alignment);
    ptr byte owned_layout_state = memory.alloc(type_slots * size_of(usize));
    if owned_layout_state == null { return false; }
    scope memory.free(owned_layout_state);
    if owned_export == source_export ||
        owned_layout_size == source_layout_size ||
        owned_layout_alignment == source_layout_alignment ||
        owned_layout_state == source_layout_state {
        io.println("OPENC-FUNCTION-PROJECT-CACHE-ALIAS");
        return false;
    }
    usize symbol = 0;
    while symbol < symbol_slots {
        write_usize(
            owned_export, symbol * size_of(usize),
            read_usize(source_export, symbol * size_of(usize))
        );
        symbol = symbol + 1;
    }
    usize type_id = 0;
    while type_id < type_slots {
        usize offset = type_id * size_of(usize);
        usize state = read_usize(source_layout_state, offset);
        if state == 1 {
            io.println("OPENC-FUNCTION-PROJECT-CACHE-IN-PROGRESS");
            return false;
        }
        write_usize(owned_layout_state, offset, state);
        usize size = 0;
        usize alignment = 0;
        if state != 0 {
            size = read_usize(source_layout_size, offset);
            alignment = read_usize(source_layout_alignment, offset);
        }
        write_usize(owned_layout_size, offset, size);
        write_usize(owned_layout_alignment, offset, alignment);
        type_id = type_id + 1;
    }
    scratch.symbol_export_cache = owned_export;
    scratch.native_layout_size_cache = owned_layout_size;
    scratch.native_layout_alignment_cache = owned_layout_alignment;
    scratch.native_layout_state_cache = owned_layout_state;
    scratch.native_layout_cache_entries = type_slots;
    timings.owned_function_project_cache_bytes =
        timings.owned_function_project_cache_bytes +
        words * size_of(usize);
    if words * size_of(usize) >
        timings.owned_function_project_cache_max_source_bytes {
        timings.owned_function_project_cache_max_source_bytes =
            words * size_of(usize);
    }
    bool passed = c_emit_prepared_source_functions_inner(
        source_context, output, timings, source_record, entry_module,
        scratch
    );
    // The source record still owns the originals; never leave it pointing at
    // the function worker's scope-limited allocation.
    source_context.symbol_export_cache = source_export;
    source_context.native_layout_size_cache = source_layout_size;
    source_context.native_layout_alignment_cache = source_layout_alignment;
    source_context.native_layout_state_cache = source_layout_state;
    source_context.native_layout_cache_entries = source_layout_entries;
    if timings.freeze_function_types {
        source_context.type_data = source_type_data;
        source_context.types = source_types;
    }
    return passed;
}

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
    context.function_result = semantic_type_void();
    context.name_cache = ir_pointer_alias(name_cache);
    context.spelling_cache = ir_pointer_alias(spelling_cache);
    context.spelling_cache_capacity = spelling_cache_capacity;
    context.call_cache = ir_pointer_alias(call_cache);
    context.call_argument_first = ir_pointer_alias(call_argument_first);
    context.call_argument_last = ir_pointer_alias(call_argument_last);
    context.argument_next = ir_pointer_alias(argument_next);
    context.type_cache = ir_pointer_alias(type_cache);
    context.profile_type_seen = ir_pointer_alias(profile_type_seen);
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
    if timings.prepared_function_scratch && timings.emission_mode == 2 {
        if !c_emit_prepared_source_functions(
                context, output, timings, source_record, entry_module
            ) {
            if parsed_source_reused {
                context.syntax_data = null;
                context.token_data = null;
            }
            c_release_source_context(context, diagnostic_data);
            return false;
        }
    } else {
        usize node = 0;
        while node < syntax.length {
            if read_record_field(syntax_data, node, 0) == 2 {
                usize body = ir_largest_direct_block(context, node);
                usize owner = ir_owner_symbol(
                    context, node,
                    resolution_symbol_function(), 0
                );
                // A semicolon-only declaration has no IR body. It is valid
                // input, but its implementation must be supplied elsewhere.
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
