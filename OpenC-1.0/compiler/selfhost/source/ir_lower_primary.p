import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_primary(
    ref IrContext context,
    usize node,
    usize expected,
    usize kind,
    usize start,
    usize length,
    usize type_id
) {
    if kind == 29 {
        return ir_emit_value(
            context, ir_op_const_integer(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 30 {
        return ir_emit_value(
            context, ir_op_const_float(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 31 {
        return ir_emit_value(
            context, ir_op_const_text(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 32 {
        return ir_emit_value(
            context, ir_op_const_bool(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 33 {
        return ir_emit_value(
            context, ir_op_nop(), type_id, node,
            2, 1, 0, context.operands.length, 0
        );
    }
    if kind == 34 {
        return ir_emit_value(
            context, ir_op_optional_none(), type_id, node,
            0, 0, 0, context.operands.length, 0
        );
    }
    if kind == 27 {
        usize symbol = ir_resolve_name(context, node);
        if symbol < context.symbols.length {
            usize local_value = read_usize(
                context.local_values, symbol * size_of(usize)
            );
            if local_value != 0 {
                usize first = context.operands.length;
                ir_operand_empty(context, local_value);
                return ir_emit_value(
                    context, ir_op_load(), type_id, node,
                    0, 0, 0, first, 1
                );
            }
            if read_record_field(context.symbol_data, symbol, 0) ==
                    resolution_symbol_enum_item() {
                return ir_emit_value(
                    context, ir_op_const_integer(), type_id, node,
                    4, ir_enum_value(context, symbol), 0,
                    context.operands.length, 0
                );
            }
        }
        if flow_span_has_byte(context.source, start, length, 46) {
            IrMemberBase member_base_value = ir_find_local_base(context, node);
            if member_base_value.symbol < context.symbols.length {
                usize first = context.operands.length;
                ir_operand_empty(context, read_usize(
                    context.local_values,
                    member_base_value.symbol * size_of(usize)
                ));
                return ir_emit_value(
                    context, ir_op_aggregate_field(), type_id, node,
                    1, member_base_value.start,
                    member_base_value.length, first, 1
                );
            }
        }
        return ir_emit_value(
            context, ir_op_nop(), type_id, node,
            1, start, length, context.operands.length, 0
        );
    }
    if kind == 35 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize operator_length = read_record_field(context.syntax_data, node, 4);
        usize child = resolution_right_expression(
            context.syntax_data, node, operator_start + operator_length
        );
        if flow_node_operator(context.source, context.syntax_data, node, "-") &&
            child < context.syntax.length && read_record_field(
                context.syntax_data, child, 0
            ) == 29 {
            return ir_emit_value(
                context, ir_op_const_integer(), type_id, node,
                6, read_record_field(context.syntax_data, child, 1),
                read_record_field(context.syntax_data, child, 2),
                context.operands.length, 0
            );
        }
        if flow_node_operator(context.source, context.syntax_data, node, "&") {
            return ir_lower_node(context, child, expected, 2);
        }
        usize value = ir_lower_node(
            context, child, semantic_type_error(), 0
        );
        if flow_node_operator(
            context.source, context.syntax_data, node, "*"
        ) && ir_pointer_deref_fault(context, child) {
            ir_emit_void(
                context, ir_op_target_fault(), node,
                2, 12, 0, context.operands.length, 0
            );
            return ir_emit_value(
                context, ir_op_nop(), type_id, node,
                2, 10, 0, context.operands.length, 0
            );
        }
        usize first = context.operands.length;
        ir_operand_empty(context, value);
        return ir_emit_value(
            context, ir_op_unary(), type_id, node,
            1, operator_start, operator_length, first, 1
        );
    }
    return 0;
}
