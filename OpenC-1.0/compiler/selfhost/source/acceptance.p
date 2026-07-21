import system.file;
import system.memory;
import system.text;

struct AcceptanceRange {
    bool valid;
    i64 lower;
    i64 upper;
}

unsafe usize acceptance_kind(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return 0; }
    return read_record_field(context.type_data, type_id, 0);
}

unsafe bool acceptance_const_type(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return false; }
    return read_record_field(context.type_data, type_id, 4) % 2 == 1;
}

unsafe usize acceptance_bits(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return 0; }
    if (read_record_field(context.type_data, type_id, 4) / 8 % 2 == 1) {
        usize preserved = read_record_field(context.type_data, type_id, 1);
        if preserved != type_id { return acceptance_bits(context, preserved); }
    }
    usize bits = read_record_field(context.type_data, type_id, 3);
    if bits == 0 {
        usize kind = acceptance_kind(context, type_id);
        if kind == 2 || kind == 3 || kind == 12 || kind == 13 {
            return 64;
        }
    }
    return bits;
}

unsafe bool acceptance_integer(ref IrContext context, usize type_id) {
    usize kind = acceptance_kind(context, type_id);
    return kind == 2 || kind == 3 || kind == 6;
}

unsafe bool acceptance_numeric(ref IrContext context, usize type_id) {
    usize kind = acceptance_kind(context, type_id);
    return kind == 2 || kind == 3 || kind == 4;
}

unsafe bool acceptance_resource(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return false; }
    if semantic_type_resource(context.type_data, type_id) { return true; }
    usize kind = acceptance_kind(context, type_id);
    if (read_record_field(context.type_data, type_id, 4) / 8 % 2 == 1) {
        usize preserved = read_record_field(context.type_data, type_id, 1);
        if preserved != type_id { return acceptance_resource(context, preserved); }
    }
    if kind >= 10 && kind <= 15 {
        usize element = read_record_field(context.type_data, type_id, 1);
        if element != type_id {
            return semantic_type_resource(context.type_data, element);
        }
    }
    return false;
}

unsafe bool acceptance_lossless(
    ref IrContext context,
    usize actual,
    usize expected
) {
    if actual == expected { return true; }
    if actual >= context.types.length || expected >= context.types.length {
        return false;
    }
    usize actual_kind = acceptance_kind(context, actual);
    usize expected_kind = acceptance_kind(context, expected);
    if actual_kind == expected_kind && actual_kind >= 10 &&
        actual_kind <= 14 {
        usize actual_element = read_record_field(
            context.type_data, actual, 1
        );
        usize expected_element = read_record_field(
            context.type_data, expected, 1
        );
        if acceptance_const_type(context, actual) &&
            !acceptance_const_type(context, expected) {
            return false;
        }
        if (actual_kind == 11 || actual_kind == 12 || actual_kind == 13) &&
            acceptance_const_type(context, actual_element) &&
            !acceptance_const_type(context, expected_element) {
            return false;
        }
        return acceptance_lossless(context, actual_element, expected_element);
    }
    if actual_kind == 10 && expected_kind == 11 {
        return acceptance_lossless(
            context,
            read_record_field(context.type_data, actual, 1),
            read_record_field(context.type_data, expected, 1)
        );
    }
    if actual_kind == 2 && expected_kind == 2 {
        return acceptance_bits(context, actual) <=
            acceptance_bits(context, expected);
    }
    if actual_kind == 3 && expected_kind == 3 {
        return acceptance_bits(context, actual) <=
            acceptance_bits(context, expected);
    }
    if actual_kind == 6 && expected_kind == 3 {
        return 8 <= acceptance_bits(context, expected);
    }
    if actual_kind == 4 && expected_kind == 4 {
        return acceptance_bits(context, actual) <=
            acceptance_bits(context, expected);
    }
    return false;
}

unsafe ResolutionInteger acceptance_integer_value(
    ref IrContext context,
    usize node
) {
    if node >= context.syntax.length {
        return ResolutionInteger{ value = 0, valid = false };
    }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 29 {
        return resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, node, 1),
            read_record_field(context.syntax_data, node, 2)
        );
    }
    if kind == 35 && flow_node_operator(
        context.source, context.syntax_data, node, "-"
    ) {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize child = resolution_right_expression(
            context.syntax_data, node,
            operator_start + read_record_field(context.syntax_data, node, 4)
        );
        ResolutionInteger value = acceptance_integer_value(context, child);
        if value.valid { value.value = -value.value; }
        return value;
    }
    return ResolutionInteger{ value = 0, valid = false };
}

unsafe bool acceptance_literal_fits(
    ref IrContext context,
    usize node,
    usize expected
) {
    if node < context.syntax.length && read_record_field(
        context.syntax_data, node, 0
    ) == 29 && acceptance_kind(context, expected) == 3 &&
        acceptance_bits(context, expected) == 64 {
        usize start = read_record_field(context.syntax_data, node, 1);
        usize length = read_record_field(context.syntax_data, node, 2);
        usize digits = 0;
        usize cursor = 0;
        while cursor < length {
            u8 octet = byte_at_or_zero(context.source, start + cursor);
            if octet >= 48 && octet <= 57 { digits = digits + 1; }
            cursor = cursor + 1;
        }
        if digits < 20 { return true; }
        if digits > 20 { return false; }
        text maximum_text = "18446744073709551615";
        cursor = 0;
        usize digit = 0;
        while cursor < length {
            u8 digit_octet = byte_at_or_zero(context.source, start + cursor);
            if digit_octet >= 48 && digit_octet <= 57 {
                u8 limit = byte_at_or_zero(maximum_text, digit);
                if digit_octet < limit { return true; }
                if digit_octet > limit { return false; }
                digit = digit + 1;
            }
            cursor = cursor + 1;
        }
        return true;
    }
    ResolutionInteger value = acceptance_integer_value(context, node);
    if !value.valid || !acceptance_integer(context, expected) { return false; }
    usize bits = acceptance_bits(context, expected);
    usize kind = acceptance_kind(context, expected);
    if kind == 2 {
        if bits >= 64 { return true; }
        i64 limit = cast(i64, 1) << cast(i64, bits - 1);
        return value.value >= -limit && value.value < limit;
    }
    if value.value < 0 { return false; }
    if bits >= 63 { return true; }
    i64 maximum = (cast(i64, 1) << cast(i64, bits)) - 1;
    return value.value <= maximum;
}

unsafe bool acceptance_can_initialize(
    ref IrContext context,
    usize node,
    usize actual,
    usize expected
) {
    if acceptance_lossless(context, actual, expected) { return true; }
    if acceptance_literal_fits(context, node, expected) { return true; }
    if node < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, node, 0);
        usize expected_kind = acceptance_kind(context, expected);
        if kind == 33 && expected_kind == 13 { return true; }
        if kind == 34 && expected_kind == 14 { return true; }
        if kind == 50 && expected_kind == 10 { return true; }
        if expected_kind == 14 && acceptance_lossless(
            context, actual,
            read_record_field(context.type_data, expected, 1)
        ) { return true; }
        if expected_kind == 12 && acceptance_lossless(
            context, actual,
            read_record_field(context.type_data, expected, 1)
        ) {
            usize node_kind = read_record_field(context.syntax_data, node, 0);
            return node_kind == 27 || node_kind == 39 || node_kind == 40;
        }
    }
    return false;
}

unsafe bool acceptance_prefix_has(
    ref IrContext context,
    usize declaration,
    text expected
) {
    return semantic_prefix_has(
        context.source, context.token_data, context.tokens,
        read_record_field(context.syntax_data, declaration, 1),
        read_record_field(context.syntax_data, declaration, 3),
        expected
    );
}

unsafe bool acceptance_symbol_named(
    ref IrContext context,
    usize left,
    usize right
) {
    text left_source;
    status left_loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, left, 1), out left_source
    );
    if !left_loaded.ok { return false; }
    text right_source;
    status right_loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, right, 1), out right_source
    );
    if !right_loaded.ok { return false; }
    return semantic_spans_equal(
        left_source,
        read_record_field(context.symbol_data, left, 2),
        read_record_field(context.symbol_data, left, 3),
        right_source,
        read_record_field(context.symbol_data, right, 2),
        read_record_field(context.symbol_data, right, 3)
    );
}

unsafe bool acceptance_known_named_type(
    ref IrContext context,
    usize type_id
) {
    if acceptance_kind(context, type_id) != 9 { return true; }
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if (kind == resolution_symbol_struct() ||
            kind == resolution_symbol_resource() ||
            kind == resolution_symbol_enum()) && read_record_field(
                context.symbol_data, symbol, 4
            ) == type_id { return true; }
        symbol = symbol + 1;
    }
    return false;
}

unsafe usize acceptance_validate_type_refs(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 26 {
            usize type_id = ir_resolve_type_node(context, node);
            usize kind = acceptance_kind(context, type_id);
            usize element = type_id;
            while kind >= 10 && kind <= 15 && element < context.types.length {
                element = read_record_field(context.type_data, element, 1);
                kind = acceptance_kind(context, element);
            }
            if !acceptance_known_named_type(context, element) {
                errors = errors + 1;
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_fields(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 9 {
            usize found = resolution_find_owner_symbol(
                context.symbol_data, context.detail_data, context.symbols,
                context.source_record, node,
                resolution_symbol_field(), 0
            );
            if found != 0 {
                usize type_id = read_record_field(
                    context.symbol_data, found - 1, 4
                );
                usize kind = acceptance_kind(context, type_id);
                if kind == 1 || kind == 11 || kind == 12 || kind == 15 {
                    errors = errors + 1;
                }
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_locals(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 12 {
            usize symbol = ir_local_symbol(context, node);
            if symbol < context.symbols.length {
                usize expected = read_record_field(
                    context.symbol_data, symbol, 4
                );
                usize kind = acceptance_kind(context, expected);
                usize initializer = flow_local_initializer_root(
                    context.syntax_data, context.syntax, node
                );
                if kind == 1 { errors = errors + 1; }
                if kind == 12 && initializer >= context.syntax.length {
                    errors = errors + 1;
                }
                if kind == 14 && acceptance_resource(
                    context, read_record_field(context.type_data, expected, 1)
                ) { errors = errors + 1; }
                if kind == 15 && acceptance_resource(
                    context, read_record_field(context.type_data, expected, 1)
                ) { errors = errors + 1; }
                if acceptance_prefix_has(context, node, "optional") &&
                    flow_span_contains_ascii(
                        context.source,
                        read_record_field(context.syntax_data, node, 1),
                        read_record_field(context.syntax_data, node, 2), "[]"
                    ) { errors = errors + 1; }
                if acceptance_prefix_has(context, node, "const") &&
                    acceptance_resource(context, expected) {
                    errors = errors + 1;
                }
                if initializer < context.syntax.length {
                    usize actual = ir_node_type(
                        context, initializer, semantic_type_error()
                    );
                    if !acceptance_can_initialize(
                        context, initializer, actual, expected
                    ) { errors = errors + 1; }
                }
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe bool acceptance_lvalue(ref IrContext context, usize node) {
    if node >= context.syntax.length { return false; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 39 || kind == 40 { return true; }
    if kind == 35 && flow_node_operator(
        context.source, context.syntax_data, node, "*"
    ) { return true; }
    if kind != 27 { return false; }
    if flow_span_has_byte(
        context.source,
        read_record_field(context.syntax_data, node, 1),
        read_record_field(context.syntax_data, node, 2), 46
    ) { return true; }
    usize symbol = ir_resolve_name(context, node);
    if symbol >= context.symbols.length { return false; }
    usize symbol_kind = read_record_field(context.symbol_data, symbol, 0);
    return symbol_kind == resolution_symbol_variable() ||
        symbol_kind == resolution_symbol_parameter() ||
        symbol_kind == resolution_symbol_field();
}

unsafe bool acceptance_mutable(ref IrContext context, usize node) {
    if node >= context.syntax.length { return false; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 35 && flow_node_operator(
        context.source, context.syntax_data, node, "*"
    ) {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize child = resolution_right_expression(
            context.syntax_data, node,
            operator_start + read_record_field(context.syntax_data, node, 4)
        );
        usize pointer = ir_node_type(
            context, child, semantic_type_error()
        );
        return acceptance_kind(context, pointer) == 13 &&
            !acceptance_const_type(context, pointer);
    }
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, node
    );
    if kind == 27 { name = node; }
    if name >= context.syntax.length { return true; }
    usize symbol = ir_resolve_name(context, name);
    if symbol >= context.symbols.length { return true; }
    usize declaration = read_record_field(context.detail_data, symbol, 1);
    usize type_id = read_record_field(context.symbol_data, symbol, 4);
    if acceptance_const_type(context, type_id) { return false; }
    return !acceptance_prefix_has(context, declaration, "const");
}

unsafe usize acceptance_validate_assignments(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 37 {
            usize operator_start = read_record_field(context.syntax_data, node, 3);
            usize left = resolution_left_expression(
                context.syntax_data, node, operator_start
            );
            usize right = resolution_right_expression(
                context.syntax_data, node,
                operator_start + read_record_field(context.syntax_data, node, 4)
            );
            if !acceptance_lvalue(context, left) { errors = errors + 1; }
            if !acceptance_mutable(context, left) { errors = errors + 1; }
            usize expected = ir_node_type(
                context, left, semantic_type_error()
            );
            if acceptance_kind(context, expected) == 12 {
                expected = read_record_field(context.type_data, expected, 1);
            }
            usize actual = ir_node_type(
                context, right, semantic_type_error()
            );
            if !acceptance_can_initialize(
                context, right, actual, expected
            ) { errors = errors + 1; }
        }
        node = node + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_binary(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 36 {
            usize operator_start = read_record_field(context.syntax_data, node, 3);
            usize left = resolution_left_expression(
                context.syntax_data, node, operator_start
            );
            usize right = resolution_right_expression(
                context.syntax_data, node,
                operator_start + read_record_field(context.syntax_data, node, 4)
            );
            usize left_type = ir_node_type(
                context, left, semantic_type_error()
            );
            usize right_type = ir_node_type(
                context, right, semantic_type_error()
            );
            bool logical = flow_node_operator(
                context.source, context.syntax_data, node, "&&"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "||"
            );
            bool equality = flow_node_operator(
                context.source, context.syntax_data, node, "=="
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "!="
            );
            bool comparison = equality || flow_node_operator(
                context.source, context.syntax_data, node, "<"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "<="
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">="
            );
            if logical {
                if left_type != semantic_type_bool() ||
                    right_type != semantic_type_bool() {
                    errors = errors + 1;
                }
            } else if comparison {
                bool null_pointer = (read_record_field(
                    context.syntax_data, left, 0
                ) == 33 && acceptance_kind(context, right_type) == 13) ||
                    (read_record_field(context.syntax_data, right, 0) == 33 &&
                     acceptance_kind(context, left_type) == 13);
                bool compatible = acceptance_lossless(
                    context, left_type, right_type
                ) || acceptance_lossless(context, right_type, left_type) ||
                    acceptance_literal_fits(context, left, right_type) ||
                    acceptance_literal_fits(context, right, left_type) ||
                    null_pointer;
                if !compatible { errors = errors + 1; }
                if equality && (acceptance_resource(context, left_type) ||
                    acceptance_resource(context, right_type)) {
                    errors = errors + 1;
                }
            } else if acceptance_kind(context, left_type) != 13 &&
                acceptance_kind(context, right_type) != 13 {
                if !acceptance_numeric(context, left_type) ||
                    !acceptance_numeric(context, right_type) {
                    errors = errors + 1;
                } else if !acceptance_lossless(
                    context, left_type, right_type
                ) && !acceptance_lossless(
                    context, right_type, left_type
                ) && !acceptance_literal_fits(
                    context, left, right_type
                ) && !acceptance_literal_fits(
                    context, right, left_type
                ) { errors = errors + 1; }
            }
            bool bitwise = flow_node_operator(
                context.source, context.syntax_data, node, "&"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "|"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, "^"
            );
            if bitwise && acceptance_kind(context, left_type) == 2 {
                errors = errors + 1;
            }
            bool shift = flow_node_operator(
                context.source, context.syntax_data, node, "<<"
            ) || flow_node_operator(
                context.source, context.syntax_data, node, ">>"
            );
            if shift {
                ResolutionInteger amount = acceptance_integer_value(
                    context, right
                );
                if amount.valid && (amount.value < 0 ||
                    amount.value >= cast(i64, acceptance_bits(
                        context, left_type
                    ))) { errors = errors + 1; }
            }
            if flow_node_operator(
                context.source, context.syntax_data, node, "/"
            ) {
                ResolutionInteger left_value = acceptance_integer_value(
                    context, left
                );
                ResolutionInteger right_value = acceptance_integer_value(
                    context, right
                );
                if left_value.valid && right_value.valid &&
                    left_value.value == cast(i64, -2147483647) - 1 &&
                    right_value.value == -1 {
                    errors = errors + 1;
                }
            }
        }
        node = node + 1;
    }
    return errors;
}

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
                            ResolutionInteger value = acceptance_integer_value(
                                context, upper
                            );
                            if value.valid && value.value > cast(i64,
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
        if read_record_field(context.syntax_data, node, 0) == 49 &&
            semantic_node_contains(context.syntax_data, initializer, node) &&
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
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 48 {
            usize aggregate_type = ir_node_type(
                context, node, semantic_type_error()
            );
            usize aggregate = context.symbols.length;
            usize symbol = 0;
            while symbol < context.symbols.length {
                usize kind = read_record_field(context.symbol_data, symbol, 0);
                if (kind == resolution_symbol_struct() ||
                    kind == resolution_symbol_resource()) &&
                    read_record_field(context.symbol_data, symbol, 4) ==
                        aggregate_type {
                    aggregate = symbol;
                    break;
                }
                symbol = symbol + 1;
            }
            if aggregate < context.symbols.length {
                symbol = 0;
                while symbol < context.symbols.length {
                    if read_record_field(context.symbol_data, symbol, 0) ==
                            resolution_symbol_field() &&
                        read_record_field(context.detail_data, symbol, 2) ==
                            aggregate + 1 &&
                        !acceptance_field_supplied(context, node, symbol) &&
                        !acceptance_field_default(context, symbol) {
                        errors = errors + 1;
                    }
                    symbol = symbol + 1;
                }
            }
        }
        node = node + 1;
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
        if read_record_field(context.syntax_data, field, 0) == 49 &&
            semantic_node_contains(context.syntax_data, initializer, field) &&
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

unsafe usize acceptance_validate_function(
    ref IrContext context,
    usize function_node,
    usize function_symbol
) {
    usize errors = 0;
    context.function_node = function_node;
    context.function_symbol = function_symbol;
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

unsafe ResolutionInteger acceptance_enum_explicit(
    ref IrContext context,
    usize item
) {
    usize cursor = read_record_field(context.syntax_data, item, 1) +
        read_record_field(context.syntax_data, item, 2);
    usize source_length = text.byte_length(context.source);
    while cursor < source_length && (byte_at_or_zero(
        context.source, cursor
    ) == 32 || byte_at_or_zero(context.source, cursor) == 9) {
        cursor = cursor + 1;
    }
    if cursor >= source_length || byte_at_or_zero(
        context.source, cursor
    ) != 61 { return ResolutionInteger{ value = 0, valid = false }; }
    cursor = cursor + 1;
    while cursor < source_length && (byte_at_or_zero(
        context.source, cursor
    ) == 32 || byte_at_or_zero(context.source, cursor) == 9) {
        cursor = cursor + 1;
    }
    bool negative = false;
    if cursor < source_length && byte_at_or_zero(
        context.source, cursor
    ) == 45 { negative = true; cursor = cursor + 1; }
    usize start = cursor;
    while cursor < source_length {
        u8 value = byte_at_or_zero(context.source, cursor);
        if value < 48 || value > 57 { break; }
        cursor = cursor + 1;
    }
    if cursor == start {
        return ResolutionInteger{ value = 0, valid = false };
    }
    ResolutionInteger parsed = resolution_parse_integer(
        context.source, start, cursor - start
    );
    if parsed.valid && negative { parsed.value = -parsed.value; }
    return parsed;
}

unsafe usize acceptance_validate_enums(ref IrContext context) {
    usize errors = 0;
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 5 {
            usize left = 0;
            while left < context.syntax.length {
                if read_record_field(context.syntax_data, left, 0) == 6 &&
                    semantic_node_contains(
                        context.syntax_data, declaration, left
                    ) {
                    ResolutionInteger left_value = acceptance_enum_explicit(
                        context, left
                    );
                    if left_value.valid {
                        usize right = left + 1;
                        while right < context.syntax.length {
                            if read_record_field(
                                context.syntax_data, right, 0
                            ) == 6 && semantic_node_contains(
                                context.syntax_data, declaration, right
                            ) {
                                ResolutionInteger right_value =
                                    acceptance_enum_explicit(context, right);
                                if right_value.valid &&
                                    right_value.value == left_value.value {
                                    errors = errors + 1;
                                }
                            }
                            right = right + 1;
                        }
                    }
                }
                left = left + 1;
            }
        }
        declaration = declaration + 1;
    }
    return errors;
}

unsafe usize acceptance_parameter_count(
    ref IrContext context,
    usize function_symbol
) {
    usize count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 { count = count + 1; }
        symbol = symbol + 1;
    }
    return count;
}

unsafe usize acceptance_parameter_at(
    ref IrContext context,
    usize function_symbol,
    usize requested
) {
    usize count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 {
            if count == requested { return symbol; }
            count = count + 1;
        }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}

unsafe bool acceptance_same_signature(
    ref IrContext context,
    usize left,
    usize right
) {
    usize count = acceptance_parameter_count(context, left);
    if count != acceptance_parameter_count(context, right) { return false; }
    usize index = 0;
    while index < count {
        usize left_parameter = acceptance_parameter_at(context, left, index);
        usize right_parameter = acceptance_parameter_at(context, right, index);
        if left_parameter >= context.symbols.length ||
            right_parameter >= context.symbols.length || read_record_field(
                context.symbol_data, left_parameter, 4
            ) != read_record_field(
                context.symbol_data, right_parameter, 4
            ) || read_record_field(
                context.detail_data, left_parameter, 3
            ) != read_record_field(
                context.detail_data, right_parameter, 3
            ) { return false; }
        index = index + 1;
    }
    return true;
}

unsafe usize acceptance_validate_duplicate_functions(
    ref IrContext context
) {
    usize errors = 0;
    usize left = 0;
    while left < context.symbols.length {
        if read_record_field(context.symbol_data, left, 0) ==
                resolution_symbol_function() &&
            read_record_field(context.detail_data, left, 2) == 0 {
            usize right = left + 1;
            while right < context.symbols.length {
                if read_record_field(context.symbol_data, right, 0) ==
                        resolution_symbol_function() &&
                    read_record_field(context.detail_data, right, 2) == 0 &&
                    read_record_field(context.detail_data, left, 0) ==
                        read_record_field(context.detail_data, right, 0) &&
                    acceptance_symbol_named(context, left, right) &&
                    acceptance_same_signature(context, left, right) {
                    errors = errors + 1;
                }
                right = right + 1;
            }
        }
        left = left + 1;
    }
    return errors;
}

unsafe bool acceptance_source_imports(
    text source,
    text project_source,
    usize module_start,
    usize module_length
) {
    usize source_length = text.byte_length(source);
    usize cursor = 0;
    while cursor + 6 <= source_length {
        if starts_with_ascii(source, cursor, "import") {
            usize name = cursor + 6;
            while name < source_length && (byte_at_or_zero(source, name) == 32 ||
                byte_at_or_zero(source, name) == 9 ||
                byte_at_or_zero(source, name) == 10 ||
                byte_at_or_zero(source, name) == 13) { name = name + 1; }
            if name + module_length <= source_length && semantic_spans_equal(
                source, name, module_length,
                project_source, module_start, module_length
            ) {
                usize after = name + module_length;
                while after < source_length && (byte_at_or_zero(source, after) == 32 ||
                    byte_at_or_zero(source, after) == 9) { after = after + 1; }
                if after < source_length && byte_at_or_zero(source, after) == 59 {
                    return true;
                }
            }
        }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool acceptance_module_imports(
    text project_source,
    text project_root,
    ptr byte module_data,
    ptr byte source_data,
    usize from_module,
    usize to_module
) {
    usize first = read_record_field(module_data, from_module, 2);
    usize count = read_record_field(module_data, from_module, 3);
    usize index = 0;
    while index < count {
        text source;
        status loaded = project_read_source_record(
            project_source, project_root, source_data, first + index,
            out source
        );
        if loaded.ok {
            if acceptance_source_imports(
                source, project_source,
                read_record_field(module_data, to_module, 0),
                read_record_field(module_data, to_module, 1)
            ) { return true; }
        }
        index = index + 1;
    }
    return false;
}

unsafe usize acceptance_validate_module_cycles(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data
) {
    usize errors = 0;
    usize left = 0;
    while left < modules.length {
        usize right = left + 1;
        while right < modules.length {
            if acceptance_module_imports(
                project_source, project_root, module_data, source_data,
                left, right
            ) && acceptance_module_imports(
                project_source, project_root, module_data, source_data,
                right, left
            ) { errors = errors + 1; }
            right = right + 1;
        }
        left = left + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_overload_calls(ref IrContext context) {
    usize errors = 0;
    usize call = 0;
    while call < context.syntax.length {
        if read_record_field(context.syntax_data, call, 0) == 38 &&
            read_record_field(context.syntax_data, call, 4) == 1 {
            usize callee = read_record_field(context.syntax_data, call, 3);
            if callee < context.syntax.length &&
                !flow_span_has_byte(
                    context.source,
                    read_record_field(context.syntax_data, callee, 1),
                    read_record_field(context.syntax_data, callee, 2), 46
                ) {
                IrBounds argument_bounds = ir_argument_bounds(
                    context, call, 0
                );
                if argument_bounds.valid {
                    usize argument = ir_root_in_bounds(
                        context, argument_bounds.start, argument_bounds.end
                    );
                    usize argument_type = ir_node_type(
                        context, argument, semantic_type_error()
                    );
                    if acceptance_integer(context, argument_type) {
                        usize exact = 0;
                        usize viable = 0;
                        usize symbol = 0;
                        while symbol < context.symbols.length {
                            if read_record_field(
                                context.symbol_data, symbol, 0
                            ) == resolution_symbol_function() &&
                                read_record_field(
                                    context.detail_data, symbol, 0
                                ) == context.module_index &&
                                resolution_symbol_name_equals(
                                    context.project_source,
                                    context.project_root,
                                    context.source_data,
                                    context.symbol_data, symbol,
                                    context.source,
                                    read_record_field(
                                        context.syntax_data, callee, 1
                                    ),
                                    read_record_field(
                                        context.syntax_data, callee, 2
                                    )
                                ) && acceptance_parameter_count(
                                    context, symbol
                                ) == 1 {
                                usize parameter = acceptance_parameter_at(
                                    context, symbol, 0
                                );
                                usize parameter_type = read_record_field(
                                    context.symbol_data, parameter, 4
                                );
                                if parameter_type == argument_type {
                                    exact = exact + 1;
                                } else if acceptance_integer(
                                    context, parameter_type
                                ) && acceptance_bits(
                                    context, parameter_type
                                ) > acceptance_bits(context, argument_type) {
                                    viable = viable + 1;
                                }
                            }
                            symbol = symbol + 1;
                        }
                        if exact == 0 && viable > 1 {
                            errors = errors + 1;
                        }
                    }
                }
            }
        }
        call = call + 1;
    }
    return errors;
}

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

unsafe usize acceptance_construct_storage(
    ref IrContext context,
    usize construct_node
) {
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, construct_node
    );
    if name >= context.syntax.length { return context.symbols.length; }
    return ir_resolve_name(context, name);
}

unsafe usize acceptance_construct_result(
    ref IrContext context,
    usize construct_node
) {
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 12 &&
            semantic_node_contains(
                context.syntax_data, declaration, construct_node
            ) { return ir_local_symbol(context, declaration); }
        declaration = declaration + 1;
    }
    return context.symbols.length;
}

unsafe usize acceptance_destroyed_symbol(
    ref IrContext context,
    usize destroy_node
) {
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, destroy_node
    );
    if name >= context.syntax.length { return context.symbols.length; }
    return ir_resolve_name(context, name);
}

unsafe usize acceptance_root_symbol(
    ref IrContext context,
    usize node
) {
    if node >= context.syntax.length { return context.symbols.length; }
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, node
    );
    if read_record_field(context.syntax_data, node, 0) == 27 { name = node; }
    if name >= context.syntax.length { return context.symbols.length; }
    usize start = read_record_field(context.syntax_data, name, 1);
    usize length = read_record_field(context.syntax_data, name, 2);
    usize root_length = 0;
    while root_length < length && byte_at_or_zero(
        context.source, start + root_length
    ) != 46 { root_length = root_length + 1; }
    if root_length < length {
        usize symbol = 0;
        while symbol < context.symbols.length {
            usize kind = read_record_field(context.symbol_data, symbol, 0);
            if (kind == resolution_symbol_variable() ||
                kind == resolution_symbol_parameter()) &&
                resolution_symbol_name_equals(
                    context.project_source, context.project_root,
                    context.source_data, context.symbol_data, symbol,
                    context.source, start, root_length
                ) { return symbol; }
            symbol = symbol + 1;
        }
    }
    return ir_resolve_name(context, name);
}

unsafe bool acceptance_destroy_between(
    ref IrContext context,
    usize symbol,
    usize after,
    usize before
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 45 {
            usize start = read_record_field(context.syntax_data, node, 1);
            if start > after && start < before &&
                acceptance_destroyed_symbol(context, node) == symbol {
                return true;
            }
        }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_symbol_used_after(
    ref IrContext context,
    usize symbol,
    usize after
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 27 &&
            read_record_field(context.syntax_data, node, 1) > after &&
            acceptance_root_symbol(context, node) == symbol {
            return true;
        }
        node = node + 1;
    }
    return false;
}

unsafe usize acceptance_validate_storage(ref IrContext context) {
    usize errors = 0;
    usize first = 0;
    while first < context.syntax.length {
        if read_record_field(context.syntax_data, first, 0) == 44 {
            usize first_storage = acceptance_construct_storage(context, first);
            usize first_result = acceptance_construct_result(context, first);
            usize second = first + 1;
            while second < context.syntax.length {
                if read_record_field(context.syntax_data, second, 0) == 44 &&
                    acceptance_construct_storage(context, second) ==
                        first_storage {
                    usize first_start = read_record_field(
                        context.syntax_data, first, 1
                    );
                    usize second_start = read_record_field(
                        context.syntax_data, second, 1
                    );
                    bool destroyed = acceptance_destroy_between(
                        context, first_result, first_start, second_start
                    );
                    if !destroyed { errors = errors + 1; }
                    else if acceptance_symbol_used_after(
                        context, first_result, second_start
                    ) { errors = errors + 1; }
                }
                second = second + 1;
            }
            if first_result < context.symbols.length &&
                !acceptance_destroy_between(
                    context, first_result,
                    read_record_field(context.syntax_data, first, 1),
                    read_record_field(context.syntax_data, first, 1) +
                        read_record_field(context.syntax_data, first, 2) +
                        text.byte_length(context.source)
                ) { errors = errors + 1; }
        }
        first = first + 1;
    }

    usize destroy_node = 0;
    while destroy_node < context.syntax.length {
        if read_record_field(context.syntax_data, destroy_node, 0) == 45 {
            usize destroyed_symbol = acceptance_destroyed_symbol(
                context, destroy_node
            );
            usize local = 0;
            while local < context.symbols.length {
                if read_record_field(context.symbol_data, local, 0) ==
                        resolution_symbol_variable() &&
                    read_record_field(context.symbol_data, local, 1) ==
                        context.source_record && acceptance_kind(
                            context,
                            read_record_field(context.symbol_data, local, 4)
                        ) == 12 {
                    usize initializer = flow_local_initializer_root(
                        context.syntax_data, context.syntax,
                        read_record_field(context.detail_data, local, 1)
                    );
                    if initializer < context.syntax.length &&
                        acceptance_root_symbol(context, initializer) == destroyed_symbol &&
                        acceptance_symbol_used_after(
                            context, local,
                            read_record_field(context.syntax_data, destroy_node, 1)
                        ) { errors = errors + 1; }
                }
                local = local + 1;
            }
        }
        destroy_node = destroy_node + 1;
    }
    return errors;
}

unsafe bool acceptance_inside_import(
    ref IrContext context,
    usize node
) {
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 1 &&
            semantic_node_contains(
                context.syntax_data, declaration, node
            ) { return true; }
        declaration = declaration + 1;
    }
    return false;
}

unsafe usize acceptance_last_segment(
    text source,
    usize start,
    usize length
) {
    usize segment = start;
    usize cursor = 0;
    while cursor < length {
        if byte_at_or_zero(source, start + cursor) == 46 {
            segment = start + cursor + 1;
        }
        cursor = cursor + 1;
    }
    return segment;
}

unsafe usize acceptance_import_alias_count(
    ref IrContext context,
    usize prefix_start,
    usize prefix_length
) {
    usize count = 0;
    usize first_name_start = 0;
    usize first_name_length = 0;
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 1 {
            usize name = 0;
            while name < context.syntax.length {
                if read_record_field(context.syntax_data, name, 0) == 27 &&
                    semantic_node_contains(
                        context.syntax_data, declaration, name
                    ) {
                    usize name_start = read_record_field(
                        context.syntax_data, name, 1
                    );
                    usize name_length = read_record_field(
                        context.syntax_data, name, 2
                    );
                    usize alias_start = acceptance_last_segment(
                        context.source, name_start, name_length
                    );
                    usize alias_length = name_start + name_length - alias_start;
                    if semantic_spans_equal(
                        context.source, prefix_start, prefix_length,
                        context.source, alias_start, alias_length
                    ) {
                        if count == 0 {
                            count = 1;
                            first_name_start = name_start;
                            first_name_length = name_length;
                        } else if !semantic_spans_equal(
                            context.source, first_name_start, first_name_length,
                            context.source, name_start, name_length
                        ) { count = count + 1; }
                    }
                    break;
                }
                name = name + 1;
            }
        }
        declaration = declaration + 1;
    }
    return count;
}

unsafe bool acceptance_builtin_alias(
    text source,
    usize start,
    usize length
) {
    return span_equals_ascii(source, start, length, "io") ||
        span_equals_ascii(source, start, length, "memory") ||
        span_equals_ascii(source, start, length, "text") ||
        span_equals_ascii(source, start, length, "file") ||
        span_equals_ascii(source, start, length, "path") ||
        span_equals_ascii(source, start, length, "process");
}

unsafe usize acceptance_validate_import_aliases(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 27 &&
            !acceptance_inside_import(context, node) {
            usize start = read_record_field(context.syntax_data, node, 1);
            usize length = read_record_field(context.syntax_data, node, 2);
            usize dot = 0;
            while dot < length && byte_at_or_zero(
                context.source, start + dot
            ) != 46 { dot = dot + 1; }
            if dot < length {
                usize aliases = acceptance_import_alias_count(
                    context, start, dot
                );
                if aliases > 1 || (aliases == 0 &&
                    acceptance_builtin_alias(context.source, start, dot)) {
                    errors = errors + 1;
                }
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe bool acceptance_same_prefix(
    ref IrContext context,
    usize left_start,
    usize left_length,
    usize right_start,
    usize right_length
) {
    return semantic_spans_equal(
        context.source, left_start, left_length,
        context.source, right_start, right_length
    );
}

unsafe usize acceptance_validate_optional_proofs(ref IrContext context) {
    usize errors = 0;
    usize if_node = 0;
    while if_node < context.syntax.length {
        if read_record_field(context.syntax_data, if_node, 0) == 14 {
            usize body = ir_direct_block(context, if_node, 0);
            if body < context.syntax.length {
                usize condition = ir_largest_expression_before(
                    context, if_node,
                    read_record_field(context.syntax_data, body, 1)
                );
                if condition < context.syntax.length {
                    usize condition_start = read_record_field(
                        context.syntax_data, condition, 1
                    );
                    usize condition_length = read_record_field(
                        context.syntax_data, condition, 2
                    );
                    usize dot = 0;
                    while dot < condition_length && byte_at_or_zero(
                        context.source, condition_start + dot
                    ) != 46 { dot = dot + 1; }
                    if dot < condition_length && span_equals_ascii(
                        context.source, condition_start + dot + 1,
                        condition_length - dot - 1, "present"
                    ) {
                        usize invalidated_at = 0;
                        usize assignment = 0;
                        while assignment < context.syntax.length {
                            if read_record_field(
                                context.syntax_data, assignment, 0
                            ) == 37 && semantic_node_contains(
                                context.syntax_data, body, assignment
                            ) {
                                usize left = resolution_left_expression(
                                    context.syntax_data, assignment,
                                    read_record_field(
                                        context.syntax_data, assignment, 3
                                    )
                                );
                                usize right = resolution_right_expression(
                                    context.syntax_data, assignment,
                                    read_record_field(
                                        context.syntax_data, assignment, 3
                                    ) + read_record_field(
                                        context.syntax_data, assignment, 4
                                    )
                                );
                                if left < context.syntax.length &&
                                    right < context.syntax.length &&
                                    read_record_field(
                                        context.syntax_data, right, 0
                                    ) == 34 && acceptance_same_prefix(
                                        context,
                                        read_record_field(
                                            context.syntax_data, left, 1
                                        ),
                                        read_record_field(
                                            context.syntax_data, left, 2
                                        ), condition_start, dot
                                    ) {
                                    invalidated_at = read_record_field(
                                        context.syntax_data, assignment, 1
                                    );
                                }
                            }
                            assignment = assignment + 1;
                        }
                        if invalidated_at != 0 {
                            usize name = 0;
                            while name < context.syntax.length {
                                if read_record_field(
                                    context.syntax_data, name, 0
                                ) == 27 && read_record_field(
                                    context.syntax_data, name, 1
                                ) > invalidated_at && semantic_node_contains(
                                    context.syntax_data, body, name
                                ) {
                                    usize name_start = read_record_field(
                                        context.syntax_data, name, 1
                                    );
                                    usize name_length = read_record_field(
                                        context.syntax_data, name, 2
                                    );
                                    if name_length == dot + 6 &&
                                        acceptance_same_prefix(
                                            context, name_start, dot,
                                            condition_start, dot
                                        ) && span_equals_ascii(
                                            context.source, name_start + dot,
                                            6, ".value"
                                        ) { errors = errors + 1; }
                                }
                                name = name + 1;
                            }
                        }
                    }
                }
            }
        }
        if_node = if_node + 1;
    }
    return errors;
}

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
                if read_record_field(context.syntax_data, field, 0) == 49 &&
                    semantic_node_contains(
                        context.syntax_data, initializer, field
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
                            ) { errors = errors + 1; }
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



unsafe usize acceptance_validate_context(ref IrContext context) {
    usize errors = 0;
    errors = errors + acceptance_validate_type_refs(context);
    errors = errors + acceptance_validate_fields(context);
    errors = errors + acceptance_validate_locals(context);
    errors = errors + acceptance_validate_assignments(context);
    errors = errors + acceptance_validate_binary(context);
    errors = errors + acceptance_validate_conditions(context);
    errors = errors + acceptance_validate_index_ranges(context);
    errors = errors + acceptance_validate_casts(context);
    errors = errors + acceptance_validate_aggregates(context);
    errors = errors + acceptance_validate_functions(context);
    errors = errors + acceptance_validate_scopes(context);
    errors = errors + acceptance_validate_enums(context);
    errors = errors + acceptance_validate_overload_calls(context);
    errors = errors + acceptance_validate_slice_aliases(context);
    errors = errors + acceptance_validate_calls(context);
    errors = errors + acceptance_validate_storage(context);
    errors = errors + acceptance_validate_import_aliases(context);
    errors = errors + acceptance_validate_optional_proofs(context);
    errors = errors + acceptance_validate_pointer_ownership(context);
    errors = errors + acceptance_validate_pointer_order(context);
    return errors;
}

unsafe usize acceptance_validate_project(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ref PackedBuffer sources,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols
) {
    usize errors = acceptance_validate_module_cycles(
        project_source, project_root,
        module_data, modules, source_data
    );
    bool checked_duplicates = false;
    usize module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            usize source_record = source_first + source_index;
            text source;
            status loaded = project_read_source_record(
                project_source, project_root, source_data,
                source_record, out source
            );
            if !loaded.ok { errors = errors + 1; source_index = source_index + 1; continue; }
            usize source_length = text.byte_length(source);
            PackedBuffer tokens = PackedBuffer{
                length = 0, capacity = source_length + 2
            };
            PackedBuffer diagnostics = PackedBuffer{
                length = 0, capacity = source_length * 4 + 8
            };
            ptr byte token_data = memory.alloc(
                tokens.capacity * record_stride()
            );
            ptr byte diagnostic_data = memory.alloc(
                diagnostics.capacity * record_stride()
            );
            lex_source(
                source, token_data, tokens, diagnostic_data, diagnostics
            );
            PackedBuffer syntax = PackedBuffer{
                length = 0, capacity = tokens.length * 6 + 8
            };
            ptr byte syntax_data = memory.alloc(
                syntax.capacity * record_stride()
            );
            parse_source_syntax(
                source, token_data, tokens,
                syntax_data, syntax, diagnostic_data, diagnostics
            );
            ptr byte scratch = memory.alloc(
                (symbols.length + syntax.length + 32) * size_of(usize)
            );
            usize symbol = 0;
            while symbol < symbols.length {
                write_usize(scratch, symbol * size_of(usize), 1);
                symbol = symbol + 1;
            }
            PackedBuffer empty = PackedBuffer{ length = 0, capacity = 0 };
            PackedBuffer modules_value = PackedBuffer{
                length = modules.length, capacity = modules.capacity
            };
            PackedBuffer types_value = PackedBuffer{
                length = types.length, capacity = types.capacity
            };
            PackedBuffer symbols_value = PackedBuffer{
                length = symbols.length, capacity = symbols.capacity
            };
            IrContext context = IrContext{
                project_source = project_source,
                project_root = project_root,
                source = source,
                module_data = ir_pointer_alias(module_data),
                modules = modules_value,
                source_data = ir_pointer_alias(source_data),
                type_data = ir_pointer_alias(type_data),
                types = types_value,
                symbol_data = ir_pointer_alias(symbol_data),
                detail_data = ir_pointer_alias(detail_data),
                symbols = symbols_value,
                token_data = ir_pointer_alias(token_data),
                tokens = tokens,
                syntax_data = ir_pointer_alias(syntax_data),
                syntax = syntax,
                module_index = module_index,
                source_record = source_record,
                function_node = 0,
                function_symbol = 0,
                function_result = semantic_type_void(),
                local_values = ir_pointer_alias(scratch),
                block_data = ir_pointer_alias(scratch),
                blocks = empty,
                instruction_data = ir_pointer_alias(scratch),
                instruction_detail = ir_pointer_alias(scratch),
                instructions = empty,
                operand_data = ir_pointer_alias(scratch),
                operands = empty,
                break_data = ir_pointer_alias(scratch),
                break_depth = 0,
                continue_data = ir_pointer_alias(scratch),
                continue_depth = 0,
                current_block = 0,
                next_value = 1
            };
            if !checked_duplicates {
                errors = errors + acceptance_validate_duplicate_functions(
                    context
                );
                checked_duplicates = true;
            }
            errors = errors + acceptance_validate_context(context);
            types = context.types;
            memory.free(scratch);
            memory.free(syntax_data);
            memory.free(diagnostic_data);
            memory.free(token_data);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    return errors;
}
