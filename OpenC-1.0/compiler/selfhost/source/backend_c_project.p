import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool c_emit_source_record(
    ref IrContext base,
    ref DBuffer output,
    usize module_index,
    usize source_record,
    usize entry_module
) {
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
    ptr byte break_data = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    ptr byte continue_data = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    IrContext context = IrContext{
        project_source = base.project_source,
        project_root = base.project_root,
        source = source,
        module_data = base.module_data,
        modules = base.modules,
        source_data = base.source_data,
        type_data = base.type_data,
        types = base.types,
        symbol_data = base.symbol_data,
        detail_data = base.detail_data,
        symbols = base.symbols,
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
        type_cache = ir_pointer_alias(type_cache),
        left_expression_cache = ir_pointer_alias(left_expression_cache),
        right_expression_cache = ir_pointer_alias(right_expression_cache),
        block_parent_cache = ir_pointer_alias(block_parent_cache),
        control_parent_cache = ir_pointer_alias(control_parent_cache),
        statement_nodes = ir_pointer_alias(statement_nodes),
        statement_count = 0,
        block_nodes = ir_pointer_alias(block_nodes),
        block_count = 0,
        control_nodes = ir_pointer_alias(control_nodes),
        control_count = 0,
        expression_nodes = ir_pointer_alias(expression_nodes),
        expression_count = 0,
        name_nodes = ir_pointer_alias(name_nodes),
        name_count = 0,
        declaration_symbol_cache = ir_pointer_alias(
            declaration_symbol_cache
        ),
        top_symbols = ir_pointer_alias(top_symbols),
        top_symbol_count = 0,
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
        next_value = base.next_value
    };
    ir_initialize_node_indexes(context);
    ir_initialize_declaration_symbols(context);
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
                io.print("OPENC-C-BACKEND-INTERNAL source=");
                io.print(source_record);
                io.print(" node="); io.print(node);
                io.print(" body="); io.print(body);
                io.print(" owner="); io.println(owner);
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
                return false;
            }
            ir_lower_function(context, node, owner - 1);
            c_emit_function(
                context, output, owner - 1, entry_module
            );
        }
        node = node + 1;
    }
    base.next_value = context.next_value;
    base.types = context.types;
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

unsafe i32 c_emit_project(
    ref IrContext base,
    text output_source,
    usize output_capacity,
    usize entry_module
) {
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
    c_emit_function_prototypes(base, output, entry_module);

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
                source_first + source_index, entry_module
            ) {
                io.print("OPENC-C-BACKEND-SOURCE-FAILED module=");
                io.print(module_index); io.print(" source=");
                io.println(source_first + source_index);
                d_buffer_destroy(output);
                return 1;
            }
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
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
        d_buffer_destroy(output);
        return 1;
    }
    status written = file.write_text(
        output_source, d_buffer_text(output)
    );
    d_buffer_destroy(output);
    if !written.ok {
        io.println("OPENC-C-BACKEND-WRITE-FAILED");
        return 1;
    }
    return 0;
}
