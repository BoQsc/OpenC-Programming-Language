import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_mode(
    ref IrContext context,
    usize node,
    usize expected,
    usize mode,
    usize kind,
    usize start,
    usize length
) {
    // mode 1 lowers an assignable address; mode 2 lowers pointer-to context.
    if mode == 2 {
        usize actual_type = ir_node_type(context, node, semantic_type_error());
        if actual_type < context.types.length &&
            read_record_field(context.type_data, actual_type, 0) == 12 {
            return ir_lower_node(context, node, expected, 0);
        }
        bool direct_address = kind == 39 || kind == 40 ||
            (kind == 35 && flow_node_operator(
                context.source, context.syntax_data, node, "*"
            ));
        if kind == 27 && flow_span_has_byte(
            context.source, start, length, 46
        ) { direct_address = true; }
        if direct_address { return ir_lower_node(context, node, expected, 1); }
        if kind == 27 {
            usize local = ir_resolve_name(context, node);
            if local < context.symbols.length {
                usize local_type = read_record_field(
                    context.symbol_data, local, 4
                );
                usize local_kind = read_record_field(
                    context.type_data, local_type, 0
                );
                if local_kind == 12 || read_record_field(
                    context.detail_data, local, 3
                ) == 1 {
                    return read_usize(
                        context.local_values, local * size_of(usize)
                    );
                }
            }
        }
        usize address = ir_lower_node(context, node, expected, 1);
        usize element = actual_type;
        if element < context.types.length && read_record_field(
            context.type_data, element, 0
        ) == 12 { element = ir_type_element(context, element); }
        usize pointer_type = semantic_derived_type(
            context.type_data, context.types, 13, element, 0, false, false
        );
        usize first = context.operands.length;
        ir_operand_empty(context, address);
        return ir_emit_value(
            context, ir_op_address(), pointer_type, node,
            2, 2, 0, first, 1
        );
    }

    if mode == 1 {
        if kind == 35 && flow_node_operator(
            context.source, context.syntax_data, node, "*"
        ) {
            usize operator_start = read_record_field(
                context.syntax_data, node, 3
            );
            usize child = ir_right_expression(
                context, node,
                operator_start + read_record_field(
                    context.syntax_data, node, 4
                )
            );
            return ir_lower_node(
                context, child, semantic_type_error(), 0
            );
        }
        if kind == 40 {
            usize base = ir_left_expression(
                context, node,
                read_record_field(context.syntax_data, node, 3)
            );
            usize right = ir_root_in_bounds(
                context,
                read_record_field(context.syntax_data, node, 3) + 1,
                read_record_field(context.syntax_data, node, 1) +
                read_record_field(context.syntax_data, node, 2) - 1
            );
            usize aggregate = ir_lower_node(
                context, base, semantic_type_error(), 1
            );
            usize index = ir_lower_node(
                context, right, semantic_type_error(), 0
            );
            usize first = context.operands.length;
            ir_operand_empty(context, aggregate);
            ir_operand_empty(context, index);
            ir_emit_void(
                context, ir_op_bounds(), node, 0, 0, 0, first, 2
            );
            first = context.operands.length;
            ir_operand_empty(context, aggregate);
            ir_operand_empty(context, index);
            return ir_emit_value(
                context, ir_op_aggregate_field(),
                ir_node_type(context, node, expected), node,
                2, 4, 0, first, 2
            );
        }
        if kind == 39 {
            usize member_start = read_record_field(
                context.syntax_data, node, 3
            );
            usize base = ir_left_expression(
                context, node, member_start
            );
            usize aggregate = ir_lower_node(
                context, base, semantic_type_error(), 1
            );
            usize first = context.operands.length;
            ir_operand_empty(context, aggregate);
            return ir_emit_value(
                context, ir_op_aggregate_field(),
                ir_node_type(context, node, expected), node,
                5, member_start,
                read_record_field(context.syntax_data, node, 4), first, 1
            );
        }
        if kind == 27 && flow_span_has_byte(
            context.source, start, length, 46
        ) {
            IrMemberBase member_base = ir_find_local_base(context, node);
            if member_base.symbol < context.symbols.length {
                usize first = context.operands.length;
                ir_operand_empty(context, read_usize(
                    context.local_values,
                    member_base.symbol * size_of(usize)
                ));
                return ir_emit_value(
                    context, ir_op_aggregate_field(),
                    ir_node_type(context, node, expected), node,
                    5, member_base.start, member_base.length, first, 1
                );
            }
        }
        if kind == 27 {
            usize local = ir_resolve_name(context, node);
            if local < context.symbols.length {
                usize value = read_usize(
                    context.local_values, local * size_of(usize)
                );
                if value != 0 { return value; }
            }
        }
        return ir_lower_node(context, node, expected, 0);
    }
    return 0;
}
