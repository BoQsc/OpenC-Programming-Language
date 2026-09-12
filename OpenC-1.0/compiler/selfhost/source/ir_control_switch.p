import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_lower_switch(ref IrContext context, usize statement) {
    usize subject_node = ir_switch_subject(context, statement);
    usize subject_value = ir_lower_node(
        context, subject_node, semantic_type_error(), 0
    );
    usize after_block = ir_add_block(context, 12);
    usize dispatch_block = context.current_block;
    write_usize(
        context.break_data,
        context.break_depth * size_of(usize), after_block
    );
    context.break_depth = context.break_depth + 1;
    usize item_index = 0;
    while true {
        usize item = ir_switch_item(context, statement, item_index);
        if item >= context.syntax.length { break; }
        usize body = ir_direct_block(context, statement, item_index);
        usize item_kind = read_record_field(
            context.syntax_data, item, 0
        );
        usize case_name = 13;
        if item_kind == 19 { case_name = 14; }
        usize case_block = ir_add_block(context, case_name);
        context.current_block = dispatch_block;
        if item_kind == 18 {
            usize case_node = ir_switch_case_expression(context, body);
            usize case_value = ir_lower_node(
                context, case_node, semantic_type_error(), 0
            );
            usize compare_first = context.operands.length;
            ir_operand_empty(context, subject_value);
            ir_operand_empty(context, case_value);
            usize compare = ir_emit_value(
                context, ir_op_compare(), semantic_type_bool(), item,
                2, 0, 0, compare_first, 2
            );
            usize comparison_record = context.instructions.length - 1;
            write_record_field(
                context.instruction_detail, comparison_record, 0, 2
            );
            write_record_field(
                context.instruction_detail, comparison_record, 1, 13
            );
            usize next_block = after_block;
            if ir_switch_item(
                context, statement, item_index + 1
            ) < context.syntax.length {
                next_block = ir_add_block(context, 15);
            }
            usize branch_first = context.operands.length;
            ir_operand_empty(context, compare);
            ir_operand_block(context, case_block);
            ir_operand_block(context, next_block);
            ir_emit_void(
                context, ir_op_branch_conditional(), item,
                0, 0, 0, branch_first, 3
            );
            dispatch_block = next_block;
        } else {
            usize default_first = context.operands.length;
            ir_operand_block(context, case_block);
            ir_emit_void(
                context, ir_op_branch(), item,
                0, 0, 0, default_first, 1
            );
            dispatch_block = after_block;
        }
        context.current_block = case_block;
        if body < context.syntax.length { ir_lower_block(context, body); }
        usize exit_first = context.operands.length;
        ir_operand_block(context, after_block);
        ir_emit_void(
            context, ir_op_branch(), item,
            0, 0, 0, exit_first, 1
        );
        item_index = item_index + 1;
    }
    context.break_depth = context.break_depth - 1;
    context.current_block = after_block;
}

unsafe void ir_lower_block(ref IrContext context, usize block) {
    usize previous_start = 0;
    usize previous_record = 0;
    bool first_statement = true;
    while true {
        usize requested_start = previous_start;
        usize requested_record = previous_record;
        if first_statement {
            requested_start = 0;
            requested_record = 0;
        }
        usize statement = ir_next_direct_statement(
            context, block,
            requested_start, requested_record
        );
        if statement >= context.syntax.length { break; }
        usize kind = read_record_field(context.syntax_data, statement, 0);
        usize control_parent = ir_control_parent(context, statement);
        bool header_statement = false;
        if control_parent < context.syntax.length && read_record_field(
            context.syntax_data, control_parent, 0
        ) == 16 {
            usize control_body = ir_largest_direct_block(
                context, control_parent
            );
            if control_body < context.syntax.length {
                header_statement = read_record_field(
                    context.syntax_data, statement, 1
                ) < read_record_field(
                    context.syntax_data, control_body, 1
                );
            }
        }
        if header_statement {
            // Header declarations are lowered by their owning control node.
        } else if kind == 12 {
            usize symbol = ir_local_symbol(context, statement);
            if symbol < context.symbols.length {
                usize local_type = read_record_field(
                    context.symbol_data, symbol, 4
                );
                usize address = ir_emit_value(
                    context, ir_op_local_alloc(), local_type, statement,
                    1,
                    read_record_field(context.syntax_data, statement, 3),
                    read_record_field(context.syntax_data, statement, 4),
                    context.operands.length, 0
                );
                write_usize(
                    context.local_values, symbol * size_of(usize), address
                );
                usize initializer = ir_local_initializer_root(
                    context, statement
                );
                if initializer < context.syntax.length && flow_span_has_byte(
                    context.source,
                    read_record_field(context.syntax_data, statement, 1),
                    read_record_field(context.syntax_data, statement, 2), 61
                ) {
                    usize value = ir_lower_expected(
                        context, initializer, local_type
                    );
                    usize operand_first = context.operands.length;
                    usize immediate = 0;
                    if read_record_field(
                        context.type_data, local_type, 0
                    ) == 12 { immediate = 3; }
                    ir_add_operand(context, address, immediate, 1, 0);
                    ir_operand_empty(context, value);
                    ir_emit_void(
                        context, ir_op_store(), statement,
                        0, 0, 0, operand_first, 2
                    );
                }
            }
        } else if kind == 13 {
            usize expression = ir_root_expression(context, statement);
            ir_lower_node(
                context, expression, semantic_type_error(), 0
            );
        } else if kind == 22 {
            usize expression = ir_root_expression(context, statement);
            if expression < context.syntax.length {
                usize value = ir_lower_expected(
                    context, expression, context.function_result
                );
                usize operand_first = context.operands.length;
                ir_operand_empty(context, value);
                ir_emit_void(
                    context, ir_op_return(), statement,
                    0, 0, 0, operand_first, 1
                );
            } else {
                ir_emit_void(
                    context, ir_op_return_void(), statement,
                    0, 0, 0, context.operands.length, 0
                );
            }
        } else if kind == 23 {
            ir_lower_scope_statement(context, statement);
        } else if kind == 14 {
            ir_lower_if(context, statement);
        } else if kind == 15 {
            ir_lower_while(context, statement);
        } else if kind == 16 {
            ir_lower_for(context, statement);
        } else if kind == 17 {
            ir_lower_switch(context, statement);
        } else if kind == 20 {
            if context.break_depth != 0 {
                usize target = read_usize(
                    context.break_data,
                    (context.break_depth - 1) * size_of(usize)
                );
                usize operand_first = context.operands.length;
                ir_operand_block(context, target);
                ir_emit_void(
                    context, ir_op_branch(), statement,
                    0, 0, 0, operand_first, 1
                );
            }
        } else if kind == 21 {
            if context.continue_depth != 0 {
                usize target = read_usize(
                    context.continue_data,
                    (context.continue_depth - 1) * size_of(usize)
                );
                usize operand_first = context.operands.length;
                ir_operand_block(context, target);
                ir_emit_void(
                    context, ir_op_branch(), statement,
                    0, 0, 0, operand_first, 1
                );
            }
        } else if kind == 11 || kind == 24 || kind == 25 {
            usize nested = statement;
            if kind == 24 || kind == 25 {
                nested = ir_largest_direct_block(context, statement);
            }
            if nested < context.syntax.length {
                ir_lower_block(context, nested);
            }
        }
        previous_start = read_record_field(
            context.syntax_data, statement, 1
        );
        previous_record = statement;
        first_statement = false;
    }
}
