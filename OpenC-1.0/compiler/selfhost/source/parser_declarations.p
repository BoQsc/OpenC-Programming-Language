import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
    if parser_match(context, "external") {
        parser_expect(context, "(", 23);
        parser_expect_identifier(context, 20);
        parser_expect(context, ",", 23);
        if token_kind(context, current_token(context)) == 4 {
            advance_token(context);
        } else {
            parser_error(context, 20, current_token(context));
        }
        parser_expect(context, ")", 23);
    }
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
    } else if parser_check(context, "external") ||
        parser_looks_like_function(context) {
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
