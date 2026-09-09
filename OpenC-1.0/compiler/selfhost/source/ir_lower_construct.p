import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_field_default_node(
    ref IrContext context,
    usize field_symbol
) {
    if read_record_field(context.symbol_data, field_symbol, 1) !=
        context.source_record {
        return context.syntax.length;
    }
    usize declaration = read_record_field(
        context.detail_data, field_symbol, 1
    );
    if declaration >= context.syntax.length {
        return context.syntax.length;
    }
    usize start = read_record_field(
        context.syntax_data, declaration, 1
    );
    usize end = start + read_record_field(
        context.syntax_data, declaration, 2
    );
    usize cursor = start;
    while cursor < end {
        if byte_at_or_zero(context.source, cursor) == 61 {
            return ir_root_in_bounds(
                context, cursor + 1, end
            );
        }
        cursor = cursor + 1;
    }
    return context.syntax.length;
}

unsafe bool ir_collected_field_supplied(
    ref IrContext context,
    ptr byte field_values,
    usize field_count,
    usize field_symbol
) {
    text field_source = context.source;
    usize field_source_record = read_record_field(
        context.symbol_data, field_symbol, 1
    );
    if field_source_record != context.source_record {
        text loaded_field_source;
        status loaded = project_read_source_record(
            context.project_source, context.project_root,
            context.source_data, field_source_record,
            out loaded_field_source
        );
        if !loaded.ok { return false; }
        field_source = loaded_field_source;
    }
    usize field = 0;
    while field < field_count {
        if semantic_spans_equal(
            context.source,
            read_record_field(field_values, field, 1),
            read_record_field(field_values, field, 2),
            field_source,
            read_record_field(context.symbol_data, field_symbol, 2),
            read_record_field(context.symbol_data, field_symbol, 3)
        ) { return true; }
        field = field + 1;
    }
    return false;
}

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
        usize aggregate_name = ir_first_name(context, node);
        usize aggregate_symbol = ir_aggregate_for_type(context, type_id);
        bool indexed_fields = context.initializer_field_first != null &&
            context.initializer_field_next != null;
        usize field = 0;
        if indexed_fields {
            field = ir_first_initializer_field(context, node);
        } else {
            context.profile_syntax_candidates =
                context.profile_syntax_candidates + context.syntax.length;
        }
        while field < context.syntax.length {
            if indexed_fields ||
                ir_initializer_direct_field(context, node, field) {
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
            if indexed_fields {
                field = ir_next_initializer_field(context, field);
            } else { field = field + 1; }
        }
        usize supplied_field_count = field_count;
        if aggregate_symbol < context.symbols.length {
            usize field_symbol = 0;
            if context.aggregate_field_first != null {
                field_symbol = ir_first_aggregate_field(
                    context, aggregate_symbol
                );
            }
            while field_symbol < context.symbols.length {
                context.profile_symbol_candidates =
                    context.profile_symbol_candidates + 1;
                if read_record_field(
                        context.symbol_data, field_symbol, 0
                    ) == resolution_symbol_field() &&
                    read_record_field(
                        context.detail_data, field_symbol, 2
                    ) == aggregate_symbol + 1 &&
                    !ir_collected_field_supplied(
                        context, field_values,
                        supplied_field_count, field_symbol
                    ) &&
                    acceptance_field_default(context, field_symbol) {
                    usize default_node = ir_field_default_node(
                        context, field_symbol
                    );
                    if default_node < context.syntax.length {
                        usize value = ir_lower_expected(
                            context, default_node,
                            read_record_field(
                                context.symbol_data, field_symbol, 4
                            )
                        );
                        write_record_field(
                            field_values, field_count, 0, value
                        );
                        write_record_field(
                            field_values, field_count, 1,
                            read_record_field(
                                context.symbol_data, field_symbol, 2
                            )
                        );
                        write_record_field(
                            field_values, field_count, 2,
                            read_record_field(
                                context.symbol_data, field_symbol, 3
                            )
                        );
                        write_record_field(
                            field_values, field_count, 3, 0
                        );
                        field_count = field_count + 1;
                    }
                }
                if context.aggregate_field_first != null {
                    field_symbol = ir_next_aggregate_field(
                        context, field_symbol
                    );
                } else {
                    field_symbol = field_symbol + 1;
                }
            }
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
        if context.array_element_first != null &&
            context.array_element_next != null {
            usize first = context.operands.length;
            usize child = ir_first_array_element(context, node);
            while child < context.syntax.length {
                ir_operand_empty(
                    context,
                    ir_lower_node(
                        context, child, semantic_type_error(), 0
                    )
                );
                child = ir_next_array_element(context, child);
            }
            return ir_emit_value(
                context, ir_op_array_create(), type_id, node,
                0, 0, 0, first, context.operands.length - first
            );
        }
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
            usize index = 0;
            usize candidate_count = context.syntax.length;
            if context.expression_nodes != null {
                candidate_count = context.expression_count;
            }
            context.profile_syntax_candidates =
                context.profile_syntax_candidates + candidate_count;
            while index < candidate_count {
                usize record = index;
                if context.expression_nodes != null {
                    record = read_usize(
                        context.expression_nodes, index * size_of(usize)
                    );
                }
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
                index = index + 1;
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
        usize array_operand_first = context.operands.length;
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
            0, 0, 0, array_operand_first, element_count
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
