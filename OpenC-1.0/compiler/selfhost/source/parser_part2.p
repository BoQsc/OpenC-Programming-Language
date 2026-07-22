import system.io;

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
