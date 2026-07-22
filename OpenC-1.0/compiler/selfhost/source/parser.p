import system.io;

struct NodeResult {
    usize record;
    usize kind;
    usize start;
    usize length;
}

struct ParserContext {
    text source;
    ptr byte token_data;
    usize token_count;
    ptr byte syntax_data;
    usize syntax_length;
    usize syntax_capacity;
    ptr byte diagnostic_data;
    usize diagnostic_length;
    usize diagnostic_capacity;
    usize cursor;
    usize function_depth;
    usize loop_depth;
    usize unsafe_depth;
    bool allow_aggregate_initializer;
}

NodeResult no_node() {
    return NodeResult{ record = 0, kind = 0, start = 0, length = 0 };
}

unsafe usize token_field(ref ParserContext context, usize token, usize field) {
    return read_record_field(context.token_data, token, field);
}

unsafe usize token_kind(ref ParserContext context, usize token) {
    return token_field(context, token, 0);
}

unsafe usize token_start(ref ParserContext context, usize token) {
    return token_field(context, token, 1);
}

unsafe usize token_length(ref ParserContext context, usize token) {
    return token_field(context, token, 2);
}

unsafe bool token_matches(
    ref ParserContext context,
    usize token,
    text expected
) {
    return span_equals_ascii(
        context.source,
        token_start(context, token),
        token_length(context, token),
        expected
    );
}

unsafe usize current_token(ref ParserContext context) {
    return context.cursor;
}

unsafe usize previous_token(ref ParserContext context) {
    if context.cursor == 0 {
        return 0;
    }
    return context.cursor - 1;
}

unsafe usize peek_token(ref ParserContext context, usize distance) {
    usize index = context.cursor + distance;
    if index < context.token_count {
        return index;
    }
    return context.token_count - 1;
}

unsafe bool parser_at_end(ref ParserContext context) {
    return token_kind(context, current_token(context)) == 0;
}

unsafe usize advance_token(ref ParserContext context) {
    if !parser_at_end(context) {
        context.cursor = context.cursor + 1;
    }
    return previous_token(context);
}

unsafe bool parser_check(ref ParserContext context, text expected) {
    return token_matches(context, current_token(context), expected);
}

unsafe bool parser_match(ref ParserContext context, text expected) {
    if !parser_check(context, expected) {
        return false;
    }
    advance_token(context);
    return true;
}

unsafe void parser_error(
    ref ParserContext context,
    usize rule,
    usize token
) {
    PackedBuffer diagnostics = PackedBuffer{
        length = context.diagnostic_length,
        capacity = context.diagnostic_capacity
    };
    report_error(
        context.diagnostic_data,
        diagnostics,
        rule,
        token_start(context, token),
        token_length(context, token)
    );
    context.diagnostic_length = diagnostics.length;
}

unsafe usize parser_expect(
    ref ParserContext context,
    text expected,
    usize rule
) {
    if parser_match(context, expected) {
        return previous_token(context);
    }
    parser_error(context, rule, current_token(context));
    return current_token(context);
}

unsafe usize parser_expect_identifier(ref ParserContext context, usize rule) {
    if token_kind(context, current_token(context)) == 1 {
        return advance_token(context);
    }
    parser_error(context, rule, current_token(context));
    return current_token(context);
}

unsafe NodeResult make_node(
    ref ParserContext context,
    usize kind,
    usize start,
    usize length
) {
    usize record = context.syntax_length;
    write_record_field(context.syntax_data, record, 0, kind);
    write_record_field(context.syntax_data, record, 1, start);
    write_record_field(context.syntax_data, record, 2, length);
    write_record_field(context.syntax_data, record, 3, 0);
    write_record_field(context.syntax_data, record, 4, 0);
    context.syntax_length = context.syntax_length + 1;
    return NodeResult{
        record = record,
        kind = kind,
        start = start,
        length = length
    };
}

unsafe void set_node_span(
    ref ParserContext context,
    ref NodeResult node,
    usize start,
    usize length
) {
    node.start = start;
    node.length = length;
    write_record_field(context.syntax_data, node.record, 1, start);
    write_record_field(context.syntax_data, node.record, 2, length);
}

unsafe void set_node_name(
    ref ParserContext context,
    ref NodeResult node,
    usize token
) {
    write_record_field(context.syntax_data, node.record, 3, token_start(context, token));
    write_record_field(context.syntax_data, node.record, 4, token_length(context, token));
}

usize combined_length(usize first_start, usize last_start, usize last_length) {
    usize finish = last_start + last_length;
    if finish >= first_start {
        return finish - first_start;
    }
    return last_length;
}

unsafe void set_node_combined(
    ref ParserContext context,
    ref NodeResult node,
    usize first_start,
    usize last_start,
    usize last_length
) {
    set_node_span(
        context,
        node,
        first_start,
        combined_length(first_start, last_start, last_length)
    );
}

bool parser_is_builtin_type(text source, usize start, usize length) {
    if span_equals_ascii(source, start, length, "void") { return true; }
    if span_equals_ascii(source, start, length, "i8") { return true; }
    if span_equals_ascii(source, start, length, "i16") { return true; }
    if span_equals_ascii(source, start, length, "i32") { return true; }
    if span_equals_ascii(source, start, length, "i64") { return true; }
    if span_equals_ascii(source, start, length, "u8") { return true; }
    if span_equals_ascii(source, start, length, "u16") { return true; }
    if span_equals_ascii(source, start, length, "u32") { return true; }
    if span_equals_ascii(source, start, length, "u64") { return true; }
    if span_equals_ascii(source, start, length, "isize") { return true; }
    if span_equals_ascii(source, start, length, "usize") { return true; }
    if span_equals_ascii(source, start, length, "bool") { return true; }
    if span_equals_ascii(source, start, length, "byte") { return true; }
    if span_equals_ascii(source, start, length, "f32") { return true; }
    if span_equals_ascii(source, start, length, "f64") { return true; }
    if span_equals_ascii(source, start, length, "text") { return true; }
    if span_equals_ascii(source, start, length, "status") { return true; }
    return false;
}

unsafe bool parser_token_is_builtin_type(
    ref ParserContext context,
    usize token
) {
    return parser_is_builtin_type(
        context.source,
        token_start(context, token),
        token_length(context, token)
    );
}

unsafe bool parser_is_name_part(ref ParserContext context, usize token) {
    usize kind = token_kind(context, token);
    return kind == 1 || (kind == 5 && parser_token_is_builtin_type(context, token));
}

unsafe usize parser_expect_name_part(ref ParserContext context) {
    if parser_is_name_part(context, current_token(context)) {
        return advance_token(context);
    }
    parser_error(context, 21, current_token(context));
    return current_token(context);
}

unsafe NodeResult parse_qualified_name(ref ParserContext context) {
    usize first = parser_expect_name_part(context);
    usize last = first;
    while parser_match(context, ".") {
        last = parser_expect_name_part(context);
    }
    return make_node(
        context,
        27,
        token_start(context, first),
        combined_length(
            token_start(context, first),
            token_start(context, last),
            token_length(context, last)
        )
    );
}
