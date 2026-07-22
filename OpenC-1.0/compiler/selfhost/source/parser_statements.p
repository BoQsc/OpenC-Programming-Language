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
