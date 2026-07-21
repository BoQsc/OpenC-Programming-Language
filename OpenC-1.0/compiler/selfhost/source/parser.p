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

unsafe bool parser_is_unsigned_integer(ref ParserContext context, usize token) {
    if token_matches(context, token, "u8") { return true; }
    if token_matches(context, token, "u16") { return true; }
    if token_matches(context, token, "u32") { return true; }
    return token_matches(context, token, "u64");
}

unsafe void parser_ensure_progress(
    ref ParserContext context,
    usize before
) {
    if context.cursor != before || parser_at_end(context) {
        return;
    }
    parser_error(context, 24, current_token(context));
    advance_token(context);
}

unsafe void parser_synchronize_top(ref ParserContext context) {
    while !parser_at_end(context) {
        if token_matches(context, previous_token(context), ";") ||
            token_matches(context, previous_token(context), "}") {
            return;
        }
        if parser_check(context, "export") ||
            parser_check(context, "struct") ||
            parser_check(context, "resource") ||
            parser_check(context, "enum") ||
            parser_check(context, "const") ||
            parser_check(context, "when") ||
            parser_check(context, "unsafe") ||
            parser_check(context, "void") {
            return;
        }
        advance_token(context);
    }
}

unsafe bool parser_looks_like_module_const(ref ParserContext context) {
    usize index = context.cursor + 1;
    while index < context.token_count &&
        !token_matches(context, index, ";") &&
        !token_matches(context, index, "{") {
        if token_matches(context, index, "=") { return true; }
        if token_matches(context, index, "(") { return false; }
        index = index + 1;
    }
    return false;
}

unsafe bool parser_looks_like_function(ref ParserContext context) {
    usize index = context.cursor;
    if token_matches(context, index, "unsafe") { index = index + 1; }
    if token_matches(context, index, "own") { index = index + 1; }
    i32 nesting = 0;
    while index + 1 < context.token_count {
        if token_matches(context, index, "[") ||
            token_matches(context, index, "(") {
            nesting = nesting + 1;
        }
        if token_matches(context, index, "]") ||
            token_matches(context, index, ")") {
            nesting = nesting - 1;
        }
        if nesting == 0 && token_kind(context, index) == 1 &&
            token_matches(context, index + 1, "(") {
            return true;
        }
        if nesting == 0 &&
            (token_matches(context, index, ";") ||
             token_matches(context, index, "{") ||
             token_matches(context, index, "=")) {
            return false;
        }
        index = index + 1;
    }
    return false;
}

unsafe NodeResult parse_import(ref ParserContext context, usize begin) {
    NodeResult name = parse_qualified_name(context);
    usize end = parser_expect(context, ";", 25);
    return make_node(
        context,
        1,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end),
            token_length(context, end)
        )
    );
}

unsafe NodeResult parse_field_declaration(
    ref ParserContext context,
    bool is_resource
) {
    usize start = token_start(context, current_token(context));
    if is_resource {
        parser_match(context, "own");
    }
    parse_type(context);
    usize name = parser_expect_identifier(context, 21);
    if parser_match(context, "=") {
        parse_constant_expression(context);
    }
    usize end = parser_expect(context, ";", 25);
    NodeResult node = make_node(
        context,
        9,
        start,
        combined_length(start, token_start(context, end), token_length(context, end))
    );
    set_node_name(context, node, name);
    return node;
}

unsafe NodeResult parse_aggregate_declaration(
    ref ParserContext context,
    usize kind,
    usize begin
) {
    usize name = parser_expect_identifier(context, 21);
    parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context,
        kind,
        token_start(context, begin),
        token_length(context, begin)
    );
    set_node_name(context, node, name);
    while !parser_at_end(context) && !parser_check(context, "}") {
        usize before = context.cursor;
        parse_field_declaration(context, kind == 4);
        parser_ensure_progress(context, before);
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context,
        node,
        token_start(context, begin),
        token_start(context, end),
        token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_enum_declaration(
    ref ParserContext context,
    usize begin
) {
    if parser_is_unsigned_integer(context, current_token(context)) &&
        token_kind(context, peek_token(context, 1)) == 1 {
        advance_token(context);
    }
    usize name = parser_expect_identifier(context, 21);
    parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context,
        5,
        token_start(context, begin),
        token_length(context, begin)
    );
    set_node_name(context, node, name);
    if !parser_check(context, "}") {
        bool more = true;
        while more {
            usize item = parser_expect_identifier(context, 21);
            NodeResult item_node = make_node(
                context, 6,
                token_start(context, item), token_length(context, item)
            );
            set_node_name(context, item_node, item);
            if parser_match(context, "=") {
                parse_constant_expression(context);
            }
            more = parser_match(context, ",") && !parser_check(context, "}");
        }
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node,
        token_start(context, begin),
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_when_declaration(
    ref ParserContext context,
    usize begin
) {
    parse_control_condition(context);
    parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context, 8,
        token_start(context, begin), token_length(context, begin)
    );
    while !parser_at_end(context) && !parser_check(context, "}") {
        usize before = context.cursor;
        NodeResult nested = parse_top_declaration(context);
        if nested.kind == 0 { parser_synchronize_top(context); }
        parser_ensure_progress(context, before);
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node,
        token_start(context, begin),
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_module_constant(ref ParserContext context) {
    usize begin = parser_expect(context, "const", 18);
    parse_type(context);
    usize name = parser_expect_identifier(context, 21);
    parser_expect(context, "=", 22);
    parse_constant_expression(context);
    usize end = parser_expect(context, ";", 25);
    NodeResult node = make_node(
        context, 7,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
    set_node_name(context, node, name);
    return node;
}

unsafe NodeResult parse_parameter(ref ParserContext context) {
    usize start = token_start(context, current_token(context));
    if parser_match(context, "out") {
        parser_match(context, "own");
    } else {
        parser_match(context, "own");
    }
    parse_type(context);
    usize name = parser_expect_identifier(context, 21);
    NodeResult node = make_node(
        context, 10, start,
        combined_length(start, token_start(context, name), token_length(context, name))
    );
    set_node_name(context, node, name);
    return node;
}

unsafe NodeResult parse_function_declaration(ref ParserContext context) {
    usize start_token = current_token(context);
    usize start = token_start(context, start_token);
    parser_match(context, "unsafe");
    parser_match(context, "own");
    if parser_match(context, "void") {
        usize value = previous_token(context);
        make_node(
            context, 26,
            token_start(context, value), token_length(context, value)
        );
    } else {
        parse_type(context);
    }
    usize name = parser_expect_identifier(context, 20);
    parser_expect(context, "(", 23);
    NodeResult node = make_node(
        context, 2, start, token_length(context, start_token)
    );
    set_node_name(context, node, name);
    if !parser_check(context, ")") {
        bool more = true;
        while more {
            parse_parameter(context);
            more = parser_match(context, ",");
        }
    }
    parser_expect(context, ")", 23);
    if parser_match(context, ";") {
        usize end = previous_token(context);
        make_node(
            context, 11,
            token_start(context, end), token_length(context, end)
        );
        set_node_combined(
            context, node, start,
            token_start(context, end), token_length(context, end)
        );
        return node;
    }
    context.function_depth = context.function_depth + 1;
    NodeResult body = parse_block(context);
    context.function_depth = context.function_depth - 1;
    set_node_combined(context, node, start, body.start, body.length);
    return node;
}

unsafe NodeResult parse_top_declaration(
    ref ParserContext context
) {
    usize start = token_start(context, current_token(context));
    parser_match(context, "export");
    NodeResult declaration = no_node();
    if parser_match(context, "struct") {
        declaration = parse_aggregate_declaration(
            context, 3, previous_token(context)
        );
    } else if parser_match(context, "resource") {
        declaration = parse_aggregate_declaration(
            context, 4, previous_token(context)
        );
    } else if parser_match(context, "enum") {
        declaration = parse_enum_declaration(context, previous_token(context));
    } else if parser_match(context, "when") {
        declaration = parse_when_declaration(context, previous_token(context));
    } else if parser_check(context, "const") &&
        parser_looks_like_module_const(context) {
        declaration = parse_module_constant(context);
    } else if parser_looks_like_function(context) {
        declaration = parse_function_declaration(context);
    } else {
        parser_error(context, 27, current_token(context));
        return declaration;
    }
    set_node_combined(
        context, declaration,
        start, declaration.start, declaration.length
    );
    return declaration;
}

unsafe NodeResult parse_type(ref ParserContext context) {
    usize start_token = current_token(context);
    usize start = token_start(context, start_token);
    bool leading_const = parser_match(context, "const");
    if parser_match(context, "ref") {
        parser_match(context, "const");
        if leading_const { parser_error(context, 28, start_token); }
    } else if parser_match(context, "ptr") {
        parser_match(context, "const");
        if leading_const { parser_error(context, 28, start_token); }
    } else if parser_match(context, "optional") {
    } else if parser_match(context, "storage") {
        if leading_const { parser_error(context, 28, start_token); }
    }
    NodeResult base = no_node();
    if token_kind(context, current_token(context)) == 5 &&
        parser_token_is_builtin_type(context, current_token(context)) {
        usize builtin = advance_token(context);
        base = make_node(
            context, 27,
            token_start(context, builtin), token_length(context, builtin)
        );
    } else {
        base = parse_qualified_name(context);
    }
    NodeResult node = make_node(
        context, 26, start,
        combined_length(start, base.start, base.length)
    );
    if parser_match(context, "[") {
        if !parser_match(context, "]") {
            parse_constant_expression(context);
            usize end = parser_expect(context, "]", 16);
            set_node_combined(
                context, node, start,
                token_start(context, end), token_length(context, end)
            );
        }
        if parser_check(context, "[") {
            parser_error(context, 29, current_token(context));
        }
    }
    return node;
}

unsafe bool parser_local_prefix(ref ParserContext context, usize token) {
    return token_matches(context, token, "const") ||
        token_matches(context, token, "ref") ||
        token_matches(context, token, "ptr") ||
        token_matches(context, token, "optional") ||
        token_matches(context, token, "storage");
}

unsafe bool parser_looks_like_local(ref ParserContext context) {
    usize index = context.cursor;
    if parser_local_prefix(context, index) { index = index + 1; }
    if index < context.token_count && token_matches(context, index, "const") {
        index = index + 1;
    }
    if index >= context.token_count ||
        !(token_kind(context, index) == 1 ||
          (token_kind(context, index) == 5 &&
           parser_token_is_builtin_type(context, index))) {
        return false;
    }
    index = index + 1;
    while index < context.token_count && token_matches(context, index, ".") {
        index = index + 2;
    }
    if index < context.token_count && token_matches(context, index, "[") {
        i32 depth = 1;
        index = index + 1;
        while index < context.token_count && depth != 0 {
            if token_matches(context, index, "[") { depth = depth + 1; }
            else if token_matches(context, index, "]") { depth = depth - 1; }
            index = index + 1;
        }
    }
    return index < context.token_count && token_kind(context, index) == 1;
}

unsafe NodeResult parse_local_declaration(ref ParserContext context) {
    usize start = token_start(context, current_token(context));
    parse_type(context);
    usize name = parser_expect_identifier(context, 21);
    if parser_match(context, "=") {
        parse_expression(context);
    }
    usize end = parser_expect(context, ";", 25);
    NodeResult node = make_node(
        context, 12, start,
        combined_length(start, token_start(context, end), token_length(context, end))
    );
    set_node_name(context, node, name);
    return node;
}

unsafe NodeResult parse_block(ref ParserContext context) {
    usize begin = parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context, 11,
        token_start(context, begin), token_length(context, begin)
    );
    while !parser_at_end(context) && !parser_check(context, "}") {
        usize before = context.cursor;
        if parser_looks_like_local(context) {
            parse_local_declaration(context);
        } else {
            parse_statement(context);
        }
        parser_ensure_progress(context, before);
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node,
        token_start(context, begin),
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_if_statement(
    ref ParserContext context,
    usize begin
) {
    parse_control_condition(context);
    NodeResult then_block = parse_block(context);
    NodeResult node = make_node(
        context, 14,
        token_start(context, begin), token_length(context, begin)
    );
    NodeResult last = then_block;
    if parser_match(context, "else") {
        if parser_check(context, "if") {
            advance_token(context);
            last = parse_if_statement(context, previous_token(context));
        } else {
            last = parse_block(context);
        }
    }
    set_node_combined(
        context, node,
        token_start(context, begin), last.start, last.length
    );
    return node;
}

unsafe NodeResult parse_while_statement(
    ref ParserContext context,
    usize begin
) {
    parse_control_condition(context);
    context.loop_depth = context.loop_depth + 1;
    NodeResult body = parse_block(context);
    context.loop_depth = context.loop_depth - 1;
    return make_node(
        context, 15,
        token_start(context, begin),
        combined_length(token_start(context, begin), body.start, body.length)
    );
}

unsafe NodeResult parse_for_statement(
    ref ParserContext context,
    usize begin
) {
    bool parenthesized = parser_match(context, "(");
    NodeResult node = make_node(
        context, 16,
        token_start(context, begin), token_length(context, begin)
    );
    if !parser_check(context, ";") {
        if parser_looks_like_local(context) {
            usize start = token_start(context, current_token(context));
            parse_type(context);
            usize name = parser_expect_identifier(context, 21);
            usize last = name;
            if parser_match(context, "=") {
                parse_expression(context);
                last = previous_token(context);
            }
            NodeResult local = make_node(
                context, 12, start,
                combined_length(
                    start, token_start(context, last), token_length(context, last)
                )
            );
            set_node_name(context, local, name);
        } else {
            parse_expression(context);
        }
    }
    parser_expect(context, ";", 25);
    if !parser_check(context, ";") { parse_expression(context); }
    parser_expect(context, ";", 25);
    if !(parenthesized && parser_check(context, ")")) &&
        !parser_check(context, "{") {
        parse_expression(context);
    }
    if parenthesized { parser_expect(context, ")", 23); }
    context.loop_depth = context.loop_depth + 1;
    NodeResult body = parse_block(context);
    context.loop_depth = context.loop_depth - 1;
    set_node_combined(
        context, node,
        token_start(context, begin), body.start, body.length
    );
    return node;
}

unsafe NodeResult parse_switch_statement(
    ref ParserContext context,
    usize begin
) {
    parse_control_condition(context);
    parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context, 17,
        token_start(context, begin), token_length(context, begin)
    );
    context.loop_depth = context.loop_depth + 1;
    while !parser_at_end(context) && !parser_check(context, "}") {
        if parser_match(context, "case") {
            parse_control_condition(context);
            NodeResult case_body = parse_block(context);
            usize case_begin = previous_token(context);
            make_node(
                context, 18,
                token_start(context, case_begin),
                combined_length(
                    token_start(context, case_begin),
                    case_body.start, case_body.length
                )
            );
        } else if parser_match(context, "default") {
            NodeResult default_body = parse_block(context);
            make_node(
                context, 19,
                default_body.start, default_body.length
            );
        } else {
            parser_error(context, 26, current_token(context));
            advance_token(context);
        }
    }
    context.loop_depth = context.loop_depth - 1;
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node,
        token_start(context, begin),
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_loop_control(
    ref ParserContext context,
    usize kind,
    usize begin
) {
    if context.loop_depth == 0 {
        parser_error(context, 12, begin);
    }
    usize end = parser_expect(context, ";", 25);
    return make_node(
        context, kind,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_return_statement(
    ref ParserContext context,
    usize begin
) {
    if !parser_check(context, ";") { parse_expression(context); }
    usize end = parser_expect(context, ";", 25);
    if context.function_depth == 0 { parser_error(context, 13, begin); }
    return make_node(
        context, 22,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_scope_statement(
    ref ParserContext context,
    usize begin
) {
    parse_expression(context);
    usize end = parser_expect(context, ";", 25);
    return make_node(
        context, 23,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_unsafe_statement(
    ref ParserContext context,
    usize begin
) {
    context.unsafe_depth = context.unsafe_depth + 1;
    NodeResult body = parse_block(context);
    context.unsafe_depth = context.unsafe_depth - 1;
    return make_node(
        context, 24,
        token_start(context, begin),
        combined_length(token_start(context, begin), body.start, body.length)
    );
}

unsafe NodeResult parse_when_statement(
    ref ParserContext context,
    usize begin
) {
    parse_control_condition(context);
    NodeResult body = parse_block(context);
    return make_node(
        context, 25,
        token_start(context, begin),
        combined_length(token_start(context, begin), body.start, body.length)
    );
}

unsafe NodeResult parse_statement(ref ParserContext context) {
    if parser_check(context, "{") { return parse_block(context); }
    if parser_match(context, "if") {
        return parse_if_statement(context, previous_token(context));
    }
    if parser_match(context, "while") {
        return parse_while_statement(context, previous_token(context));
    }
    if parser_match(context, "for") {
        return parse_for_statement(context, previous_token(context));
    }
    if parser_match(context, "switch") {
        return parse_switch_statement(context, previous_token(context));
    }
    if parser_match(context, "break") {
        return parse_loop_control(context, 20, previous_token(context));
    }
    if parser_match(context, "continue") {
        return parse_loop_control(context, 21, previous_token(context));
    }
    if parser_match(context, "return") {
        return parse_return_statement(context, previous_token(context));
    }
    if parser_match(context, "scope") {
        return parse_scope_statement(context, previous_token(context));
    }
    if parser_match(context, "unsafe") {
        return parse_unsafe_statement(context, previous_token(context));
    }
    if parser_match(context, "when") {
        return parse_when_statement(context, previous_token(context));
    }
    usize start = token_start(context, current_token(context));
    parse_expression(context);
    usize end = parser_expect(context, ";", 25);
    return make_node(
        context, 13, start,
        combined_length(start, token_start(context, end), token_length(context, end))
    );
}

unsafe bool parser_is_assignment_operator(ref ParserContext context) {
    if parser_check(context, "=") { return true; }
    if parser_check(context, "+=") { return true; }
    if parser_check(context, "-=") { return true; }
    if parser_check(context, "*=") { return true; }
    if parser_check(context, "/=") { return true; }
    if parser_check(context, "%=") { return true; }
    if parser_check(context, "&=") { return true; }
    if parser_check(context, "|=") { return true; }
    if parser_check(context, "^=") { return true; }
    if parser_check(context, "<<=") { return true; }
    return parser_check(context, ">>=");
}

unsafe bool parser_binary_operator(
    ref ParserContext context,
    usize level
) {
    if level == 1 {
        return parser_check(context, "*") || parser_check(context, "/") ||
            parser_check(context, "%");
    }
    if level == 2 {
        return parser_check(context, "+") || parser_check(context, "-");
    }
    if level == 3 {
        return parser_check(context, "<<") || parser_check(context, ">>");
    }
    if level == 4 {
        return parser_check(context, "<") || parser_check(context, "<=") ||
            parser_check(context, ">") || parser_check(context, ">=");
    }
    if level == 5 {
        return parser_check(context, "==") || parser_check(context, "!=");
    }
    if level == 6 { return parser_check(context, "&"); }
    if level == 7 { return parser_check(context, "^"); }
    if level == 8 { return parser_check(context, "|"); }
    if level == 9 { return parser_check(context, "&&"); }
    return parser_check(context, "||");
}

unsafe NodeResult parse_binary_level(
    ref ParserContext context,
    usize level
) {
    NodeResult expression = no_node();
    if level == 0 {
        return parse_unary(context);
    }
    expression = parse_binary_level(context, level - 1);
    while parser_binary_operator(context, level) {
        usize operator = advance_token(context);
        NodeResult right = parse_binary_level(context, level - 1);
        NodeResult combined = make_node(
            context, 36, expression.start,
            combined_length(expression.start, right.start, right.length)
        );
        set_node_name(context, combined, operator);
        expression = combined;
    }
    return expression;
}

unsafe NodeResult parse_logical_or(ref ParserContext context) {
    return parse_binary_level(context, 10);
}

unsafe NodeResult parse_assignment(ref ParserContext context) {
    NodeResult left = parse_logical_or(context);
    if parser_is_assignment_operator(context) {
        usize operator = advance_token(context);
        NodeResult right = parse_assignment(context);
        NodeResult assignment = make_node(
            context, 37, left.start,
            combined_length(left.start, right.start, right.length)
        );
        set_node_name(context, assignment, operator);
        return assignment;
    }
    return left;
}

unsafe NodeResult parse_expression(ref ParserContext context) {
    return parse_assignment(context);
}

unsafe NodeResult parse_constant_expression(ref ParserContext context) {
    return parse_logical_or(context);
}

unsafe NodeResult parse_control_condition(ref ParserContext context) {
    bool previous = context.allow_aggregate_initializer;
    context.allow_aggregate_initializer = false;
    NodeResult result = parse_expression(context);
    context.allow_aggregate_initializer = previous;
    return result;
}

unsafe bool parser_is_unary_operator(ref ParserContext context) {
    return parser_check(context, "!") || parser_check(context, "~") ||
        parser_check(context, "+") || parser_check(context, "-") ||
        parser_check(context, "&") || parser_check(context, "*");
}

unsafe NodeResult parse_typed_intrinsic(
    ref ParserContext context,
    usize kind,
    usize begin
) {
    parser_expect(context, "(", 23);
    parse_type(context);
    parser_expect(context, ",", 17);
    parse_expression(context);
    usize end = parser_expect(context, ")", 23);
    return make_node(
        context, kind,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_construct_expression(
    ref ParserContext context,
    usize begin
) {
    parser_expect(context, "(", 23);
    parse_expression(context);
    parser_expect(context, ",", 17);
    parse_expression(context);
    usize end = parser_expect(context, ")", 23);
    return make_node(
        context, 44,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_destroy_expression(
    ref ParserContext context,
    usize begin
) {
    parser_expect(context, "(", 23);
    parse_qualified_name(context);
    usize end = parser_expect(context, ")", 23);
    return make_node(
        context, 45,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_type_query(
    ref ParserContext context,
    usize begin
) {
    parser_expect(context, "(", 23);
    parse_type(context);
    usize end = parser_expect(context, ")", 23);
    return make_node(
        context, 46,
        token_start(context, begin),
        combined_length(
            token_start(context, begin),
            token_start(context, end), token_length(context, end)
        )
    );
}

unsafe NodeResult parse_status_initializer(ref ParserContext context) {
    usize begin = advance_token(context);
    parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context, 47,
        token_start(context, begin), token_length(context, begin)
    );
    if !parser_check(context, "}") {
        bool more = true;
        while more {
            usize field = parser_expect_identifier(context, 21);
            if !token_matches(context, field, "code") &&
                !token_matches(context, field, "message") {
                parser_error(context, 14, field);
            }
            NodeResult status_field = make_node(
                context, 49,
                token_start(context, field), token_length(context, field)
            );
            set_node_name(context, status_field, field);
            parser_expect(context, "=", 22);
            parse_expression(context);
            more = parser_match(context, ",") && !parser_check(context, "}");
        }
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node,
        token_start(context, begin),
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_aggregate_initializer(
    ref ParserContext context,
    NodeResult name
) {
    parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context, 48, name.start, name.length
    );
    if !parser_check(context, "}") {
        bool more = true;
        while more {
            bool owns = parser_match(context, "own");
            usize field = parser_expect_identifier(context, 21);
            parser_expect(context, "=", 22);
            NodeResult value = no_node();
            if owns { value = parse_qualified_name(context); }
            else { value = parse_expression(context); }
            NodeResult aggregate_field = make_node(
                context, 49,
                token_start(context, field),
                combined_length(
                    token_start(context, field), value.start, value.length
                )
            );
            set_node_name(context, aggregate_field, field);
            more = parser_match(context, ",") && !parser_check(context, "}");
        }
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node, name.start,
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_array_initializer(ref ParserContext context) {
    usize begin = parser_expect(context, "{", 15);
    NodeResult node = make_node(
        context, 50,
        token_start(context, begin), token_length(context, begin)
    );
    if !parser_check(context, "}") {
        bool more = true;
        while more {
            parse_expression(context);
            more = parser_match(context, ",") && !parser_check(context, "}");
        }
    }
    usize end = parser_expect(context, "}", 15);
    set_node_combined(
        context, node,
        token_start(context, begin),
        token_start(context, end), token_length(context, end)
    );
    return node;
}

unsafe NodeResult parse_primary(ref ParserContext context) {
    usize token = current_token(context);
    if parser_match(context, "(") {
        NodeResult expression = parse_expression(context);
        parser_expect(context, ")", 23);
        return expression;
    }
    usize kind = token_kind(context, token);
    if kind == 2 {
        advance_token(context);
        return make_node(
            context, 29,
            token_start(context, token), token_length(context, token)
        );
    }
    if kind == 3 {
        advance_token(context);
        return make_node(
            context, 30,
            token_start(context, token), token_length(context, token)
        );
    }
    if kind == 4 {
        advance_token(context);
        return make_node(
            context, 31,
            token_start(context, token), token_length(context, token)
        );
    }
    if parser_match(context, "true") || parser_match(context, "false") {
        usize value = previous_token(context);
        return make_node(
            context, 32,
            token_start(context, value), token_length(context, value)
        );
    }
    if parser_match(context, "null") {
        usize value = previous_token(context);
        return make_node(
            context, 33,
            token_start(context, value), token_length(context, value)
        );
    }
    if parser_match(context, "none") {
        usize value = previous_token(context);
        return make_node(
            context, 34,
            token_start(context, value), token_length(context, value)
        );
    }
    if parser_check(context, "status") &&
        token_matches(context, peek_token(context, 1), "{") {
        return parse_status_initializer(context);
    }
    if parser_check(context, "{") {
        return parse_array_initializer(context);
    }
    if kind == 1 || kind == 5 {
        NodeResult name = parse_qualified_name(context);
        if context.allow_aggregate_initializer && parser_check(context, "{") {
            return parse_aggregate_initializer(context, name);
        }
        return name;
    }
    parser_error(context, 19, current_token(context));
    advance_token(context);
    return make_node(
        context, 52,
        token_start(context, token), token_length(context, token)
    );
}

unsafe NodeResult parse_postfix(ref ParserContext context) {
    NodeResult expression = parse_primary(context);
    bool scanning = true;
    while scanning {
        if parser_match(context, "(") {
            NodeResult call = make_node(
                context, 38, expression.start, expression.length
            );
            write_record_field(context.syntax_data, call.record, 3, expression.record);
            usize argument_count = 0;
            if !parser_check(context, ")") {
                bool more = true;
                while more {
                    if parser_match(context, "out") {
                        usize name = parser_expect_identifier(context, 21);
                        make_node(
                            context, 51,
                            token_start(context, name), token_length(context, name)
                        );
                    } else {
                        parse_expression(context);
                    }
                    argument_count = argument_count + 1;
                    more = parser_match(context, ",");
                }
            }
            write_record_field(context.syntax_data, call.record, 4, argument_count);
            usize end = parser_expect(context, ")", 23);
            set_node_combined(
                context, call, expression.start,
                token_start(context, end), token_length(context, end)
            );
            expression = call;
        } else if parser_match(context, ".") {
            usize member = parser_expect_identifier(context, 21);
            NodeResult member_expression = make_node(
                context, 39, expression.start,
                combined_length(
                    expression.start,
                    token_start(context, member), token_length(context, member)
                )
            );
            set_node_name(context, member_expression, member);
            expression = member_expression;
        } else if parser_match(context, "[") {
            usize bracket = previous_token(context);
            if !parser_check(context, "..") && !parser_check(context, "]") {
                parse_expression(context);
            }
            if parser_match(context, "..") {
                if !parser_check(context, "]") { parse_expression(context); }
                usize end = parser_expect(context, "]", 16);
                NodeResult range_expression = make_node(
                    context, 41, expression.start,
                    combined_length(
                        expression.start,
                        token_start(context, end), token_length(context, end)
                    )
                );
                set_node_name(context, range_expression, bracket);
                expression = range_expression;
            } else {
                usize end = parser_expect(context, "]", 16);
                NodeResult index_expression = make_node(
                    context, 40, expression.start,
                    combined_length(
                        expression.start,
                        token_start(context, end), token_length(context, end)
                    )
                );
                set_node_name(context, index_expression, bracket);
                expression = index_expression;
            }
        } else {
            scanning = false;
        }
    }
    return expression;
}

unsafe NodeResult parse_unary(ref ParserContext context) {
    if parser_is_unary_operator(context) {
        usize begin = advance_token(context);
        NodeResult value = parse_unary(context);
        NodeResult node = make_node(
            context, 35,
            token_start(context, begin),
            combined_length(
                token_start(context, begin), value.start, value.length
            )
        );
        set_node_name(context, node, begin);
        return node;
    }
    if parser_match(context, "cast") {
        return parse_typed_intrinsic(context, 42, previous_token(context));
    }
    if parser_match(context, "cast_unchecked") {
        return parse_typed_intrinsic(context, 42, previous_token(context));
    }
    if parser_match(context, "reinterpret") {
        return parse_typed_intrinsic(context, 43, previous_token(context));
    }
    if parser_match(context, "construct") {
        return parse_construct_expression(context, previous_token(context));
    }
    if parser_match(context, "destroy") {
        return parse_destroy_expression(context, previous_token(context));
    }
    if parser_match(context, "size_of") || parser_match(context, "align_of") {
        return parse_type_query(context, previous_token(context));
    }
    return parse_postfix(context);
}

text syntax_kind_name(usize kind) {
    if kind == 0 { return "source_unit"; }
    if kind == 1 { return "import_decl"; }
    if kind == 2 { return "function_decl"; }
    if kind == 3 { return "struct_decl"; }
    if kind == 4 { return "resource_decl"; }
    if kind == 5 { return "enum_decl"; }
    if kind == 6 { return "enum_item"; }
    if kind == 7 { return "module_const_decl"; }
    if kind == 8 { return "when_decl"; }
    if kind == 9 { return "field_decl"; }
    if kind == 10 { return "parameter"; }
    if kind == 11 { return "block"; }
    if kind == 12 { return "local_decl"; }
    if kind == 13 { return "expression_stmt"; }
    if kind == 14 { return "if_stmt"; }
    if kind == 15 { return "while_stmt"; }
    if kind == 16 { return "for_stmt"; }
    if kind == 17 { return "switch_stmt"; }
    if kind == 18 { return "switch_case"; }
    if kind == 19 { return "default_case"; }
    if kind == 20 { return "break_stmt"; }
    if kind == 21 { return "continue_stmt"; }
    if kind == 22 { return "return_stmt"; }
    if kind == 23 { return "scope_stmt"; }
    if kind == 24 { return "unsafe_stmt"; }
    if kind == 25 { return "when_stmt"; }
    if kind == 26 { return "type_ref"; }
    if kind == 27 { return "qualified_name"; }
    if kind == 28 { return "identifier"; }
    if kind == 29 { return "integer_literal"; }
    if kind == 30 { return "float_literal"; }
    if kind == 31 { return "text_literal"; }
    if kind == 32 { return "bool_literal"; }
    if kind == 33 { return "null_literal"; }
    if kind == 34 { return "none_literal"; }
    if kind == 35 { return "unary_expr"; }
    if kind == 36 { return "binary_expr"; }
    if kind == 37 { return "assignment_expr"; }
    if kind == 38 { return "call_expr"; }
    if kind == 39 { return "member_expr"; }
    if kind == 40 { return "index_expr"; }
    if kind == 41 { return "range_expr"; }
    if kind == 42 { return "cast_expr"; }
    if kind == 43 { return "reinterpret_expr"; }
    if kind == 44 { return "construct_expr"; }
    if kind == 45 { return "destroy_expr"; }
    if kind == 46 { return "type_query_expr"; }
    if kind == 47 { return "status_initializer"; }
    if kind == 48 { return "aggregate_initializer"; }
    if kind == 49 { return "aggregate_field"; }
    if kind == 50 { return "array_initializer"; }
    if kind == 51 { return "out_argument"; }
    return "missing";
}

unsafe void emit_syntax_records(
    ptr byte data,
    ref PackedBuffer syntax
) {
    usize record = 0;
    while record < syntax.length {
        io.print("NODE ");
        io.print(syntax_kind_name(read_record_field(data, record, 0)));
        io.print(" ");
        io.print(read_record_field(data, record, 1));
        io.print(" ");
        io.println(read_record_field(data, record, 2));
        record = record + 1;
    }
}

unsafe NodeResult parse_source_syntax(
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    ptr byte diagnostic_data,
    ref PackedBuffer diagnostics
) {
    ParserContext context = ParserContext{
        source = source,
        token_data = token_data,
        token_count = tokens.length,
        syntax_data = syntax_data,
        syntax_length = syntax.length,
        syntax_capacity = syntax.capacity,
        diagnostic_data = diagnostic_data,
        diagnostic_length = diagnostics.length,
        diagnostic_capacity = diagnostics.capacity,
        cursor = 0,
        function_depth = 0,
        loop_depth = 0,
        unsafe_depth = 0,
        allow_aggregate_initializer = true
    };
    usize first = current_token(context);
    NodeResult root = make_node(
        context, 0,
        token_start(context, first), token_length(context, first)
    );
    while parser_match(context, "import") {
        parse_import(context, previous_token(context));
    }
    while !parser_at_end(context) {
        usize before = context.cursor;
        NodeResult declaration = parse_top_declaration(context);
        if declaration.kind == 0 { parser_synchronize_top(context); }
        parser_ensure_progress(context, before);
    }
    usize end = current_token(context);
    set_node_combined(
        context, root,
        token_start(context, first),
        token_start(context, end), token_length(context, end)
    );
    syntax.length = context.syntax_length;
    diagnostics.length = context.diagnostic_length;
    return root;
}
