import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_lower_function(
    ref IrContext context,
    usize function_node,
    usize function_symbol
) {
    context.function_node = function_node;
    context.function_symbol = function_symbol;
    ir_select_function_locals(context, function_symbol);
    context.function_result = read_record_field(
        context.symbol_data, function_symbol, 4
    );
    context.blocks.length = 0;
    context.instructions.length = 0;
    context.operands.length = 0;
    context.break_depth = 0;
    context.continue_depth = 0;
    usize symbol = context.function_local_first;
    while symbol < context.function_local_end {
        write_usize(
            context.local_values, symbol * size_of(usize), 0
        );
        symbol = symbol + 1;
    }
    context.current_block = ir_add_block(context, 1);
    symbol = context.function_local_first;
    while symbol < context.function_local_end {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 {
            usize parameter_node = read_record_field(
                context.detail_data, symbol, 1
            );
            usize parameter_type = read_record_field(
                context.symbol_data, symbol, 4
            );
            if read_record_field(context.detail_data, symbol, 3) == 1 {
                parameter_type = semantic_derived_type(
                    context.type_data, context.types, 12,
                    parameter_type, 0, false, false
                );
            }
            usize address = ir_emit_value(
                context, ir_op_local_alloc(), parameter_type,
                parameter_node, 1,
                read_record_field(context.symbol_data, symbol, 2),
                read_record_field(context.symbol_data, symbol, 3),
                context.operands.length, 0
            );
            write_usize(
                context.local_values, symbol * size_of(usize), address
            );
        }
        symbol = symbol + 1;
    }
    usize body = ir_largest_direct_block(context, function_node);
    if body < context.syntax.length { ir_lower_block(context, body); }
    if context.function_result == semantic_type_void() {
        bool returns = false;
        if context.instructions.length != 0 {
            usize last = context.instructions.length - 1;
            if read_record_field(context.instruction_data, last, 0) ==
                    context.current_block {
                usize opcode = read_record_field(
                    context.instruction_data, last, 2
                );
                returns = opcode == ir_op_return() ||
                    opcode == ir_op_return_void();
            }
        }
        if !returns {
            ir_emit_value(
                context, ir_op_return_void(), semantic_type_void(),
                function_node, 0, 0, 0, context.operands.length, 0
            );
        }
    }

}

unsafe void ir_emit_function_json(
    ref IrContext context,
    usize function_node,
    usize function_symbol
) {
    ir_lower_function(context, function_node, function_symbol);
    io.print("{\"blocks\":[");
    usize block = 0;
    while block < context.blocks.length {
        if block != 0 { io.print(","); }
        io.print("{\"id\":"); io.print(block);
        io.print(",\"instructions\":[");
        usize instruction = 0;
        usize emitted = 0;
        while instruction < context.instructions.length {
            if read_record_field(
                context.instruction_data, instruction, 0
            ) == block {
                if emitted != 0 { io.print(","); }
                ir_emit_instruction_json(context, instruction);
                emitted = emitted + 1;
            }
            instruction = instruction + 1;
        }
        io.print("],\"name\":");
        ir_json_text(ir_block_name(read_record_field(
            context.block_data, block, 1
        )));
        io.print("}");
        block = block + 1;
    }
    io.print("],\"exported\":");
    bool exported = semantic_prefix_has(
        context.source, context.token_data, context.tokens,
        read_record_field(context.syntax_data, function_node, 1),
        read_record_field(context.syntax_data, function_node, 3),
        "export"
    );
    if exported { io.print("true"); } else { io.print("false"); }
    io.print(",\"name\":");
    ir_json_symbol_identity(context, function_symbol);
    io.print(",\"result\":"); io.print(context.function_result);
    io.print(",\"unsafe\":");
    if flow_function_unsafe(context.source, context.syntax_data, function_node) {
        io.print("true");
    } else { io.print("false"); }
    io.print("}");
}

unsafe usize ir_entry_module(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize module_count
) {
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            read_record_field(detail_data, symbol, 2) == 0 {
            text symbol_source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                read_record_field(symbol_data, symbol, 1), out symbol_source
            );
            if !loaded.ok {
                symbol = symbol + 1;
                continue;
            }
            if span_equals_ascii(
                symbol_source,
                read_record_field(symbol_data, symbol, 2),
                read_record_field(symbol_data, symbol, 3), "main"
            ) {
                return read_record_field(detail_data, symbol, 0);
            }
        }
        symbol = symbol + 1;
    }
    return module_count;
}

unsafe ptr byte ir_pointer_alias(ptr byte value) { return value; }

unsafe usize ir_emit_builtin_module(
    text project_source,
    ptr byte module_data,
    ref PackedBuffer modules,
    text name,
    usize emitted
) {
    if project_find_module(
        project_source, module_data, modules, name
    ) >= 0 { return emitted; }
    if emitted != 0 { io.print(","); }
    io.print("{\"functions\":[],\"module\":");
    ir_json_text(name);
    io.print("}");
    return emitted + 1;
}

struct IrObserveState {
    PackedBuffer types;
    usize next_value;
    usize emitted_functions;
}

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
        expression_start_heads = null,
        expression_start_capacity = 0,
        expression_start_next = null,
        expression_next_start = null,
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
        profile_symbol_candidates = 0
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
    memory.free(operand_data);
    memory.free(instruction_detail);
    memory.free(instruction_data);
    memory.free(block_data);
    memory.free(syntax_data);
    memory.free(diagnostic_data);
    memory.free(token_data);
    return true;
}

unsafe i32 observe_semantic_ir(text project_path) {
    io.println("OPENC-SEMANTIC-IR-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        return 1;
    }
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
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize frontend_errors = 0;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(
            module_data, module_index, 2
        );
        usize source_count = read_record_field(
            module_data, module_index, 3
        );
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status declaration_source_status = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !declaration_source_status.ok {
                io.println("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            frontend_errors = frontend_errors + flow_source_frontend_errors(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    if frontend_errors != 0 {
        io.print("FRONTEND_ERROR "); io.println(frontend_errors);
        return 1;
    }

    usize capacity = total_source_length * 8 + project_length + 1024;
    PackedBuffer types = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer symbols = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer errors = PackedBuffer{ length = 0, capacity = capacity };
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
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_predeclare_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_collect_source_symbols(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types, symbol_data, detail_data, symbols
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            flow_precheck_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_record,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            flow_validate_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_record,
                type_data, symbol_data, detail_data, symbols,
                error_data, errors
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    usize acceptance_errors = acceptance_validate_project(
        project_source, project_root,
        module_data, modules, source_data, sources,
        type_data, types, symbol_data, detail_data, symbols
    );
    if errors.length + acceptance_errors != 0 {
        io.print("SEMANTIC_ERROR ");
        io.println(errors.length + acceptance_errors);
        return 1;
    }

    usize entry = ir_entry_module(
        project_source, project_root, source_data,
        symbol_data, detail_data, symbols, modules.length
    );
    io.print("{\"entry_function\":");
    if entry < modules.length { io.print("\"main\""); }
    else { io.print("\"\""); }
    io.print(",\"entry_module\":");
    if entry < modules.length {
        ir_json_slice(
            project_source,
            read_record_field(module_data, entry, 0),
            read_record_field(module_data, entry, 1)
        );
    } else { io.print("\"\""); }
    io.print(",\"modules\":[");

    usize next_value = 1;
    usize emitted_modules = 0;
    module_index = 0;
    while module_index < modules.length {
        if emitted_modules != 0 { io.print(","); }
        io.print("{\"functions\":[");
        IrObserveState state = IrObserveState{
            types = types,
            next_value = next_value,
            emitted_functions = 0
        };
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            if !ir_observe_emit_source(
                project_source, project_root, module_data, modules,
                source_data, type_data, symbol_data, detail_data,
                symbols, module_index, source_record, state
            ) { return 1; }
            source_index = source_index + 1;
        }
        next_value = state.next_value;
        types = state.types;
        io.print("],\"module\":");
        ir_json_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        );
        io.print("}");
        emitted_modules = emitted_modules + 1;
        module_index = module_index + 1;
    }
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.io", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.memory", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.text", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.process", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.path", emitted_modules
    );
    emitted_modules = ir_emit_builtin_module(
        project_source, module_data, modules, "system.file", emitted_modules
    );
    io.println("],\"schema\":\"openc.core_ir.v1\"}");
    return 0;
}
