import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
