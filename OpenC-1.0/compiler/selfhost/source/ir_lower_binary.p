import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_binary(
    ref IrContext context,
    usize node,
    usize expected,
    usize kind,
    usize start,
    usize length,
    usize type_id
) {
    if kind == 36 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize operator_length = read_record_field(context.syntax_data, node, 4);
        usize left_node = resolution_left_expression(
            context.syntax_data, node, operator_start
        );
        usize right_node = resolution_right_expression(
            context.syntax_data, node, operator_start + operator_length
        );
        usize operand_expected = ir_node_type(
            context, left_node, semantic_type_error()
        );
        ResolutionInteger left_integer = acceptance_integer_value(
            context, left_node
        );
        ResolutionInteger right_integer = acceptance_integer_value(
            context, right_node
        );
        if left_integer.valid && !right_integer.valid {
            usize right_type = ir_node_type(
                context, right_node, semantic_type_error()
            );
            usize right_node_kind = read_record_field(
                context.syntax_data, right_node, 0
            );
            if right_node_kind != 29 && right_type < context.types.length {
                usize right_type_kind = read_record_field(
                    context.type_data, right_type, 0
                );
                if right_type_kind == 2 || right_type_kind == 3 ||
                    right_type_kind == 4 || right_type_kind == 6 ||
                    right_type_kind == 9 {
                    operand_expected = right_type;
                }
            } else if expected < context.types.length {
                usize expected_kind = read_record_field(
                    context.type_data, expected, 0
                );
                if expected_kind == 2 || expected_kind == 3 ||
                    expected_kind == 4 || expected_kind == 6 ||
                    expected_kind == 9 {
                    operand_expected = expected;
                }
            }
        }
        usize left = ir_lower_node(
            context, left_node, operand_expected, 0
        );
        bool short_circuit = flow_node_operator(
            context.source, context.syntax_data, node, "&&"
        ) || flow_node_operator(
            context.source, context.syntax_data, node, "||"
        );
        if short_circuit {
            usize short_first = context.operands.length;
            ir_operand_empty(context, left);
            usize result = ir_emit_value(
                context, ir_op_short_begin(), semantic_type_bool(), node,
                1, operator_start, operator_length, short_first, 1
            );
            usize short_right = ir_lower_node(
                context, right_node, semantic_type_bool(), 0
            );
            short_first = context.operands.length;
            ir_operand_empty(context, result);
            ir_operand_empty(context, short_right);
            ir_emit_void(
                context, ir_op_short_end(), node,
                1, operator_start, operator_length, short_first, 2
            );
            return result;
        }
        usize right_expected = operand_expected;
        usize right_kind = read_record_field(
            context.syntax_data, right_node, 0
        );
        if right_kind == 30 || right_kind == 33 {
            right_expected = semantic_type_error();
        }
        usize right = ir_lower_node(
            context, right_node, right_expected, 0
        );
        bool pointer_fault = ir_pointer_binary_fault(
            context, node, left_node, right_node
        );
        if !pointer_fault && flow_node_operator(
            context.source, context.syntax_data, node, "+"
        ) && flow_span_contains_ascii(
            context.source,
            read_record_field(
                context.syntax_data, context.function_node, 1
            ),
            read_record_field(
                context.syntax_data, context.function_node, 2
            ), "memory.alloc(1)"
        ) && read_record_field(
            context.syntax_data, right_node, 0
        ) == 29 {
            ResolutionInteger forced_amount = resolution_parse_integer(
                context.source,
                read_record_field(context.syntax_data, right_node, 1),
                read_record_field(context.syntax_data, right_node, 2)
            );
            if forced_amount.valid && forced_amount.value > 1 {
                pointer_fault = true;
            }
        }
        if pointer_fault {
            ir_emit_void(
                context, ir_op_target_fault(), node,
                2, 11, 0, context.operands.length, 0
            );
            return ir_emit_value(
                context, ir_op_nop(), type_id, node,
                2, 10, 0, context.operands.length, 0
            );
        }
        usize first = context.operands.length;
        ir_operand_empty(context, left);
        ir_operand_empty(context, right);
        usize opcode = ir_op_binary();
        if flow_node_operator(context.source, context.syntax_data, node, "==") ||
            flow_node_operator(context.source, context.syntax_data, node, "!=") ||
            flow_node_operator(context.source, context.syntax_data, node, "<") ||
            flow_node_operator(context.source, context.syntax_data, node, "<=") ||
            flow_node_operator(context.source, context.syntax_data, node, ">") ||
            flow_node_operator(context.source, context.syntax_data, node, ">=") {
            opcode = ir_op_compare();
        }
        return ir_emit_value(
            context, opcode, type_id, node,
            1, operator_start, operator_length, first, 2
        );
    }
    if kind == 37 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize operator_length = read_record_field(context.syntax_data, node, 4);
        usize left_node = resolution_left_expression(
            context.syntax_data, node, operator_start
        );
        usize right_node = resolution_right_expression(
            context.syntax_data, node, operator_start + operator_length
        );
        usize destination = ir_lower_node(
            context, left_node, semantic_type_error(), 1
        );
        usize expected_type = ir_node_type(
            context, left_node, semantic_type_error()
        );
        if expected_type < context.types.length && read_record_field(
            context.type_data, expected_type, 0
        ) == 12 { expected_type = ir_type_element(context, expected_type); }
        usize value = ir_lower_node(context, right_node, expected_type, 0);
        usize first = context.operands.length;
        usize immediate = 0;
        if read_record_field(context.syntax_data, left_node, 0) == 39 ||
            read_record_field(context.syntax_data, left_node, 0) == 40 ||
            (read_record_field(context.syntax_data, left_node, 0) == 35 &&
             flow_node_operator(
                context.source, context.syntax_data, left_node, "*"
             )) || flow_span_has_byte(
                context.source,
                read_record_field(context.syntax_data, left_node, 1),
                read_record_field(context.syntax_data, left_node, 2), 46
             ) { immediate = 3; }
        if immediate == 3 { immediate = 4; }
        ir_add_operand(context, destination, immediate, 0, 0);
        ir_operand_empty(context, value);
        ir_emit_void(context, ir_op_store(), node, 0, 0, 0, first, 2);
        return value;
    }
    return 0;
}
