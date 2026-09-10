import system.file;
import system.memory;
import system.text;

unsafe bool acceptance_field_supplied(
    ref IrContext context,
    usize initializer,
    usize field_symbol
) {
    text field_source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, field_symbol, 1),
        out field_source
    );
    if !loaded.ok { return false; }
    usize node = 0;
    while node < context.syntax.length {
        if ir_initializer_direct_field(context, initializer, node) &&
            semantic_spans_equal(
                context.source,
                read_record_field(context.syntax_data, node, 3),
                read_record_field(context.syntax_data, node, 4),
                field_source,
                read_record_field(context.symbol_data, field_symbol, 2),
                read_record_field(context.symbol_data, field_symbol, 3)
            ) { return true; }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_field_default(
    ref IrContext context,
    usize field_symbol
) {
    text source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, field_symbol, 1), out source
    );
    if !loaded.ok { return false; }
    usize declaration = read_record_field(
        context.detail_data, field_symbol, 1
    );
    if read_record_field(context.symbol_data, field_symbol, 1) !=
        context.source_record { return false; }
    return flow_span_has_byte(
        source,
        read_record_field(context.syntax_data, declaration, 1),
        read_record_field(context.syntax_data, declaration, 2), 61
    );
}

unsafe usize acceptance_validate_aggregates(ref IrContext context) {
    usize errors = 0;
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.expression_nodes != null { node_count = context.expression_count; }
    while node_index < node_count {
        usize node = node_index;
        if context.expression_nodes != null {
            node = read_usize(
                context.expression_nodes, node_index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, node, 0) == 48 {
            usize aggregate_type = ir_node_type(
                context, node, semantic_type_error()
            );
            usize aggregate = context.symbols.length;
                usize symbol = ir_aggregate_for_type(context, aggregate_type);
                if symbol < context.symbols.length &&
                    read_record_field(context.symbol_data, symbol, 0) !=
                        resolution_symbol_enum() {
                    aggregate = symbol;
                }
                if aggregate < context.symbols.length {
                    usize encoded = 0;
                    bool indexed = context.aggregate_field_first != null &&
                        context.field_next != null;
                    if indexed {
                        encoded = read_usize(
                            context.aggregate_field_first,
                            aggregate * size_of(usize)
                        );
                    }
                    symbol = 0;
                    while (indexed && encoded != 0) ||
                        (!indexed && symbol < context.symbols.length) {
                        usize field_symbol = symbol;
                        if indexed { field_symbol = encoded - 1; }
                        if read_record_field(
                                context.symbol_data, field_symbol, 0
                            ) == resolution_symbol_field() &&
                            read_record_field(
                                context.detail_data, field_symbol, 2
                            ) == aggregate + 1 &&
                            !acceptance_field_supplied(
                                context, node, field_symbol
                            ) && !acceptance_field_default(
                                context, field_symbol
                            ) {
                            errors = errors + 1;
                        }
                        if indexed {
                            encoded = read_usize(
                                context.field_next,
                                field_symbol * size_of(usize)
                            );
                        } else {
                            symbol = symbol + 1;
                        }
                    }
                }
            }
        node_index = node_index + 1;
    }
    return errors;
}

unsafe bool acceptance_direct_return(
    ref IrContext context,
    usize block
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 22 &&
            semantic_node_contains(context.syntax_data, block, node) &&
            flow_smallest_block_parent(
                context.syntax_data, context.syntax, node
            ) == block { return true; }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_definitely_returns(
    ref IrContext context,
    usize function_node,
    usize body
) {
    if acceptance_direct_return(context, body) { return true; }
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 14 &&
            semantic_node_contains(context.syntax_data, body, node) &&
            flow_smallest_block_parent(
                context.syntax_data, context.syntax, node
            ) == body {
            usize then_block = ir_direct_block(context, node, 0);
            usize else_block = ir_direct_block(context, node, 1);
            if then_block < context.syntax.length &&
                else_block < context.syntax.length &&
                acceptance_direct_return(context, then_block) &&
                acceptance_direct_return(context, else_block) {
                return true;
            }
        }
        if (read_record_field(context.syntax_data, node, 0) == 24 ||
            read_record_field(context.syntax_data, node, 0) == 25) &&
            semantic_node_contains(context.syntax_data, body, node) &&
            flow_smallest_block_parent(
                context.syntax_data, context.syntax, node
            ) == body {
            usize nested = flow_largest_direct_block(
                context.syntax_data, context.syntax, node
            );
            if nested < context.syntax.length &&
                acceptance_direct_return(context, nested) {
                return true;
            }
        }
        if read_record_field(context.syntax_data, node, 0) == 17 &&
            semantic_node_contains(context.syntax_data, body, node) &&
            flow_smallest_block_parent(
                context.syntax_data, context.syntax, node
            ) == body {
            usize subject = ir_switch_subject(context, node);
            usize subject_type = ir_node_type(
                context, subject, semantic_type_error()
            );
            usize enum_symbol = context.symbols.length;
            usize symbol = 0;
            while symbol < context.symbols.length {
                if read_record_field(context.symbol_data, symbol, 0) ==
                        resolution_symbol_enum() && read_record_field(
                            context.symbol_data, symbol, 4
                        ) == subject_type {
                    enum_symbol = symbol;
                    break;
                }
                symbol = symbol + 1;
            }
            usize expected_cases = 0;
            if enum_symbol < context.symbols.length {
                symbol = 0;
                while symbol < context.symbols.length {
                    if read_record_field(context.symbol_data, symbol, 0) ==
                            resolution_symbol_enum_item() &&
                        read_record_field(context.detail_data, symbol, 2) ==
                            enum_symbol + 1 {
                        expected_cases = expected_cases + 1;
                    }
                    symbol = symbol + 1;
                }
            }
            usize cases = 0;
            bool all_return = true;
            usize item_index = 0;
            usize item = ir_switch_item(context, node, item_index);
            while item < context.syntax.length {
                usize item_body = ir_direct_block(
                    context, node, item_index
                );
                if item_body >= context.syntax.length ||
                    !acceptance_direct_return(context, item_body) {
                    all_return = false;
                }
                if read_record_field(context.syntax_data, item, 0) == 18 {
                    cases = cases + 1;
                } else {
                    expected_cases = cases;
                }
                item_index = item_index + 1;
                item = ir_switch_item(context, node, item_index);
            }
            if all_return && expected_cases != 0 && cases == expected_cases {
                return true;
            }
        }
        node = node + 1;
    }
    return false;
}
