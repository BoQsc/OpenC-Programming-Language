import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_validate_assignments(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 37 {
            usize operator_start = read_record_field(context.syntax_data, node, 3);
            usize left = resolution_left_expression(
                context.syntax_data, node, operator_start
            );
            usize right = resolution_right_expression(
                context.syntax_data, node,
                operator_start + read_record_field(context.syntax_data, node, 4)
            );
            if !acceptance_lvalue(context, left) { errors = errors + 1; }
            if !acceptance_mutable(context, left) { errors = errors + 1; }
            usize expected = ir_node_type(
                context, left, semantic_type_error()
            );
            if acceptance_kind(context, expected) == 12 {
                expected = read_record_field(context.type_data, expected, 1);
            }
            usize actual = ir_node_type(
                context, right, semantic_type_error()
            );
            if !acceptance_can_initialize(
                context, right, actual, expected
            ) { errors = errors + 1; }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_binary(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 36 {
            usize operator_start = read_record_field(context.syntax_data, node, 3);
            usize left = resolution_left_expression(
                context.syntax_data, node, operator_start
            );
            usize right = resolution_right_expression(
                context.syntax_data, node,
                operator_start + read_record_field(context.syntax_data, node, 4)
            );
            usize left_type = ir_node_type(
                context, left, semantic_type_error()
            );
            usize right_type = ir_node_type(
                context, right, semantic_type_error()
            );
            bool logical = flow_node_operator(
                context.source, context.syntax_data, node, "&&"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "||"
            );
            bool equality = flow_node_operator(
                context.source, context.syntax_data, node, "=="
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "!="
            );
            bool comparison = equality || flow_node_operator(
                context.source, context.syntax_data, node, "<"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "<="
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">="
            );
            if logical {
                if left_type != semantic_type_bool() ||
                    right_type != semantic_type_bool() {
                    errors = errors + 1;
                }
            } else if comparison {
                bool null_pointer = (read_record_field(
                    context.syntax_data, left, 0
                ) == 33 && acceptance_kind(context, right_type) == 13) ||
                    (read_record_field(context.syntax_data, right, 0) == 33 &&
                     acceptance_kind(context, left_type) == 13);
                bool compatible = acceptance_lossless(
                    context, left_type, right_type
                ) || acceptance_lossless(context, right_type, left_type) ||
                    acceptance_literal_fits(context, left, right_type) ||
                    acceptance_literal_fits(context, right, left_type) ||
                    null_pointer;
                if !compatible { errors = errors + 1; }
                if equality && (acceptance_resource(context, left_type) ||
                    acceptance_resource(context, right_type)) {
                    errors = errors + 1;
                }
            } else if acceptance_kind(context, left_type) != 13 &&
                acceptance_kind(context, right_type) != 13 {
                if !acceptance_numeric(context, left_type) ||
                    !acceptance_numeric(context, right_type) {
                    errors = errors + 1;
                } else if !acceptance_lossless(
                    context, left_type, right_type
                ) && !acceptance_lossless(
                    context, right_type, left_type
                ) && !acceptance_literal_fits(
                    context, left, right_type
                ) && !acceptance_literal_fits(
                    context, right, left_type
                ) { errors = errors + 1; }
            }
            bool bitwise = flow_node_operator(
                context.source, context.syntax_data, node, "&"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "|"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "^"
            );
            if bitwise && acceptance_kind(context, left_type) == 2 {
                errors = errors + 1;
            }
            bool shift = flow_node_operator(
                context.source, context.syntax_data, node, "<<"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">>"
            );
            if shift {
                ResolutionInteger amount = acceptance_integer_value(
                    context, right
                );
                if amount.valid && (amount.value < 0 ||
                    amount.value >= cast(i64, acceptance_bits(
                        context, left_type
                    ))) { errors = errors + 1; }
            }
            if flow_node_operator(
                context.source, context.syntax_data, node, "/"
            ) {
                ResolutionInteger left_value = acceptance_integer_value(
                    context, left
                );
                ResolutionInteger right_value = acceptance_integer_value(
                    context, right
                );
                if left_value.valid && right_value.valid &&
                    left_value.value == cast(i64, -2147483647) - 1 &&
                    right_value.value == -1 {
                    errors = errors + 1;
                }
            }
        }
        node = node + 1;
    }
    return errors;
}
