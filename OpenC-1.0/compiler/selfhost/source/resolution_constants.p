import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe ResolutionConstant resolution_evaluate_expression(
    text source,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize record,
    ptr byte error_data,
    ref PackedBuffer errors,
    usize source_record
) {
    ResolutionConstant result = ResolutionConstant{
        valid = false, kind = 0, type_id = semantic_type_error(),
        signed_value = 0, bool_value = false,
        value_start = 0, value_length = 0,
        start = read_record_field(syntax_data, record, 1),
        length = read_record_field(syntax_data, record, 2)
    };
    usize kind = read_record_field(syntax_data, record, 0);
    if kind == 29 {
        ResolutionInteger parsed_integer = resolution_parse_integer(
            source, result.start, result.length
        );
        if !parsed_integer.valid { return result; }
        i64 value = parsed_integer.value;
        result.valid = true;
        result.kind = 1;
        result.type_id = semantic_builtin_type("i64", 0, 3);
        if value <= cast(i64, 2147483647) {
            result.type_id = semantic_builtin_type("i32", 0, 3);
        }
        result.signed_value = value;
        return result;
    }
    if kind == 30 {
        result.valid = true;
        result.kind = 4;
        result.type_id = semantic_builtin_type("f64", 0, 3);
        result.value_start = result.start;
        result.value_length = result.length;
        return result;
    }
    if kind == 31 {
        result.valid = true;
        result.kind = 3;
        result.type_id = semantic_type_text();
        if result.length >= 2 {
            result.value_start = result.start + 1;
            result.value_length = result.length - 2;
        }
        return result;
    }
    if kind == 32 {
        result.valid = true;
        result.kind = 2;
        result.type_id = semantic_type_bool();
        result.bool_value = span_equals_ascii(
            source, result.start, result.length, "true"
        );
        return result;
    }
    if kind == 35 {
        usize operator_start = read_record_field(syntax_data, record, 3);
        usize operator_length = read_record_field(syntax_data, record, 4);
        usize operand = resolution_right_expression(
            syntax_data, record, operator_start + operator_length
        );
        if operand == record { return result; }
        result = resolution_evaluate_expression(
            source, syntax_data, syntax, operand,
            error_data, errors, source_record
        );
        result.start = read_record_field(syntax_data, record, 1);
        result.length = read_record_field(syntax_data, record, 2);
        if !result.valid { return result; }
        if span_equals_ascii(source, operator_start, operator_length, "!") {
            if result.kind != 2 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.bool_value = !result.bool_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "-") {
            if result.kind != 1 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.signed_value = -result.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "~") {
            if result.kind != 1 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.signed_value = ~result.signed_value;
        }
        return result;
    }
    if kind == 36 {
        usize operator_start = read_record_field(syntax_data, record, 3);
        usize operator_length = read_record_field(syntax_data, record, 4);
        usize left_record = resolution_left_expression(
            syntax_data, record, operator_start
        );
        usize right_record = resolution_right_expression(
            syntax_data, record, operator_start + operator_length
        );
        if left_record == record || right_record == record { return result; }
        ResolutionConstant left = resolution_evaluate_expression(
            source, syntax_data, syntax, left_record,
            error_data, errors, source_record
        );
        ResolutionConstant right = resolution_evaluate_expression(
            source, syntax_data, syntax, right_record,
            error_data, errors, source_record
        );
        result.valid = left.valid && right.valid;
        if !result.valid { return result; }
        bool logical = span_equals_ascii(source, operator_start, operator_length, "&&") ||
            span_equals_ascii(source, operator_start, operator_length, "||");
        bool comparison = span_equals_ascii(source, operator_start, operator_length, "==") ||
            span_equals_ascii(source, operator_start, operator_length, "!=") ||
            span_equals_ascii(source, operator_start, operator_length, "<") ||
            span_equals_ascii(source, operator_start, operator_length, "<=") ||
            span_equals_ascii(source, operator_start, operator_length, ">") ||
            span_equals_ascii(source, operator_start, operator_length, ">=");
        if logical {
            if left.kind != 2 || right.kind != 2 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.kind = 2;
            result.type_id = semantic_type_bool();
            if span_equals_ascii(source, operator_start, operator_length, "&&") {
                result.bool_value = left.bool_value && right.bool_value;
            } else { result.bool_value = left.bool_value || right.bool_value; }
            return result;
        }
        if left.kind != 1 || right.kind != 1 {
            semantic_record_error(
                error_data, errors, source_record,
                result.start, result.length, 8
            );
            result.valid = false;
            return result;
        }
        if comparison {
            result.kind = 2;
            result.type_id = semantic_type_bool();
            if span_equals_ascii(source, operator_start, operator_length, "==") {
                result.bool_value = left.signed_value == right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, "!=") {
                result.bool_value = left.signed_value != right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, "<") {
                result.bool_value = left.signed_value < right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, "<=") {
                result.bool_value = left.signed_value <= right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, ">") {
                result.bool_value = left.signed_value > right.signed_value;
            } else { result.bool_value = left.signed_value >= right.signed_value; }
            return result;
        }
        result.kind = 1;
        result.type_id = left.type_id;
        if span_equals_ascii(source, operator_start, operator_length, "+") {
            result.signed_value = left.signed_value + right.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "-") {
            result.signed_value = left.signed_value - right.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "*") {
            result.signed_value = left.signed_value * right.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "/") ||
            span_equals_ascii(source, operator_start, operator_length, "%") {
            if right.signed_value == 0 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 5
                );
                result.valid = false;
                return result;
            }
            if span_equals_ascii(source, operator_start, operator_length, "/") {
                result.signed_value = left.signed_value / right.signed_value;
            } else { result.signed_value = left.signed_value % right.signed_value; }
        } else if span_equals_ascii(source, operator_start, operator_length, "<<") ||
            span_equals_ascii(source, operator_start, operator_length, ">>") {
            if right.signed_value < 0 || right.signed_value >= 64 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 6
                );
                result.valid = false;
                return result;
            }
            if span_equals_ascii(source, operator_start, operator_length, "<<") {
                result.signed_value = left.signed_value << right.signed_value;
            } else {
                result.signed_value = left.signed_value >> right.signed_value;
            }
        } else if span_equals_ascii(source, operator_start, operator_length, "&") {
            result.signed_value = cast(i64,
                cast(u64, left.signed_value) & cast(u64, right.signed_value)
            );
        } else if span_equals_ascii(source, operator_start, operator_length, "|") {
            result.signed_value = cast(i64,
                cast(u64, left.signed_value) | cast(u64, right.signed_value)
            );
        } else if span_equals_ascii(source, operator_start, operator_length, "^") {
            result.signed_value = cast(i64,
                cast(u64, left.signed_value) ^ cast(u64, right.signed_value)
            );
        } else { result.valid = false; }
        return result;
    }
    if kind == 46 {
        usize type_node = resolution_smallest_parent(
            syntax_data, syntax, record, 0, 0, 0
        );
        type_node = type_node;
    }
    return result;
}
