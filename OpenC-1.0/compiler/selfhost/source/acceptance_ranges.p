import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_range_base_symbol(
    ref IrContext context,
    usize range
) {
    usize base = resolution_left_expression(
        context.syntax_data, range,
        read_record_field(context.syntax_data, range, 3)
    );
    if base >= context.syntax.length { return context.symbols.length; }
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, base
    );
    if read_record_field(context.syntax_data, base, 0) == 27 { name = base; }
    if name >= context.syntax.length { return context.symbols.length; }
    return ir_resolve_name(context, name);
}

unsafe AcceptanceRange acceptance_range_bounds(
    ref IrContext context,
    usize range
) {
    usize bracket = read_record_field(context.syntax_data, range, 3);
    usize close = read_record_field(context.syntax_data, range, 1) +
        read_record_field(context.syntax_data, range, 2) - 1;
    usize dots = bracket + 1;
    while dots < close && !starts_with_ascii(
        context.source, dots, ".."
    ) { dots = dots + 1; }
    i64 lower = 0;
    i64 upper = cast(i64, 9223372036854775807);
    usize lower_node = ir_root_in_bounds(context, bracket + 1, dots);
    usize upper_node = ir_root_in_bounds(context, dots + 2, close);
    ResolutionInteger lower_value = acceptance_integer_value(
        context, lower_node
    );
    ResolutionInteger upper_value = acceptance_integer_value(
        context, upper_node
    );
    if lower_value.valid { lower = lower_value.value; }
    if upper_value.valid { upper = upper_value.value; }
    return AcceptanceRange{ valid = true, lower = lower, upper = upper };
}

unsafe bool acceptance_slice_mutated(
    ref IrContext context,
    usize slice_symbol
) {
    usize assignment = 0;
    while assignment < context.syntax.length {
        if read_record_field(context.syntax_data, assignment, 0) == 37 {
            usize left = resolution_left_expression(
                context.syntax_data, assignment,
                read_record_field(context.syntax_data, assignment, 3)
            );
            if left < context.syntax.length && read_record_field(
                context.syntax_data, left, 0
            ) == 40 {
                usize base = resolution_left_expression(
                    context.syntax_data, left,
                    read_record_field(context.syntax_data, left, 3)
                );
                if base < context.syntax.length &&
                    ir_resolve_name(context, base) == slice_symbol {
                    return true;
                }
            }
        }
        assignment = assignment + 1;
    }
    return false;
}

unsafe usize acceptance_validate_slice_aliases(ref IrContext context) {
    usize errors = 0;
    usize left = 0;
    while left < context.symbols.length {
        if read_record_field(context.symbol_data, left, 0) ==
                resolution_symbol_variable() &&
            read_record_field(context.symbol_data, left, 1) ==
                context.source_record && acceptance_kind(
                    context, read_record_field(context.symbol_data, left, 4)
                ) == 11 && !acceptance_const_type(
                    context, read_record_field(context.symbol_data, left, 4)
                ) && acceptance_slice_mutated(context, left) {
            usize left_declaration = read_record_field(
                context.detail_data, left, 1
            );
            usize left_range = flow_local_initializer_root(
                context.syntax_data, context.syntax, left_declaration
            );
            if left_range < context.syntax.length && read_record_field(
                context.syntax_data, left_range, 0
            ) == 41 {
                usize left_base = acceptance_range_base_symbol(
                    context, left_range
                );
                AcceptanceRange left_bounds = acceptance_range_bounds(
                    context, left_range
                );
                usize right = left + 1;
                while right < context.symbols.length {
                    if read_record_field(context.symbol_data, right, 0) ==
                            resolution_symbol_variable() &&
                        read_record_field(context.symbol_data, right, 1) ==
                            context.source_record && acceptance_kind(
                            context,
                            read_record_field(context.symbol_data, right, 4)
                        ) == 11 && acceptance_slice_mutated(context, right) {
                        usize right_range = flow_local_initializer_root(
                            context.syntax_data, context.syntax,
                            read_record_field(context.detail_data, right, 1)
                        );
                        if right_range < context.syntax.length &&
                            read_record_field(
                                context.syntax_data, right_range, 0
                            ) == 41 && acceptance_range_base_symbol(
                                context, right_range
                            ) == left_base {
                            AcceptanceRange right_bounds =
                                acceptance_range_bounds(context, right_range);
                            if left_bounds.lower < right_bounds.upper &&
                                right_bounds.lower < left_bounds.upper {
                                errors = errors + 1;
                            }
                        }
                    }
                    right = right + 1;
                }
            }
        }
        left = left + 1;
    }
    return errors;
}

unsafe bool acceptance_call_named(
    ref IrContext context,
    usize call,
    text expected
) {
    if call >= context.syntax.length || read_record_field(
        context.syntax_data, call, 0
    ) != 38 { return false; }
    usize callee = read_record_field(context.syntax_data, call, 3);
    return callee < context.syntax.length && span_equals_ascii(
        context.source,
        read_record_field(context.syntax_data, callee, 1),
        read_record_field(context.syntax_data, callee, 2), expected
    );
}

unsafe bool acceptance_large_literal(
    ref IrContext context,
    usize node
) {
    if node >= context.syntax.length || read_record_field(
        context.syntax_data, node, 0
    ) != 29 { return false; }
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    usize digits = 0;
    usize cursor = 0;
    while cursor < length {
        u8 octet = byte_at_or_zero(context.source, start + cursor);
        if octet >= 48 && octet <= 57 { digits = digits + 1; }
        cursor = cursor + 1;
    }
    return digits >= 20;
}

unsafe usize acceptance_validate_calls(ref IrContext context) {
    usize errors = 0;
    usize call = 0;
    while call < context.syntax.length {
        if read_record_field(context.syntax_data, call, 0) == 38 {
            usize argument_count = read_record_field(
                context.syntax_data, call, 4
            );
            usize target = ir_select_call(context, call);
            if target < context.symbols.length &&
                acceptance_parameter_count(context, target) != argument_count {
                errors = errors + 1;
            }
            usize argument = 0;
            while argument < argument_count {
                IrBounds bounds = ir_argument_bounds(context, call, argument);
                if bounds.valid {
                    usize value = ir_root_in_bounds(
                        context, bounds.start, bounds.end
                    );
                    if value < context.syntax.length && read_record_field(
                        context.syntax_data, value, 0
                    ) == 51 {
                        usize out_symbol = ir_resolve_name(context, value);
                        if out_symbol < context.symbols.length &&
                            read_record_field(
                                context.symbol_data, out_symbol, 0
                            ) == resolution_symbol_variable() {
                            usize declaration = read_record_field(
                                context.detail_data, out_symbol, 1
                            );
                            if flow_local_initializer_root(
                                context.syntax_data, context.syntax, declaration
                            ) < context.syntax.length {
                                errors = errors + 1;
                            }
                        }
                    } else if acceptance_large_literal(context, value) {
                        bool has_u64_context = false;
                        if target < context.symbols.length &&
                            argument < acceptance_parameter_count(
                                context, target
                            ) {
                            usize parameter = acceptance_parameter_at(
                                context, target, argument
                            );
                            has_u64_context = parameter < context.symbols.length &&
                                read_record_field(
                                    context.symbol_data, parameter, 4
                                ) == semantic_builtin_type("u64", 0, 3);
                        }
                        if !has_u64_context &&
                            !acceptance_call_named(
                                context, call, "memory.alloc"
                            ) && !acceptance_call_named(
                                context, call, "system.memory.alloc"
                            ) { errors = errors + 1; }
                    }
                    if target < context.symbols.length &&
                        argument < acceptance_parameter_count(
                            context, target
                        ) && value < context.syntax.length &&
                        read_record_field(context.syntax_data, value, 0) != 51 {
                        usize parameter = acceptance_parameter_at(
                            context, target, argument
                        );
                        usize expected = read_record_field(
                            context.symbol_data, parameter, 4
                        );
                        usize actual = ir_node_type(
                            context, value, semantic_type_error()
                        );
                        if !acceptance_can_initialize(
                            context, value, actual, expected
                        ) { errors = errors + 1; }
                    }
                }
                argument = argument + 1;
            }
        }
        call = call + 1;
    }
    return errors;
}
