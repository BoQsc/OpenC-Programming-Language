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
        acceptance_report_node(
            context, "functions", "missing_return", function_node
        );
        errors = errors + 1;
    }
    bool function_unsafe = acceptance_prefix_has(
        context, function_node, "unsafe"
    );
    if !function_unsafe && !acceptance_function_has_guard(
        context, function_node
    ) && acceptance_function_calls_unsafe(context, function_node) {
        acceptance_report_node(
            context, "functions", "unsafe_call", function_node
        );
        errors = errors + 1;
    }
    usize parameter_index = 0;
    usize parameter_count = acceptance_parameter_count(
        context, function_symbol
    );
    while parameter_index < parameter_count {
        usize parameter_symbol = acceptance_parameter_at(
            context, function_symbol, parameter_index
        );
        if parameter_symbol < context.symbols.length &&
            acceptance_prefix_has(
                context,
                read_record_field(
                    context.detail_data, parameter_symbol, 1
                ), "own"
            ) {
            usize type_id = read_record_field(
                context.symbol_data, parameter_symbol, 4
            );
            if !acceptance_resource(context, type_id) &&
                acceptance_kind(context, type_id) != 13 {
                acceptance_report_node(
                    context, "functions", "invalid_own", function_node
                );
                errors = errors + 1;
            }
        }
        parameter_index = parameter_index + 1;
    }
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.statement_nodes != null { node_count = context.statement_count; }
    while node_index < node_count {
        usize node = node_index;
        if context.statement_nodes != null {
            node = read_usize(
                context.statement_nodes, node_index * size_of(usize)
            );
        }
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
                    ) {
                    acceptance_report_node(
                        context, "functions", "return_type", node
                    );
                    errors = errors + 1;
                }
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
                    ) {
                    acceptance_report_node(
                        context, "functions", "return_resource", node
                    );
                    errors = errors + 1;
                }
                if acceptance_kind(context, result_type) == 11 {
                    usize root = value_name;
                    if read_record_field(context.syntax_data, value, 0) == 41 {
                        root = ir_left_expression(
                            context, value,
                            read_record_field(context.syntax_data, value, 3)
                        );
                    }
                    if root < context.syntax.length && acceptance_symbol_local(
                        context, ir_resolve_name(context, root), function_symbol
                    ) {
                        acceptance_report_node(
                            context, "functions", "return_slice", node
                        );
                        errors = errors + 1;
                    }
                }
                if read_record_field(context.syntax_data, value, 0) == 47 &&
                    acceptance_status_failure(context, value) {
                    parameter_index = 0;
                    while parameter_index < parameter_count {
                        usize parameter_symbol = acceptance_parameter_at(
                            context, function_symbol, parameter_index
                        );
                        if parameter_symbol < context.symbols.length &&
                            read_record_field(
                                    context.detail_data, parameter_symbol, 3
                                ) == 1 && acceptance_out_assigned(
                                    context, function_node, parameter_symbol,
                                    read_record_field(context.syntax_data, node, 1)
                                ) {
                                acceptance_report_node(
                                    context, "functions", "status_out", node
                                );
                                errors = errors + 1;
                            }
                        parameter_index = parameter_index + 1;
                    }
                }
            } else if result_type != semantic_type_void() {
                acceptance_report_node(
                    context, "functions", "missing_return_value", node
                );
                errors = errors + 1;
            }
        }
        node_index = node_index + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_functions(ref IrContext context) {
    usize errors = 0;
    usize symbol = acceptance_source_symbol_first(context);
    usize symbol_end = acceptance_source_symbol_end(context, symbol);
    while symbol < symbol_end {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() {
            usize node = read_record_field(
                context.detail_data, symbol, 1
            );
            if node < context.syntax.length {
                errors = errors + acceptance_validate_function(
                    context, node, symbol
                );
            }
        }
        symbol = symbol + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_scopes(ref IrContext context) {
    usize errors = 0;
    usize left = acceptance_source_symbol_first(context);
    usize symbol_end = acceptance_source_symbol_end(context, left);
    while left < symbol_end {
        if read_record_field(context.symbol_data, left, 0) ==
                resolution_symbol_variable() &&
            read_record_field(context.symbol_data, left, 1) ==
                context.source_record {
            usize right = left + 1;
            while right < symbol_end {
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
                    usize left_block = ir_block_parent(
                        context, left_declaration
                    );
                    usize right_block = ir_block_parent(
                        context, right_declaration
                    );
                    if left_block == right_block {
                        acceptance_report_node(
                            context, "scopes", "same_block", right_declaration
                        );
                        errors = errors + 1;
                    } else if left_block < context.syntax.length &&
                        right_block < context.syntax.length &&
                        (semantic_node_contains(
                            context.syntax_data, left_block, right_block
                        ) || semantic_node_contains(
                            context.syntax_data, right_block, left_block
                        )) {
                        acceptance_report_node(
                            context, "scopes", "nested_block", right_declaration
                        );
                        errors = errors + 1;
                    }
                }
                right = right + 1;
            }
        }
        left = left + 1;
    }

    usize for_index = 0;
    usize for_count = context.syntax.length;
    if context.control_nodes != null { for_count = context.control_count; }
    while for_index < for_count {
        usize for_node = for_index;
        if context.control_nodes != null {
            for_node = read_usize(
                context.control_nodes, for_index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, for_node, 0) == 16 {
            usize body = ir_largest_direct_block(context, for_node);
            usize symbol = acceptance_source_symbol_first(context);
            usize local_end = acceptance_source_symbol_end(context, symbol);
            while symbol < local_end {
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
                        usize use_index = 0;
                        usize use_count = context.syntax.length;
                        if context.name_nodes != null {
                            use_count = context.name_count;
                        }
                        while use_index < use_count {
                            usize use = use_index;
                            if context.name_nodes != null {
                                use = read_usize(
                                    context.name_nodes,
                                    use_index * size_of(usize)
                                );
                            }
                            if read_record_field(context.syntax_data, use, 0) == 27 &&
                                read_record_field(context.syntax_data, use, 1) >=
                                    read_record_field(context.syntax_data, for_node, 1) +
                                    read_record_field(context.syntax_data, for_node, 2) &&
                                ir_resolve_name(context, use) == symbol {
                                acceptance_report_node(
                                    context, "scopes", "for_escape", use
                                );
                                errors = errors + 1;
                            }
                            use_index = use_index + 1;
                        }
                    }
                }
                symbol = symbol + 1;
            }
        }
        for_index = for_index + 1;
    }
    return errors;
}
