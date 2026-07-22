import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_validate_conditions(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, node, 0);
        if kind == 14 || kind == 15 || kind == 25 {
            usize body = ir_direct_block(context, node, 0);
            if body < context.syntax.length {
                usize condition = ir_largest_expression_before(
                    context, node,
                    read_record_field(context.syntax_data, body, 1)
                );
                if condition < context.syntax.length && ir_node_type(
                    context, condition, semantic_type_error()
                ) != semantic_type_bool() { errors = errors + 1; }
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_index_ranges(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, node, 0);
        if kind == 40 || kind == 41 {
            usize bracket = read_record_field(context.syntax_data, node, 3);
            usize base = resolution_left_expression(
                context.syntax_data, node, bracket
            );
            usize base_type = ir_node_type(
                context, base, semantic_type_error()
            );
            if base < context.syntax.length {
                usize base_symbol = ir_resolve_name(context, base);
                if base_symbol < context.symbols.length {
                    base_type = read_record_field(
                        context.symbol_data, base_symbol, 4
                    );
                }
            }
            usize base_kind = acceptance_kind(context, base_type);
            if base_kind == 0 && base_type < context.types.capacity {
                base_kind = read_record_field(context.type_data, base_type, 0);
            }
            if kind == 41 && base_type < context.types.capacity &&
                read_record_field(context.type_data, base_type, 0) == 10 {
                usize direct_close = read_record_field(
                    context.syntax_data, node, 1
                ) + read_record_field(
                    context.syntax_data, node, 2
                ) - 1;
                usize direct_dots = bracket + 1;
                while direct_dots < direct_close && !starts_with_ascii(
                    context.source, direct_dots, ".."
                ) { direct_dots = direct_dots + 1; }
                usize direct_upper = ir_root_in_bounds(
                    context, direct_dots + 2, direct_close
                );
                if direct_upper < context.syntax.length {
                    ResolutionInteger direct_value = acceptance_integer_value(
                        context, direct_upper
                    );
                    if direct_value.valid && direct_value.value > cast(i64,
                        read_record_field(context.type_data, base_type, 2)
                    ) { errors = errors + 1; }
                }
            }
            if kind == 40 {
                usize index = ir_root_in_bounds(
                    context, bracket + 1,
                    read_record_field(context.syntax_data, node, 1) +
                    read_record_field(context.syntax_data, node, 2) - 1
                );
                if base_kind != 10 && base_kind != 11 {
                    errors = errors + 1;
                }
                if index < context.syntax.length &&
                    !acceptance_integer(context, ir_node_type(
                        context, index, semantic_type_error()
                    )) { errors = errors + 1; }
                if base_kind == 10 && index < context.syntax.length {
                    ResolutionInteger value = acceptance_integer_value(
                        context, index
                    );
                    if value.valid && (value.value < 0 ||
                        value.value >= cast(i64, read_record_field(
                            context.type_data, base_type, 2
                        ))) { errors = errors + 1; }
                }
            } else {
                if base_kind != 10 && base_kind != 11 && base_kind != 7 {
                    errors = errors + 1;
                }
                if base_kind == 10 {
                    usize close = read_record_field(
                        context.syntax_data, node, 1
                    ) + read_record_field(
                        context.syntax_data, node, 2
                    ) - 1;
                    usize dots = bracket + 1;
                    while dots < close && !starts_with_ascii(
                        context.source, dots, ".."
                    ) { dots = dots + 1; }
                    usize upper = 0;
                    while upper < context.syntax.length {
                        if read_record_field(context.syntax_data, upper, 0) == 29 &&
                            read_record_field(context.syntax_data, upper, 1) >= dots + 2 &&
                            semantic_node_contains(context.syntax_data, node, upper) {
                            ResolutionInteger upper_value = acceptance_integer_value(
                                context, upper
                            );
                            if upper_value.valid && upper_value.value > cast(i64,
                                read_record_field(context.type_data, base_type, 2)
                            ) { errors = errors + 1; }
                        }
                        upper = upper + 1;
                    }
                }
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_type_size(ref IrContext context, usize type_id) {
    usize kind = acceptance_kind(context, type_id);
    usize bits = acceptance_bits(context, type_id);
    if bits != 0 { return bits / 8; }
    if kind == 5 || kind == 6 { return 1; }
    if kind == 12 || kind == 13 { return 8; }
    return 0;
}

unsafe usize acceptance_typed_value(
    ref IrContext context,
    usize node
) {
    usize type_node = ir_type_ref_within(context, node);
    if type_node >= context.syntax.length { return context.syntax.length; }
    usize after = read_record_field(context.syntax_data, type_node, 1) +
        read_record_field(context.syntax_data, type_node, 2);
    return ir_expression_child_after(context, node, after, true);
}

unsafe usize acceptance_validate_casts(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, node, 0);
        if kind == 42 || kind == 43 {
            usize target = ir_resolve_type_node(
                context, ir_type_ref_within(context, node)
            );
            usize value = acceptance_typed_value(context, node);
            usize source_type = ir_node_type(
                context, value, semantic_type_error()
            );
            usize target_kind = acceptance_kind(context, target);
            usize source_kind = acceptance_kind(context, source_type);
            if kind == 42 {
                if acceptance_integer(context, target) && source_kind == 4 &&
                    value < context.syntax.length && read_record_field(
                        context.syntax_data, value, 0
                    ) == 30 && flow_span_has_byte(
                        context.source,
                        read_record_field(context.syntax_data, value, 1),
                        read_record_field(context.syntax_data, value, 2), 46
                    ) { errors = errors + 1; }
                if target_kind == 4 && acceptance_integer(
                    context, source_type
                ) && acceptance_bits(context, target) == 32 {
                    ResolutionInteger integer = acceptance_integer_value(
                        context, value
                    );
                    if integer.valid && (integer.value > 16777216 ||
                        integer.value < -16777216) {
                        errors = errors + 1;
                    }
                }
                if acceptance_integer(context, target) && source_kind == 13 {
                    errors = errors + 1;
                }
                if starts_with_ascii(
                    context.source,
                    read_record_field(context.syntax_data, node, 1),
                    "cast_unchecked"
                ) && acceptance_integer(context, target) && source_kind == 4 {
                    errors = errors + 1;
                }
            } else {
                if target_kind == 13 && acceptance_integer(
                    context, source_type
                ) { errors = errors + 1; }
                if !(target_kind == 13 && source_kind == 13) {
                    bool target_scalar = target_kind == 2 || target_kind == 3 ||
                        target_kind == 4 || target_kind == 6;
                    bool source_scalar = source_kind == 2 || source_kind == 3 ||
                        source_kind == 4 || source_kind == 6;
                    if !target_scalar || !source_scalar {
                        errors = errors + 1;
                    } else if acceptance_type_size(context, target) !=
                        acceptance_type_size(context, source_type) {
                        errors = errors + 1;
                    }
                }
            }
        } else if kind == 46 {
            usize target = ir_resolve_type_node(
                context, ir_type_ref_within(context, node)
            );
            if target == semantic_type_void() { errors = errors + 1; }
        }
        node = node + 1;
    }
    return errors;
}
