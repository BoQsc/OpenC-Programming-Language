import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_lower_while(ref IrContext context, usize statement) {
    usize body = ir_direct_block(context, statement, 0);
    if body >= context.syntax.length {
        body = ir_largest_direct_block(context, statement);
    }
    usize header_block = ir_add_block(context, 5);
    usize body_block = ir_add_block(context, 6);
    usize after_block = ir_add_block(context, 7);
    usize operand_first = context.operands.length;
    ir_operand_block(context, header_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, operand_first, 1
    );
    context.current_block = header_block;
    usize condition = ir_largest_expression_before(
        context, statement, ir_first_block_start(context, statement)
    );
    usize condition_value = ir_lower_node(
        context, condition, semantic_type_bool(), 0
    );
    operand_first = context.operands.length;
    ir_operand_empty(context, condition_value);
    ir_operand_block(context, body_block);
    ir_operand_block(context, after_block);
    ir_emit_void(
        context, ir_op_branch_conditional(), condition,
        0, 0, 0, operand_first, 3
    );
    context.current_block = body_block;
    write_usize(
        context.break_data,
        context.break_depth * size_of(usize), after_block
    );
    context.break_depth = context.break_depth + 1;
    write_usize(
        context.continue_data,
        context.continue_depth * size_of(usize), header_block
    );
    context.continue_depth = context.continue_depth + 1;
    if body < context.syntax.length { ir_lower_block(context, body); }
    context.break_depth = context.break_depth - 1;
    context.continue_depth = context.continue_depth - 1;
    operand_first = context.operands.length;
    ir_operand_block(context, header_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, operand_first, 1
    );
    context.current_block = after_block;
}

unsafe void ir_lower_for(ref IrContext context, usize statement) {
    usize body = ir_largest_direct_block(context, statement);
    usize body_start = read_record_field(context.syntax_data, body, 1);
    usize first_semicolon = body_start;
    usize second_semicolon = body_start;
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens,
        read_record_field(context.syntax_data, statement, 1)
    );
    usize semicolons = 0;
    while token < context.tokens.length && read_record_field(
        context.token_data, token, 1
    ) < body_start {
        if span_equals_ascii(
            context.source,
            read_record_field(context.token_data, token, 1),
            read_record_field(context.token_data, token, 2), ";"
        ) {
            if semicolons == 0 {
                first_semicolon = read_record_field(
                    context.token_data, token, 1
                );
            } else if semicolons == 1 {
                second_semicolon = read_record_field(
                    context.token_data, token, 1
                );
            }
            semicolons = semicolons + 1;
        }
        token = token + 1;
    }
    usize local_node = context.syntax.length;
    usize record = 0;
    while record < context.syntax.length {
        if read_record_field(context.syntax_data, record, 0) == 12 &&
            semantic_node_contains(
                context.syntax_data, statement, record
            ) && read_record_field(
                context.syntax_data, record, 1
            ) < first_semicolon {
            local_node = record;
            break;
        }
        record = record + 1;
    }
    if local_node < context.syntax.length {
        usize local_symbol = ir_local_symbol(context, local_node);
        if local_symbol < context.symbols.length {
            usize local_type = read_record_field(
                context.symbol_data, local_symbol, 4
            );
            usize address = ir_emit_value(
                context, ir_op_local_alloc(), local_type, local_node,
                1,
                read_record_field(context.syntax_data, local_node, 3),
                read_record_field(context.syntax_data, local_node, 4),
                context.operands.length, 0
            );
            write_usize(
                context.local_values,
                local_symbol * size_of(usize), address
            );
            usize initializer = ir_local_initializer_root(
                context, local_node
            );
            if initializer < context.syntax.length {
                usize initial_value = ir_lower_node(
                    context, initializer, local_type, 0
                );
                usize initial_first = context.operands.length;
                ir_operand_empty(context, address);
                ir_operand_empty(context, initial_value);
                ir_emit_void(
                    context, ir_op_store(), local_node,
                    0, 0, 0, initial_first, 2
                );
            }
        }
    }
    usize condition_node = ir_root_in_bounds(
        context, first_semicolon + 1, second_semicolon
    );
    usize step_node = ir_root_in_bounds(
        context, second_semicolon + 1, body_start
    );
    usize header_block = ir_add_block(context, 8);
    usize body_block = ir_add_block(context, 9);
    usize step_block = ir_add_block(context, 10);
    usize after_block = ir_add_block(context, 11);
    usize branch_first = context.operands.length;
    ir_operand_block(context, header_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, branch_first, 1
    );
    context.current_block = header_block;
    if condition_node < context.syntax.length {
        usize condition_value = ir_lower_node(
            context, condition_node, semantic_type_bool(), 0
        );
        usize condition_first = context.operands.length;
        ir_operand_empty(context, condition_value);
        ir_operand_block(context, body_block);
        ir_operand_block(context, after_block);
        ir_emit_void(
            context, ir_op_branch_conditional(), condition_node,
            0, 0, 0, condition_first, 3
        );
    } else {
        usize body_first = context.operands.length;
        ir_operand_block(context, body_block);
        ir_emit_void(
            context, ir_op_branch(), statement,
            0, 0, 0, body_first, 1
        );
    }
    context.current_block = body_block;
    write_usize(
        context.break_data,
        context.break_depth * size_of(usize), after_block
    );
    context.break_depth = context.break_depth + 1;
    write_usize(
        context.continue_data,
        context.continue_depth * size_of(usize), step_block
    );
    context.continue_depth = context.continue_depth + 1;
    if body < context.syntax.length { ir_lower_block(context, body); }
    context.break_depth = context.break_depth - 1;
    context.continue_depth = context.continue_depth - 1;
    usize step_first = context.operands.length;
    ir_operand_block(context, step_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, step_first, 1
    );
    context.current_block = step_block;
    if step_node < context.syntax.length {
        ir_lower_node(context, step_node, semantic_type_error(), 0);
    }
    usize header_first = context.operands.length;
    ir_operand_block(context, header_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, header_first, 1
    );
    context.current_block = after_block;
}
