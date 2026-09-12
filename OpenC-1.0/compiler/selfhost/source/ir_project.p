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
                return module_count;
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
