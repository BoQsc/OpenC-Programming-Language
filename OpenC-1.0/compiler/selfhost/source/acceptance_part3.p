import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_validate_assignments_range(
    ref IrContext context, usize target_node, bool one_node
) {
    usize errors = 0;
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.expression_nodes != null { node_count = context.expression_count; }
    if one_node { node_count = 1; }
    while node_index < node_count {
        usize node = node_index;
        if context.expression_nodes != null {
            node = read_usize(
                context.expression_nodes, node_index * size_of(usize)
            );
        }
        if one_node { node = target_node; }
        if read_record_field(context.syntax_data, node, 0) == 37 {
            usize operator_start = read_record_field(context.syntax_data, node, 3);
            usize left = ir_left_expression(
                context, node, operator_start
            );
            usize right = ir_right_expression(
                context, node,
                operator_start + read_record_field(context.syntax_data, node, 4)
            );
            usize expected = semantic_type_error();
            bool direct_name = left < context.syntax.length &&
                read_record_field(context.syntax_data, left, 0) == 27 &&
                !flow_span_has_byte(
                    context.source,
                    read_record_field(context.syntax_data, left, 1),
                    read_record_field(context.syntax_data, left, 2), 46
                );
            if direct_name {
                usize left_symbol = ir_resolve_name(context, left);
                if left_symbol >= context.symbols.length {
                    errors = errors + 1;
                } else {
                    usize symbol_kind = read_record_field(
                        context.symbol_data, left_symbol, 0
                    );
                    if symbol_kind != resolution_symbol_variable() &&
                        symbol_kind != resolution_symbol_parameter() &&
                        symbol_kind != resolution_symbol_field() {
                        errors = errors + 1;
                    }
                    expected = read_record_field(
                        context.symbol_data, left_symbol, 4
                    );
                    if acceptance_const_type(context, expected) ||
                        acceptance_prefix_has(
                            context,
                            read_record_field(
                                context.detail_data, left_symbol, 1
                            ), "const"
                        ) {
                        errors = errors + 1;
                    }
                }
            } else {
                if !acceptance_lvalue(context, left) {
                    errors = errors + 1;
                }
                if !acceptance_mutable(context, left) {
                    errors = errors + 1;
                }
                expected = ir_node_type(
                    context, left, semantic_type_error()
                );
            }
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
        node_index = node_index + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_assignments(ref IrContext context) {
    return acceptance_validate_assignments_range(context, 0, false);
}

unsafe usize acceptance_validate_assignment_node(
    ref IrContext context, usize node
) {
    return acceptance_validate_assignments_range(context, node, true);
}

unsafe usize acceptance_validate_binary_range(
    ref IrContext context, usize target_node, bool one_node
) {
    usize errors = 0;
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.expression_nodes != null { node_count = context.expression_count; }
    if one_node { node_count = 1; }
    while node_index < node_count {
        usize node = node_index;
        if context.expression_nodes != null {
            node = read_usize(
                context.expression_nodes, node_index * size_of(usize)
            );
        }
        if one_node { node = target_node; }
        if read_record_field(context.syntax_data, node, 0) == 36 {
            usize operator_start = read_record_field(context.syntax_data, node, 3);
            usize left = ir_left_expression(
                context, node, operator_start
            );
            usize right = ir_right_expression(
                context, node,
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
                    acceptance_report_node(
                        context, "binary", "logical_type", node
                    );
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
                if !compatible {
                    acceptance_report_node(
                        context, "binary", "comparison_type", node
                    );
                    errors = errors + 1;
                }
                if equality && (acceptance_resource(context, left_type) ||
                    acceptance_resource(context, right_type)) {
                    acceptance_report_node(
                        context, "binary", "resource_equality", node
                    );
                    errors = errors + 1;
                }
            } else if acceptance_kind(context, left_type) != 13 &&
                acceptance_kind(context, right_type) != 13 {
                if !acceptance_numeric(context, left_type) ||
                    !acceptance_numeric(context, right_type) {
                    acceptance_report_node(
                        context, "binary", "numeric_type", node
                    );
                    errors = errors + 1;
                } else if !acceptance_lossless(
                    context, left_type, right_type
                ) && !acceptance_lossless(
                    context, right_type, left_type
                ) && !acceptance_literal_fits(
                    context, left, right_type
                ) && !acceptance_literal_fits(
                    context, right, left_type
                ) {
                    acceptance_report_node(
                        context, "binary", "numeric_conversion", node
                    );
                    errors = errors + 1;
                }
            }
            bool bitwise = flow_node_operator(
                context.source, context.syntax_data, node, "&"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "|"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "^"
            );
            if bitwise && acceptance_kind(context, left_type) == 2 {
                acceptance_report_node(
                    context, "binary", "signed_bitwise", node
                );
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
                    ))) {
                    acceptance_report_node(
                        context, "binary", "shift_range", node
                    );
                    errors = errors + 1;
                }
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
                    acceptance_report_node(
                        context, "binary", "division_overflow", node
                    );
                    errors = errors + 1;
                }
            }
        }
        node_index = node_index + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_binary(ref IrContext context) {
    return acceptance_validate_binary_range(context, 0, false);
}

unsafe usize acceptance_validate_binary_node(
    ref IrContext context, usize node
) {
    return acceptance_validate_binary_range(context, node, true);
}
