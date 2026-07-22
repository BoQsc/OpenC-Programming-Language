import system.file;
import system.memory;
import system.text;

unsafe bool acceptance_symbol_local(
    ref IrContext context,
    usize symbol,
    usize function_symbol
) {
    if symbol >= context.symbols.length { return false; }
    return read_record_field(context.symbol_data, symbol, 0) ==
            resolution_symbol_variable() &&
        read_record_field(context.detail_data, symbol, 2) ==
            function_symbol + 1;
}

unsafe bool acceptance_function_has_guard(
    ref IrContext context,
    usize function_node
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 14 &&
            semantic_node_contains(context.syntax_data, function_node, node) {
            return true;
        }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_function_calls_unsafe(
    ref IrContext context,
    usize function_node
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 38 &&
            semantic_node_contains(context.syntax_data, function_node, node) {
            usize target = ir_select_call(context, node);
            if target < context.symbols.length {
                usize declaration = read_record_field(
                    context.detail_data, target, 1
                );
                usize source_record = read_record_field(
                    context.symbol_data, target, 1
                );
                if source_record != context.source_record {
                    node = node + 1;
                    continue;
                }
                text source;
                status loaded = project_read_source_record(
                    context.project_source, context.project_root,
                    context.source_data, source_record, out source
                );
                if !loaded.ok {
                    node = node + 1;
                    continue;
                }
                if semantic_prefix_has(
                        source, context.token_data, context.tokens,
                        read_record_field(context.syntax_data, declaration, 1),
                        read_record_field(context.syntax_data, declaration, 3),
                        "unsafe"
                    ) { return true; }
            }
        }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_out_assigned(
    ref IrContext context,
    usize function_node,
    usize parameter_symbol,
    usize before
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 37 &&
            read_record_field(context.syntax_data, node, 1) < before &&
            semantic_node_contains(context.syntax_data, function_node, node) {
            usize left = resolution_left_expression(
                context.syntax_data, node,
                read_record_field(context.syntax_data, node, 3)
            );
            if left < context.syntax.length &&
                ir_resolve_name(context, left) == parameter_symbol {
                return true;
            }
        }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_status_failure(
    ref IrContext context,
    usize initializer
) {
    usize field = 0;
    while field < context.syntax.length {
        if ir_initializer_direct_field(context, initializer, field) &&
            span_equals_ascii(
                context.source,
                read_record_field(context.syntax_data, field, 3),
                read_record_field(context.syntax_data, field, 4), "code"
            ) {
            usize value = ir_initializer_field_value(
                context, initializer, field
            );
            ResolutionInteger code = acceptance_integer_value(context, value);
            return code.valid && code.value != 0;
        }
        field = field + 1;
    }
    return false;
}
