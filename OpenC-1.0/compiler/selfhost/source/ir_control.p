import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_expected(
    ref IrContext context,
    usize node,
    usize expected
) {
    if expected < context.types.length {
        usize expected_kind = read_record_field(
            context.type_data, expected, 0
        );
        usize actual = ir_node_type(
            context, node, semantic_type_error()
        );
        if expected_kind == 12 && actual < context.types.length &&
            read_record_field(context.type_data, actual, 0) != 12 {
            return ir_lower_node(context, node, semantic_type_error(), 2);
        }
        usize expected_node_kind = read_record_field(
            context.syntax_data, node, 0
        );
        bool optional_direct_literal = expected_node_kind >= 29 &&
            expected_node_kind <= 32;
        if expected_kind == 14 && actual != expected &&
            expected_node_kind != 34 && !optional_direct_literal {
            usize value = ir_lower_node(context, node, ir_type_element(
                context, expected
            ), 0);
            usize first = context.operands.length;
            ir_operand_empty(context, value);
            return ir_emit_value(
                context, ir_op_optional_some(), expected, node,
                2, 7, 0, first, 1
            );
        }
    }
    return ir_lower_node(context, node, expected, 0);
}

unsafe usize ir_direct_else_if(ref IrContext context, usize parent) {
    usize selected = context.syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize first_block = ir_direct_block(context, parent, 0);
    usize after_then = read_record_field(context.syntax_data, parent, 1);
    if first_block < context.syntax.length {
        after_then = read_record_field(
            context.syntax_data, first_block, 1
        ) + read_record_field(context.syntax_data, first_block, 2);
    }
    usize record = 0;
    while record < context.syntax.length {
        if record != parent && read_record_field(
                context.syntax_data, record, 0
            ) == 14 && semantic_node_contains(
                context.syntax_data, parent, record
            ) && flow_control_parent(
                context.syntax_data, context.syntax, record
            ) == parent && read_record_field(
                context.syntax_data, record, 1
            ) >= after_then {
            usize start = read_record_field(context.syntax_data, record, 1);
            if selected == context.syntax.length || start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe void ir_lower_if(ref IrContext context, usize statement) {
    usize first_block = ir_direct_block(context, statement, 0);
    usize second_block = ir_direct_block(context, statement, 1);
    usize else_if = ir_direct_else_if(context, statement);
    usize condition = ir_largest_expression_before(
        context, statement, ir_first_block_start(context, statement)
    );
    usize condition_value = ir_lower_node(
        context, condition, semantic_type_bool(), 0
    );
    usize then_block = ir_add_block(context, 2);
    usize else_block = ir_add_block(context, 3);
    usize merge_block = ir_add_block(context, 4);
    usize operand_first = context.operands.length;
    ir_operand_empty(context, condition_value);
    ir_operand_block(context, then_block);
    ir_operand_block(context, else_block);
    ir_emit_void(
        context, ir_op_branch_conditional(), condition,
        0, 0, 0, operand_first, 3
    );
    context.current_block = then_block;
    if first_block < context.syntax.length {
        ir_lower_block(context, first_block);
    }
    operand_first = context.operands.length;
    ir_operand_block(context, merge_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, operand_first, 1
    );
    context.current_block = else_block;
    if second_block < context.syntax.length {
        ir_lower_block(context, second_block);
    } else if else_if < context.syntax.length {
        ir_lower_if(context, else_if);
    }
    operand_first = context.operands.length;
    ir_operand_block(context, merge_block);
    ir_emit_void(
        context, ir_op_branch(), statement,
        0, 0, 0, operand_first, 1
    );
    context.current_block = merge_block;
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
        usize statement = flow_next_direct_statement(
            context.syntax_data, context.syntax, block,
            requested_start, requested_record
        );
        if statement >= context.syntax.length { break; }
        usize kind = read_record_field(context.syntax_data, statement, 0);
        usize control_parent = flow_control_parent(
            context.syntax_data, context.syntax, statement
        );
        bool header_statement = false;
        if control_parent < context.syntax.length && read_record_field(
            context.syntax_data, control_parent, 0
        ) == 16 {
            usize control_body = flow_largest_direct_block(
                context.syntax_data, context.syntax, control_parent
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
                usize initializer = flow_local_initializer_root(
                    context.syntax_data, context.syntax, statement
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
            usize expression = flow_root_expression(
                context.syntax_data, context.syntax, statement
            );
            ir_lower_node(
                context, expression, semantic_type_error(), 0
            );
        } else if kind == 22 {
            usize expression = flow_root_expression(
                context.syntax_data, context.syntax, statement
            );
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
            usize action = flow_root_expression(
                context.syntax_data, context.syntax, statement
            );
            ptr byte scope_values = memory.alloc(
                (context.syntax.length + 1) * size_of(usize)
            );
            usize scope_count = 0;
            usize text_kind = 2;
            usize text_one = 9;
            usize text_two = 0;
            if action < context.syntax.length && read_record_field(
                context.syntax_data, action, 0
            ) == 38 {
                usize selected = ir_select_call(context, action);
                if selected < context.symbols.length {
                    text_kind = 3;
                    text_one = selected;
                } else {
                    usize callee = read_record_field(
                        context.syntax_data, action, 3
                    );
                    text_kind = 1;
                    text_one = read_record_field(
                        context.syntax_data, callee, 1
                    );
                    text_two = read_record_field(
                        context.syntax_data, callee, 2
                    );
                    if ir_builtin_call(
                        context.source, text_one, text_two
                    ) { text_kind = 7; }
                }
                usize arguments = read_record_field(
                    context.syntax_data, action, 4
                );
                usize argument = 0;
                while argument < arguments {
                    IrBounds scope_bounds = ir_argument_bounds(
                        context, action, argument
                    );
                    if scope_bounds.valid {
                        usize child = ir_root_in_bounds(
                            context, scope_bounds.start, scope_bounds.end
                        );
                        write_usize(
                            scope_values, scope_count * size_of(usize),
                            ir_lower_node(
                                context, child, semantic_type_error(), 0
                            )
                        );
                        scope_count = scope_count + 1;
                    }
                    argument = argument + 1;
                }
            } else if action < context.syntax.length && read_record_field(
                context.syntax_data, action, 0
            ) == 45 {
                text_kind = 2;
                text_one = 8;
                usize owner_node = flow_event_first_name(
                    context.syntax_data, context.syntax, action
                );
                write_usize(
                    scope_values, scope_count * size_of(usize),
                    ir_lower_node(
                        context, owner_node, semantic_type_error(), 0
                    )
                );
                scope_count = scope_count + 1;
            }
            usize operand_first = context.operands.length;
            usize scope_index = 0;
            while scope_index < scope_count {
                ir_operand_empty(context, read_usize(
                    scope_values, scope_index * size_of(usize)
                ));
                scope_index = scope_index + 1;
            }
            memory.free(scope_values);
            ir_emit_void(
                context, ir_op_scope_register(), statement,
                text_kind, text_one, text_two,
                operand_first, scope_count
            );
        } else if kind == 14 {
            ir_lower_if(context, statement);
        } else if kind == 15 {
            usize body = ir_direct_block(context, statement, 0);
            if body >= context.syntax.length {
                body = flow_largest_direct_block(
                    context.syntax_data, context.syntax, statement
                );
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
        } else if kind == 16 {
            usize body = flow_largest_direct_block(
                context.syntax_data, context.syntax, statement
            );
            usize body_start = read_record_field(
                context.syntax_data, body, 1
            );
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
                    usize initializer = flow_local_initializer_root(
                        context.syntax_data, context.syntax, local_node
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
                ir_lower_node(
                    context, step_node, semantic_type_error(), 0
                );
            }
            usize header_first = context.operands.length;
            ir_operand_block(context, header_block);
            ir_emit_void(
                context, ir_op_branch(), statement,
                0, 0, 0, header_first, 1
            );
            context.current_block = after_block;
        } else if kind == 17 {
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
                usize item = ir_switch_item(
                    context, statement, item_index
                );
                if item >= context.syntax.length { break; }
                usize body = ir_direct_block(
                    context, statement, item_index
                );
                usize item_kind = read_record_field(
                    context.syntax_data, item, 0
                );
                usize case_name = 13;
                if item_kind == 19 { case_name = 14; }
                usize case_block = ir_add_block(context, case_name);
                context.current_block = dispatch_block;
                if item_kind == 18 {
                    usize case_node = ir_switch_case_expression(
                        context, body
                    );
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
                    // The comparison text is the canonical equality operator.
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
                if body < context.syntax.length {
                    ir_lower_block(context, body);
                }
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
        } else if kind == 11 || kind == 24 {
            usize nested = statement;
            if kind == 24 {
                nested = flow_largest_direct_block(
                    context.syntax_data, context.syntax, statement
                );
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
