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
    if context.control_child_first != null &&
        context.control_child_next != null &&
        parent < context.syntax.length {
        usize encoded = read_usize(
            context.control_child_first,
            parent * size_of(usize)
        );
        while encoded != 0 {
            usize record = encoded - 1;
            if read_record_field(context.syntax_data, record, 0) == 14 &&
                read_record_field(context.syntax_data, record, 1) >=
                    after_then {
                return record;
            }
            encoded = read_usize(
                context.control_child_next,
                record * size_of(usize)
            );
        }
        return context.syntax.length;
    }
    usize index = 0;
    usize candidate_count = context.syntax.length;
    if context.control_nodes != null {
        candidate_count = context.control_count;
    }
    context.profile_parent_candidates =
        context.profile_parent_candidates + candidate_count;
    while index < candidate_count {
        usize record = index;
        if context.control_nodes != null {
            record = read_usize(
                context.control_nodes, index * size_of(usize)
            );
        }
        if record != parent && read_record_field(
                context.syntax_data, record, 0
            ) == 14 && semantic_node_contains(
                context.syntax_data, parent, record
            ) && ir_control_parent(
                context, record
            ) == parent && read_record_field(
                context.syntax_data, record, 1
            ) >= after_then {
            usize start = read_record_field(context.syntax_data, record, 1);
            if selected == context.syntax.length || start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        index = index + 1;
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

unsafe void ir_lower_scope_statement(
    ref IrContext context,
    usize statement
) {
    usize action = ir_root_expression(context, statement);
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
            if ir_builtin_call(context.source, text_one, text_two) {
                text_kind = 7;
            }
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
        usize owner_node = ir_first_name(context, action);
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
        text_kind, text_one, text_two, operand_first, scope_count
    );
}
