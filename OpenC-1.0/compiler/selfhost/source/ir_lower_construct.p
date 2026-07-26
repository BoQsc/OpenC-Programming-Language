import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_construct(
    ref IrContext context,
    usize node,
    usize expected,
    usize kind,
    usize start,
    usize length,
    usize type_id
) {
    if kind == 48 {
        ptr byte field_values = memory.alloc(
            (context.syntax.length + 1) * record_stride()
        );
        usize field_count = 0;
        usize aggregate_name = flow_event_first_name(
            context.syntax_data, context.syntax, node
        );
        usize aggregate_symbol = context.symbols.length;
        usize candidate = 0;
        while candidate < context.symbols.length {
            usize candidate_kind = read_record_field(
                context.symbol_data, candidate, 0
            );
            if (candidate_kind == resolution_symbol_struct() ||
                candidate_kind == resolution_symbol_resource()) &&
                read_record_field(
                    context.symbol_data, candidate, 4
                ) == type_id {
                aggregate_symbol = candidate;
                break;
            }
            candidate = candidate + 1;
        }
        usize field = 0;
        while field < context.syntax.length {
            if ir_initializer_direct_field(context, node, field) {
                usize value_node = ir_initializer_field_value(
                    context, node, field
                );
                usize field_expected = semantic_type_error();
                if aggregate_symbol < context.symbols.length {
                    usize field_symbol = ir_field_symbol(
                        context, aggregate_symbol,
                        read_record_field(context.syntax_data, field, 3),
                        read_record_field(context.syntax_data, field, 4)
                    );
                    if field_symbol < context.symbols.length {
                        field_expected = read_record_field(
                            context.symbol_data, field_symbol, 4
                        );
                    }
                }
                usize value = ir_lower_expected(
                    context, value_node, field_expected
                );
                write_record_field(field_values, field_count, 0, value);
                write_record_field(
                    field_values, field_count, 1,
                    read_record_field(context.syntax_data, field, 3)
                );
                write_record_field(
                    field_values, field_count, 2,
                    read_record_field(context.syntax_data, field, 4)
                );
                usize field_start = read_record_field(
                    context.syntax_data, field, 1
                );
                usize own_field = 0;
                if field_start >= 4 && starts_with_ascii(
                    context.source, field_start - 4, "own "
                ) { own_field = 1; }
                write_record_field(
                    field_values, field_count, 3, own_field
                );
                field_count = field_count + 1;
            }
            field = field + 1;
        }
        usize first = context.operands.length;
        field = 0;
        while field < field_count {
            usize immediate_kind = 2;
            if read_record_field(
                field_values, field, 3
            ) != 0 { immediate_kind = 5; }
            ir_add_operand(
                context, read_record_field(field_values, field, 0),
                immediate_kind,
                read_record_field(field_values, field, 1),
                read_record_field(field_values, field, 2)
            );
            field = field + 1;
        }
        memory.free(field_values);
        return ir_emit_value(
            context, ir_op_aggregate_create(), type_id, node,
            1,
            read_record_field(context.syntax_data, aggregate_name, 1),
            read_record_field(context.syntax_data, aggregate_name, 2),
            first, context.operands.length - first
        );
    }
    if kind == 50 {
        ptr byte element_values = memory.alloc(
            (context.syntax.length + 1) * size_of(usize)
        );
        usize element_count = 0;
        usize previous_start = 0;
        usize previous_record = 0;
        bool first_child = true;
        while true {
            usize child = context.syntax.length;
            usize child_start = cast(usize, 4294967295);
            usize record = 0;
            while record < context.syntax.length {
                usize child_kind = read_record_field(
                    context.syntax_data, record, 0
                );
                usize record_start = read_record_field(
                    context.syntax_data, record, 1
                );
                if resolution_expression_kind(child_kind) && record != node &&
                    semantic_node_contains(context.syntax_data, node, record) &&
                    resolution_smallest_parent(
                        context.syntax_data, context.syntax, record,
                        50, 999, 998
                    ) == node &&
                    (first_child || record_start > previous_start ||
                     (record_start == previous_start && record > previous_record)) &&
                    (child == context.syntax.length || record_start < child_start) {
                    child = record;
                    child_start = record_start;
                }
                record = record + 1;
            }
            if child >= context.syntax.length { break; }
            write_usize(
                element_values, element_count * size_of(usize),
                ir_lower_node(context, child, semantic_type_error(), 0)
            );
            element_count = element_count + 1;
            previous_start = child_start;
            previous_record = child;
            first_child = false;
        }
        usize first = context.operands.length;
        usize element_index = 0;
        while element_index < element_count {
            ir_operand_empty(context, read_usize(
                element_values, element_index * size_of(usize)
            ));
            element_index = element_index + 1;
        }
        memory.free(element_values);
        return ir_emit_value(
            context, ir_op_array_create(), type_id, node,
            0, 0, 0, first, element_count
        );
    }
    if kind == 51 {
        usize out_symbol = ir_resolve_name(context, node);
        if out_symbol < context.symbols.length {
            return read_usize(
                context.local_values, out_symbol * size_of(usize)
            );
        }
        return 0;
    }
    return 0;
}
