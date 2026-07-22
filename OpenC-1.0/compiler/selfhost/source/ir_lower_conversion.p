import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_conversion(
    ref IrContext context,
    usize node,
    usize expected,
    usize kind,
    usize start,
    usize length,
    usize type_id
) {
    if kind == 42 || kind == 43 {
        usize type_node = ir_type_ref_within(context, node);
        usize after = start;
        if type_node < context.syntax.length {
            after = read_record_field(context.syntax_data, type_node, 1) +
                read_record_field(context.syntax_data, type_node, 2);
        }
        usize child = ir_expression_child_after(context, node, after, true);
        usize value = ir_lower_node(
            context, child, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, value);
        usize opcode = ir_op_cast();
        if kind == 43 { opcode = ir_op_reinterpret(); }
        return ir_emit_value(
            context, opcode, type_id, node,
            1, start, ir_keyword_length(context, node), first, 1
        );
    }
    if kind == 44 {
        usize storage_node = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize value_node = ir_expression_child_after(
            context, node,
            read_record_field(context.syntax_data, storage_node, 1) +
            read_record_field(context.syntax_data, storage_node, 2), true
        );
        usize storage_type = ir_node_type(
            context, storage_node, semantic_type_error()
        );
        usize value_expected = semantic_type_error();
        if storage_type < context.types.length {
            value_expected = ir_type_element(context, storage_type);
        }
        usize address = ir_lower_node(
            context, storage_node, semantic_type_error(), 1
        );
        usize value = ir_lower_node(
            context, value_node, value_expected, 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, address);
        ir_operand_empty(context, value);
        return ir_emit_value(
            context, ir_op_object_construct(), type_id, node,
            1, start, ir_keyword_length(context, node), first, 2
        );
    }
    if kind == 45 {
        usize owner_node = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize owner = ir_lower_node(
            context, owner_node, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, owner);
        ir_emit_void(
            context, ir_op_object_destroy(), node, 0, 0, 0, first, 1
        );
        return 0;
    }
    if kind == 46 {
        usize queried_type = ir_resolve_type_node(
            context, ir_type_ref_within(context, node)
        );
        usize queried_value = acceptance_type_size(context, queried_type);
        if starts_with_ascii(context.source, start, "align_of") &&
            queried_value > cast(usize, 8) {
            queried_value = 8;
        }
        return ir_emit_value(
            context, ir_op_const_integer(), type_id, node,
            4, queried_value, 0, context.operands.length, 0
        );
    }
    if kind == 47 {
        ptr byte status_values = memory.alloc(
            (context.syntax.length + 1) * record_stride()
        );
        usize status_count = 0;
        usize field = 0;
        while field < context.syntax.length {
            if ir_initializer_direct_field(context, node, field) {
                usize value_node = ir_initializer_field_value(
                    context, node, field
                );
                usize value = ir_lower_node(
                    context, value_node, semantic_type_error(), 0
                );
                write_record_field(status_values, status_count, 0, value);
                write_record_field(
                    status_values, status_count, 1,
                    read_record_field(context.syntax_data, field, 3)
                );
                write_record_field(
                    status_values, status_count, 2,
                    read_record_field(context.syntax_data, field, 4)
                );
                status_count = status_count + 1;
            }
            field = field + 1;
        }
        usize first = context.operands.length;
        field = 0;
        while field < status_count {
            ir_add_operand(
                context,
                read_record_field(status_values, field, 0), 2,
                read_record_field(status_values, field, 1),
                read_record_field(status_values, field, 2)
            );
            field = field + 1;
        }
        memory.free(status_values);
        return ir_emit_value(
            context, ir_op_status_create(), semantic_type_status(), node,
            2, 6, 0, first, context.operands.length - first
        );
    }
    return 0;
}
