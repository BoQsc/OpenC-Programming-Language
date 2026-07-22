import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
