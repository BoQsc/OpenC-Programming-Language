import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
