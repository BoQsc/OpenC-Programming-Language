import system.file;
import system.memory;
import system.text;

struct IrSemanticScalar {
    usize type_id;
    usize value_id;
    bool valid;
}

struct IrScalarCensus {
    usize assignments;
    usize binaries;
}

unsafe IrSemanticScalar ir_semantic_scalar_invalid(ref IrContext context) {
    context.scalar_state.errors = context.scalar_state.errors + 1;
    return IrSemanticScalar{
        type_id = semantic_type_error(), value_id = 0, valid = false
    };
}

unsafe bool ir_semantic_scalar_reject(
    ref IrContext context,
    usize reason
) {
    context.scalar_state.preflight_reason = reason;
    return false;
}

// Mark covered expression ownership in the already allocated call cache.
// Only kinds 36/37 are marked; call selection owns kind-38 cache slots.
// Each covered node must be reached from exactly one statement root, and
// recursion is capped by function-local expression depth, not source size.
unsafe bool ir_semantic_scalar_census(
    ref IrContext context,
    usize node,
    usize depth,
    ref IrScalarCensus counts
) {
    if node >= context.syntax.length || depth > 64 { return false; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 27 || kind == 29 { return true; }
    if kind != 36 && kind != 37 { return false; }
    usize mark = node * size_of(usize);
    if read_usize(context.call_cache, mark) != 0 { return false; }
    write_usize(context.call_cache, mark, 1);
    usize operator_start = read_record_field(context.syntax_data, node, 3);
    usize operator_length = read_record_field(context.syntax_data, node, 4);
    if operator_length != 1 { return false; }
    usize left = ir_left_expression(context, node, operator_start);
    usize right = ir_right_expression(
        context, node, operator_start + operator_length
    );
    if left >= context.syntax.length || right >= context.syntax.length {
        return false;
    }
    if kind == 37 {
        if !flow_node_operator(context.source, context.syntax_data, node, "=") ||
            read_record_field(context.syntax_data, left, 0) != 27 ||
            flow_span_has_byte(
                context.source,
                read_record_field(context.syntax_data, left, 1),
                read_record_field(context.syntax_data, left, 2), 46
            ) { return false; }
        counts.assignments = counts.assignments + 1;
        return ir_semantic_scalar_census(
            context, right, depth + 1, counts
        );
    }
    if !flow_node_operator(context.source, context.syntax_data, node, "+") &&
        !flow_node_operator(context.source, context.syntax_data, node, "-") &&
        !flow_node_operator(context.source, context.syntax_data, node, "*") {
        return false;
    }
    counts.binaries = counts.binaries + 1;
    return ir_semantic_scalar_census(
        context, left, depth + 1, counts
    ) && ir_semantic_scalar_census(
        context, right, depth + 1, counts
    );
}

// A linear expression census plus disjoint root traversals replaces the
// former statement x expression containment loop. No source-sized arena is
// created, and unsupported families fall back before any lowering.
unsafe bool ir_semantic_scalar_eligible(ref IrContext context) {
    if !context.suppress_acceptance_diagnostics ||
        context.call_cache == null {
        return ir_semantic_scalar_reject(context, 1);
    }
    usize assignments = 0;
    usize binaries = 0;
    usize index = 0;
    while index < context.expression_count {
        usize node = read_usize(
            context.expression_nodes, index * size_of(usize)
        );
        usize kind = read_record_field(context.syntax_data, node, 0);
        if kind == 36 {
            binaries = binaries + 1;
        } else if kind == 37 {
            assignments = assignments + 1;
        } else if kind != 27 && kind != 29 {
            return ir_semantic_scalar_reject(context, 2);
        }
        index = index + 1;
    }
    if assignments == 0 || binaries == 0 {
        return ir_semantic_scalar_reject(context, 3);
    }
    IrScalarCensus rooted = IrScalarCensus{
        assignments = 0, binaries = 0
    };
    index = 0;
    while index < context.statement_count {
        usize statement = read_usize(
            context.statement_nodes, index * size_of(usize)
        );
        usize kind = read_record_field(context.syntax_data, statement, 0);
        if kind == 12 {
            if ir_local_initializer_root(context, statement) <
                context.syntax.length {
                return ir_semantic_scalar_reject(context, 5);
            }
        } else if kind == 13 {
            usize root = ir_root_expression(context, statement);
            if root >= context.syntax.length || read_record_field(
                context.syntax_data, root, 0
            ) != 37 { return ir_semantic_scalar_reject(context, 4); }
            if !ir_semantic_scalar_census(
                context, root, 0, rooted
            ) { return ir_semantic_scalar_reject(context, 4); }
        } else if kind == 22 {
            usize root = ir_root_expression(context, statement);
            if root < context.syntax.length {
                usize root_kind = read_record_field(
                    context.syntax_data, root, 0
                );
                if root_kind != 27 && root_kind != 29 {
                    return ir_semantic_scalar_reject(context, 6);
                }
            }
        } else if kind != 11 {
            return ir_semantic_scalar_reject(context, 6);
        }
        index = index + 1;
    }
    if rooted.assignments != assignments ||
        rooted.binaries != binaries {
        return ir_semantic_scalar_reject(context, 4);
    }
    context.scalar_state.enabled = true;
    context.scalar_state.expected_assignments = assignments;
    context.scalar_state.expected_binaries = binaries;
    return true;
}

// Semantic type/rule resolution and SSA lowering share this single recursive
// visit. The current closed grammar covers signed i32/i64 arithmetic.
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
    usize i64_type = semantic_builtin_type("i64", 0, 3);
    if kind == 29 {
        ResolutionInteger literal = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, node, 1),
            read_record_field(context.syntax_data, node, 2)
        );
        if !literal.valid || literal.value < 0 ||
            (expected != i32_type && expected != i64_type) ||
            (expected == i32_type && literal.value > 2147483647) {
            return ir_semantic_scalar_invalid(context);
        }
        usize value = ir_emit_value(
            context, ir_op_const_integer(), expected, node,
            4, cast(usize, literal.value), 0,
            context.operands.length, 0
        );
        return IrSemanticScalar{
            type_id = expected, value_id = value, valid = true
        };
    }
    if kind == 27 {
        usize symbol = ir_resolve_name(context, node);
        if symbol >= context.symbols.length {
            return ir_semantic_scalar_invalid(context);
        }
        usize name_type = read_record_field(context.symbol_data, symbol, 4);
        usize symbol_kind = read_record_field(context.symbol_data, symbol, 0);
        if (name_type != i32_type && name_type != i64_type) ||
            (expected != semantic_type_error() && expected != name_type) ||
            (symbol_kind != resolution_symbol_variable() &&
             symbol_kind != resolution_symbol_parameter()) {
            return ir_semantic_scalar_invalid(context);
        }
        usize address = read_usize(
            context.local_values, symbol * size_of(usize)
        );
        if address == 0 { return ir_semantic_scalar_invalid(context); }
        usize first = context.operands.length;
        ir_operand_empty(context, address);
        usize value = ir_emit_value(
            context, ir_op_load(), name_type, node,
            0, 0, 0, first, 1
        );
        return IrSemanticScalar{
            type_id = name_type, value_id = value, valid = true
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
            context, left_node, expected
        );
        // Mirror the existing checked-multiply identity lowering: validate
        // the literal but do not create a constant or multiply SSA value.
        if left.valid && flow_node_operator(
            context.source, context.syntax_data, node, "*"
        ) && right_node < context.syntax.length &&
            read_record_field(context.syntax_data, right_node, 0) == 29 {
            ResolutionInteger identity = resolution_parse_integer(
                context.source,
                read_record_field(context.syntax_data, right_node, 1),
                read_record_field(context.syntax_data, right_node, 2)
            );
            if identity.valid && identity.value == 1 &&
                (expected == i32_type || expected == i64_type) {
                return left;
            }
        }
        IrSemanticScalar right = ir_semantic_scalar_visit(
            context, right_node, expected
        );
        if !left.valid || !right.valid ||
            (expected != i32_type && expected != i64_type) ||
            (!flow_node_operator(
                context.source, context.syntax_data, node, "+"
            ) && !flow_node_operator(
                context.source, context.syntax_data, node, "-"
            ) && !flow_node_operator(
                context.source, context.syntax_data, node, "*"
            )) {
            return ir_semantic_scalar_invalid(context);
        }
        usize first = context.operands.length;
        ir_operand_empty(context, left.value_id);
        ir_operand_empty(context, right.value_id);
        usize value = ir_emit_value(
            context, ir_op_binary(), expected, node,
            1, operator_start, 1, first, 2
        );
        return IrSemanticScalar{
            type_id = expected, value_id = value, valid = true
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
        if symbol >= context.symbols.length {
            return ir_semantic_scalar_invalid(context);
        }
        usize target_type = read_record_field(context.symbol_data, symbol, 4);
        if (target_type != i32_type && target_type != i64_type) ||
            (expected != semantic_type_error() && expected != target_type) ||
            (read_record_field(context.symbol_data, symbol, 0) !=
                resolution_symbol_variable() &&
             read_record_field(context.symbol_data, symbol, 0) !=
                resolution_symbol_parameter()) ||
            acceptance_const_type(context, target_type) ||
            acceptance_prefix_has(
                context,
                read_record_field(context.detail_data, symbol, 1), "const"
            ) { return ir_semantic_scalar_invalid(context); }
        IrSemanticScalar right = ir_semantic_scalar_visit(
            context, right_node, target_type
        );
        if !right.valid || !acceptance_can_initialize(
            context, right_node, right.type_id, target_type
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
