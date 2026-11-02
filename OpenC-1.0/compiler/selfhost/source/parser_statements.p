import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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

unsafe usize parser_binary_precedence(ref ParserContext context) {
    usize token = current_token(context);
    if token_kind(context, token) != 6 { return 0; }
    usize length = token_length(context, token);
    if length == 0 || length > 2 { return 0; }
    usize start = token_start(context, token);
    u8 first = text.byte_at_unchecked(context.source, start);
    if length == 1 {
        if first == 42 || first == 47 || first == 37 { return 10; }
        if first == 43 || first == 45 { return 9; }
        if first == 60 || first == 62 { return 7; }
        if first == 38 { return 5; }
        if first == 94 { return 4; }
        if first == 124 { return 3; }
        return 0;
    }
    u8 second = text.byte_at_unchecked(context.source, start + 1);
    if (first == 60 && second == 60) ||
        (first == 62 && second == 62) { return 8; }
    if (first == 60 || first == 62) && second == 61 { return 7; }
    if (first == 61 || first == 33) && second == 61 { return 6; }
    if first == 38 && second == 38 { return 2; }
    if first == 124 && second == 124 { return 1; }
    return 0;
}

unsafe NodeResult parse_binary_climbing(
    ref ParserContext context,
    usize minimum_precedence
) {
    NodeResult expression = parse_unary(context);
    while true {
        usize precedence = parser_binary_precedence(context);
        if precedence < minimum_precedence || precedence == 0 { break; }
        usize operator = advance_token(context);
        NodeResult right = parse_binary_climbing(context, precedence + 1);
        NodeResult combined = make_node(
            context, 36, expression.start,
            combined_length(expression.start, right.start, right.length)
        );
        set_node_name(context, combined, operator);
        expression = combined;
    }
    return expression;
}
