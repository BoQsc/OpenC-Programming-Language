import system.file;
import system.memory;
import system.text;

unsafe bool acceptance_symbol_allocated(
    ref IrContext context,
    usize symbol
) {
    if symbol >= context.symbols.length || read_record_field(
        context.symbol_data, symbol, 0
    ) != resolution_symbol_variable() { return false; }
    usize initializer = flow_local_initializer_root(
        context.syntax_data, context.syntax,
        read_record_field(context.detail_data, symbol, 1)
    );
    return acceptance_call_named(context, initializer, "memory.alloc") ||
        acceptance_call_named(context, initializer, "system.memory.alloc");
}

unsafe bool acceptance_field_is_own(
    ref IrContext context,
    usize field
) {
    usize start = read_record_field(context.syntax_data, field, 1);
    if start < 4 { return false; }
    return starts_with_ascii(context.source, start - 4, "own ");
}

unsafe usize acceptance_validate_pointer_ownership(
    ref IrContext context
) {
    usize errors = 0;
    usize initializer = 0;
    while initializer < context.syntax.length {
        if read_record_field(context.syntax_data, initializer, 0) == 48 {
            usize field = 0;
            while field < context.syntax.length {
                if ir_initializer_direct_field(
                    context, initializer, field
                ) && !acceptance_field_is_own(context, field) {
                    usize value = ir_initializer_field_value(
                        context, initializer, field
                    );
                    if value < context.syntax.length {
                        usize name = flow_event_first_name(
                            context.syntax_data, context.syntax, value
                        );
                        if read_record_field(
                            context.syntax_data, value, 0
                        ) == 27 { name = value; }
                        if name < context.syntax.length &&
                            acceptance_symbol_allocated(
                                context, ir_resolve_name(context, name)
                            ) {
                            acceptance_report_node(
                                context, "pointer_ownership",
                                "allocated_field", initializer
                            );
                            errors = errors + 1;
                        }
                    }
                }
                field = field + 1;
            }
        }
        initializer = initializer + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_pointer_order(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 36 &&
            (flow_node_operator(
                context.source, context.syntax_data, node, "<"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "<="
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">="
            )) {
            usize operator_start = read_record_field(
                context.syntax_data, node, 3
            );
            usize left = resolution_left_expression(
                context.syntax_data, node, operator_start
            );
            usize right = resolution_right_expression(
                context.syntax_data, node,
                operator_start + read_record_field(
                    context.syntax_data, node, 4
                )
            );
            usize left_symbol = ir_resolve_name(context, left);
            usize right_symbol = ir_resolve_name(context, right);
            if left_symbol != right_symbol &&
                acceptance_symbol_allocated(context, left_symbol) &&
                acceptance_symbol_allocated(context, right_symbol) {
                errors = errors + 1;
            }
        }
        node = node + 1;
    }
    return errors;
}
