import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_validate_function(
    ref IrContext context,
    usize function_node,
    usize function_symbol
) {
    usize errors = 0;
    context.function_node = function_node;
    context.function_symbol = function_symbol;
    ir_select_function_locals(context, function_symbol);
    usize result_type = read_record_field(
        context.symbol_data, function_symbol, 4
    );
    context.function_result = result_type;
    usize body = flow_largest_direct_block(
        context.syntax_data, context.syntax, function_node
    );
    if body >= context.syntax.length || byte_at_or_zero(
        context.source, read_record_field(context.syntax_data, body, 1)
    ) != 123 { return 0; }
    if result_type != semantic_type_void() &&
        !acceptance_definitely_returns(context, function_node, body) {
        errors = errors + 1;
    }
    bool function_unsafe = acceptance_prefix_has(
        context, function_node, "unsafe"
    );
    if !function_unsafe && !acceptance_function_has_guard(
        context, function_node
    ) && acceptance_function_calls_unsafe(context, function_node) {
        errors = errors + 1;
    }
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 && acceptance_prefix_has(
                    context,
                    read_record_field(context.detail_data, symbol, 1), "own"
                ) {
            usize type_id = read_record_field(
                context.symbol_data, symbol, 4
            );
            if !acceptance_resource(context, type_id) &&
                acceptance_kind(context, type_id) != 13 {
                errors = errors + 1;
            }
        }
        symbol = symbol + 1;
    }
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 22 &&
            semantic_node_contains(context.syntax_data, function_node, node) {
            usize value = flow_root_expression(
                context.syntax_data, context.syntax, node
            );
            if value < context.syntax.length {
                usize actual = ir_node_type(
                    context, value, semantic_type_error()
                );
                if result_type == semantic_type_void() ||
                    !acceptance_can_initialize(
                        context, value, actual, result_type
                    ) { errors = errors + 1; }
                usize value_name = flow_event_first_name(
                    context.syntax_data, context.syntax, value
                );
                if read_record_field(context.syntax_data, value, 0) == 27 {
                    value_name = value;
                }
                if acceptance_kind(context, result_type) == 12 &&
                    value_name < context.syntax.length &&
                    acceptance_symbol_local(
                        context, ir_resolve_name(context, value_name),
                        function_symbol
                    ) { errors = errors + 1; }
                if acceptance_kind(context, result_type) == 11 {
                    usize root = value_name;
                    if read_record_field(context.syntax_data, value, 0) == 41 {
                        root = resolution_left_expression(
                            context.syntax_data, value,
                            read_record_field(context.syntax_data, value, 3)
                        );
                    }
                    if root < context.syntax.length && acceptance_symbol_local(
                        context, ir_resolve_name(context, root), function_symbol
                    ) { errors = errors + 1; }
                }
                if read_record_field(context.syntax_data, value, 0) == 47 &&
                    acceptance_status_failure(context, value) {
                    symbol = 0;
                    while symbol < context.symbols.length {
                        if read_record_field(context.symbol_data, symbol, 0) ==
                                resolution_symbol_parameter() &&
                            read_record_field(context.detail_data, symbol, 2) ==
                                function_symbol + 1 && read_record_field(
                                    context.detail_data, symbol, 3
                                ) == 1 && acceptance_out_assigned(
                                    context, function_node, symbol,
                                    read_record_field(context.syntax_data, node, 1)
                                ) { errors = errors + 1; }
                        symbol = symbol + 1;
                    }
                }
            } else if result_type != semantic_type_void() {
                errors = errors + 1;
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_functions(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 2 {
            usize owner = resolution_find_owner_symbol(
                context.symbol_data, context.detail_data, context.symbols,
                context.source_record, node,
                resolution_symbol_function(), 0
            );
            if owner != 0 {
                errors = errors + acceptance_validate_function(
                    context, node, owner - 1
                );
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_scopes(ref IrContext context) {
    usize errors = 0;
    usize left = 0;
    while left < context.symbols.length {
        if read_record_field(context.symbol_data, left, 0) ==
                resolution_symbol_variable() &&
            read_record_field(context.symbol_data, left, 1) ==
                context.source_record {
            usize right = left + 1;
            while right < context.symbols.length {
                if read_record_field(context.symbol_data, right, 0) ==
                        resolution_symbol_variable() &&
                    read_record_field(context.symbol_data, right, 1) ==
                        context.source_record &&
                    read_record_field(context.detail_data, left, 2) ==
                        read_record_field(context.detail_data, right, 2) &&
                    acceptance_symbol_named(context, left, right) {
                    usize left_declaration = read_record_field(
                        context.detail_data, left, 1
                    );
                    usize right_declaration = read_record_field(
                        context.detail_data, right, 1
                    );
                    usize left_block = flow_smallest_block_parent(
                        context.syntax_data, context.syntax, left_declaration
                    );
                    usize right_block = flow_smallest_block_parent(
                        context.syntax_data, context.syntax, right_declaration
                    );
                    if left_block == right_block {
                        errors = errors + 1;
                    } else if left_block < context.syntax.length &&
                        right_block < context.syntax.length &&
                        (semantic_node_contains(
                            context.syntax_data, left_block, right_block
                        ) || semantic_node_contains(
                            context.syntax_data, right_block, left_block
                        )) { errors = errors + 1; }
                }
                right = right + 1;
            }
        }
        left = left + 1;
    }

    usize for_node = 0;
    while for_node < context.syntax.length {
        if read_record_field(context.syntax_data, for_node, 0) == 16 {
            usize body = flow_largest_direct_block(
                context.syntax_data, context.syntax, for_node
            );
            usize symbol = 0;
            while symbol < context.symbols.length {
                if read_record_field(context.symbol_data, symbol, 0) ==
                        resolution_symbol_variable() &&
                    read_record_field(context.symbol_data, symbol, 1) ==
                        context.source_record {
                    usize declaration = read_record_field(
                        context.detail_data, symbol, 1
                    );
                    if semantic_node_contains(
                        context.syntax_data, for_node, declaration
                    ) && (body >= context.syntax.length ||
                        read_record_field(context.syntax_data, declaration, 1) <
                        read_record_field(context.syntax_data, body, 1)) {
                        usize use = 0;
                        while use < context.syntax.length {
                            if read_record_field(context.syntax_data, use, 0) == 27 &&
                                read_record_field(context.syntax_data, use, 1) >=
                                    read_record_field(context.syntax_data, for_node, 1) +
                                    read_record_field(context.syntax_data, for_node, 2) &&
                                ir_resolve_name(context, use) == symbol {
                                errors = errors + 1;
                            }
                            use = use + 1;
                        }
                    }
                }
                symbol = symbol + 1;
            }
        }
        for_node = for_node + 1;
    }
    return errors;
}
