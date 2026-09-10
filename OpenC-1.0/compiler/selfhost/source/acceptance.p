import system.file;
import system.memory;
import system.text;

struct AcceptanceRange {
    bool valid;
    i64 lower;
    i64 upper;
}

unsafe usize acceptance_source_symbol_first(ref IrContext context) {
    usize symbol = 0;
    while symbol < context.symbols.length && read_record_field(
        context.symbol_data, symbol, 1
    ) != context.source_record {
        symbol = symbol + 1;
    }
    return symbol;
}

unsafe usize acceptance_source_symbol_end(
    ref IrContext context,
    usize first
) {
    usize symbol = first;
    while symbol < context.symbols.length && read_record_field(
        context.symbol_data, symbol, 1
    ) == context.source_record {
        symbol = symbol + 1;
    }
    return symbol;
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
    if expected_kind == 12 && acceptance_const_type(context, actual) &&
        !acceptance_const_type(context, expected) { return false; }
    if read_record_field(context.type_data, actual, 4) / 8 % 2 == 1 {
        usize preserved = read_record_field(context.type_data, actual, 1);
        if preserved != actual {
            return acceptance_lossless(context, preserved, expected);
        }
    }
    if read_record_field(context.type_data, expected, 4) / 8 % 2 == 1 {
        usize preserved = read_record_field(context.type_data, expected, 1);
        if preserved != expected {
            return acceptance_lossless(context, actual, preserved);
        }
    }
    if expected_kind == 12 {
        return acceptance_lossless(
            context, actual,
            read_record_field(context.type_data, expected, 1)
        );
    }
    if actual_kind == 12 {
        return acceptance_lossless(
            context,
            read_record_field(context.type_data, actual, 1), expected
        );
    }
    if actual_kind == 9 && expected_kind == 9 {
        return read_record_field(context.type_data, actual, 1) ==
                read_record_field(context.type_data, expected, 1) &&
            read_record_field(context.type_data, actual, 2) ==
                read_record_field(context.type_data, expected, 2) &&
            read_record_field(context.type_data, actual, 3) ==
                read_record_field(context.type_data, expected, 3);
    }
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
        usize child = ir_right_expression(
            context, node,
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
