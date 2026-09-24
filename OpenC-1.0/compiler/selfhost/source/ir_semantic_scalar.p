import system.file;
import system.memory;
import system.text;

struct IrSemanticScalar {
    usize type_id;
    usize value_id;
    bool valid;
}

unsafe IrSemanticScalar ir_semantic_scalar_invalid(ref IrContext context) {
    context.scalar_state.errors = context.scalar_state.errors + 1;
    return IrSemanticScalar{
        type_id = semantic_type_error(), value_id = 0, valid = false
    };
}

// Phase A admits a closed expression-statement grammar. It replaces the
// existing feature sweep, rather than adding a second source-sized arena.
// Anything with a local initializer, call, control condition, covered return
// expression, or non-scalar operator stays on the complete legacy path.
unsafe bool ir_semantic_scalar_eligible(ref IrContext context) {
    if !context.suppress_acceptance_diagnostics ||
        context.syntax.length > 2048 { return false; }
    usize assignments = 0;
    usize binaries = 0;
    usize index = 0;
    while index < context.expression_count {
        usize node = read_usize(
            context.expression_nodes, index * size_of(usize)
        );
        usize kind = read_record_field(context.syntax_data, node, 0);
        if kind == 36 {
            if !flow_node_operator(
                context.source, context.syntax_data, node, "+"
            ) { return false; }
            usize start = read_record_field(context.syntax_data, node, 3);
            usize left = ir_left_expression(context, node, start);
            usize right = ir_right_expression(context, node, start + 1);
            if left >= context.syntax.length || right >= context.syntax.length {
                return false;
            }
            usize left_kind = read_record_field(context.syntax_data, left, 0);
            usize right_kind = read_record_field(context.syntax_data, right, 0);
            if (left_kind != 27 && left_kind != 29 && left_kind != 36) ||
                (right_kind != 27 && right_kind != 29 && right_kind != 36) {
                return false;
            }
            binaries = binaries + 1;
        } else if kind == 37 {
            if !flow_node_operator(
                context.source, context.syntax_data, node, "="
            ) || read_record_field(context.syntax_data, node, 4) != 1 {
                return false;
            }
            usize start = read_record_field(context.syntax_data, node, 3);
            usize left = ir_left_expression(context, node, start);
            usize right = ir_right_expression(context, node, start + 1);
            if left >= context.syntax.length || right >= context.syntax.length ||
                read_record_field(context.syntax_data, left, 0) != 27 ||
                flow_span_has_byte(
                    context.source,
                    read_record_field(context.syntax_data, left, 1),
                    read_record_field(context.syntax_data, left, 2), 46
                ) { return false; }
            usize right_kind = read_record_field(context.syntax_data, right, 0);
            if right_kind != 27 && right_kind != 29 && right_kind != 36 {
                return false;
            }
            assignments = assignments + 1;
        } else if kind != 27 && kind != 29 {
            return false;
        }
        index = index + 1;
    }
    if assignments == 0 || binaries == 0 { return false; }
    usize rooted_assignments = 0;
    usize contained_binaries = 0;
    index = 0;
    while index < context.statement_count {
        usize statement = read_usize(
            context.statement_nodes, index * size_of(usize)
        );
        usize kind = read_record_field(context.syntax_data, statement, 0);
        if kind == 12 {
            if ir_local_initializer_root(context, statement) <
                context.syntax.length { return false; }
        } else if kind == 13 {
            usize root = ir_root_expression(context, statement);
            if root >= context.syntax.length || read_record_field(
                context.syntax_data, root, 0
            ) != 37 { return false; }
            rooted_assignments = rooted_assignments + 1;
            usize expression = 0;
            while expression < context.expression_count {
                usize child = read_usize(
                    context.expression_nodes,
                    expression * size_of(usize)
                );
                if read_record_field(context.syntax_data, child, 0) == 36 &&
                    semantic_node_contains(
                        context.syntax_data, root, child
                    ) { contained_binaries = contained_binaries + 1; }
                expression = expression + 1;
            }
        } else if kind == 22 {
            usize root = ir_root_expression(context, statement);
            if root < context.syntax.length {
                usize root_kind = read_record_field(
                    context.syntax_data, root, 0
                );
                if root_kind != 27 && root_kind != 29 { return false; }
            }
        } else if kind != 11 { return false; }
        index = index + 1;
    }
    if rooted_assignments != assignments ||
        contained_binaries != binaries { return false; }
    context.scalar_state.enabled = true;
    context.scalar_state.expected_assignments = assignments;
    context.scalar_state.expected_binaries = binaries;
    return true;
}

// Semantic type/rule resolution and SSA lowering share this single recursive
// visit. It is deliberately restricted to the Phase A i32 scalar grammar.
unsafe IrSemanticScalar ir_semantic_scalar_visit(
    ref IrContext context,
    usize node,
    usize expected
) {
    if node >= context.syntax.length {
        return ir_semantic_scalar_invalid(context);
    }
    usize kind = read_record_field(context.syntax_data, node, 0);
    usize i32_type = semantic_builtin_type("i32", 0, 3);
    if kind == 29 {
        ResolutionInteger literal = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, node, 1),
            read_record_field(context.syntax_data, node, 2)
        );
        if !literal.valid || literal.value < 0 ||
            literal.value > 2147483647 ||
            (expected != semantic_type_error() && expected != i32_type) {
            return ir_semantic_scalar_invalid(context);
        }
        usize value = ir_emit_value(
            context, ir_op_const_integer(), i32_type, node,
            4, cast(usize, literal.value), 0,
            context.operands.length, 0
        );
        return IrSemanticScalar{
            type_id = i32_type, value_id = value, valid = true
        };
    }
    if kind == 27 {
        usize symbol = ir_resolve_name(context, node);
        if symbol >= context.symbols.length || read_record_field(
            context.symbol_data, symbol, 4
        ) != i32_type ||
            (expected != semantic_type_error() && expected != i32_type) {
            return ir_semantic_scalar_invalid(context);
        }
        usize address = read_usize(
            context.local_values, symbol * size_of(usize)
        );
        if address == 0 { return ir_semantic_scalar_invalid(context); }
        usize first = context.operands.length;
        ir_operand_empty(context, address);
        usize value = ir_emit_value(
            context, ir_op_load(), i32_type, node,
            0, 0, 0, first, 1
        );
        return IrSemanticScalar{
            type_id = i32_type, value_id = value, valid = true
        };
    }
    if kind == 36 {
        context.scalar_state.visited_binaries =
            context.scalar_state.visited_binaries + 1;
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize left_node = ir_left_expression(context, node, operator_start);
        usize right_node = ir_right_expression(
            context, node, operator_start + 1
        );
        IrSemanticScalar left = ir_semantic_scalar_visit(
            context, left_node, i32_type
        );
        IrSemanticScalar right = ir_semantic_scalar_visit(
            context, right_node, i32_type
        );
        if !left.valid || !right.valid ||
            !flow_node_operator(
                context.source, context.syntax_data, node, "+"
            ) || (expected != semantic_type_error() &&
                expected != i32_type) {
            return ir_semantic_scalar_invalid(context);
        }
        usize first = context.operands.length;
        ir_operand_empty(context, left.value_id);
        ir_operand_empty(context, right.value_id);
        usize value = ir_emit_value(
            context, ir_op_binary(), i32_type, node,
            1, operator_start, 1, first, 2
        );
        return IrSemanticScalar{
            type_id = i32_type, value_id = value, valid = true
        };
    }
    if kind == 37 {
        context.scalar_state.visited_assignments =
            context.scalar_state.visited_assignments + 1;
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        if !flow_node_operator(
            context.source, context.syntax_data, node, "="
        ) || read_record_field(context.syntax_data, node, 4) != 1 {
            return ir_semantic_scalar_invalid(context);
        }
        usize left_node = ir_left_expression(context, node, operator_start);
        usize right_node = ir_right_expression(
            context, node, operator_start + 1
        );
        if left_node >= context.syntax.length ||
            read_record_field(context.syntax_data, left_node, 0) != 27 {
            return ir_semantic_scalar_invalid(context);
        }
        usize symbol = ir_resolve_name(context, left_node);
        if symbol >= context.symbols.length ||
            read_record_field(context.symbol_data, symbol, 4) != i32_type ||
            (read_record_field(context.symbol_data, symbol, 0) !=
                resolution_symbol_variable() &&
             read_record_field(context.symbol_data, symbol, 0) !=
                resolution_symbol_parameter()) ||
            acceptance_const_type(context, i32_type) ||
            acceptance_prefix_has(
                context,
                read_record_field(context.detail_data, symbol, 1), "const"
            ) { return ir_semantic_scalar_invalid(context); }
        IrSemanticScalar right = ir_semantic_scalar_visit(
            context, right_node, i32_type
        );
        if !right.valid || !acceptance_can_initialize(
            context, right_node, right.type_id, i32_type
        ) { return ir_semantic_scalar_invalid(context); }
        usize destination = read_usize(
            context.local_values, symbol * size_of(usize)
        );
        if destination == 0 { return ir_semantic_scalar_invalid(context); }
        usize first = context.operands.length;
        ir_add_operand(context, destination, 0, 0, 0);
        ir_operand_empty(context, right.value_id);
        ir_emit_void(context, ir_op_store(), node, 0, 0, 0, first, 2);
        return right;
    }
    return ir_semantic_scalar_invalid(context);
}
