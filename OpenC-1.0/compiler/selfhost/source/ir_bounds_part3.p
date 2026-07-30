import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_token_before_block(
    ref IrContext context,
    usize block,
    text expected
) {
    usize block_start = read_record_field(context.syntax_data, block, 1);
    usize selected = context.tokens.length;
    usize token = 0;
    while token < context.tokens.length {
        usize start = read_record_field(context.token_data, token, 1);
        usize length = read_record_field(context.token_data, token, 2);
        if start < block_start && span_equals_ascii(
            context.source, start, length, expected
        ) { selected = token; }
        token = token + 1;
    }
    return selected;
}

unsafe usize ir_switch_subject(
    ref IrContext context,
    usize switch_node
) {
    usize start = read_record_field(context.syntax_data, switch_node, 1);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, start
    );
    while token < context.tokens.length && !span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "{"
    ) { token = token + 1; }
    if token >= context.tokens.length { return context.syntax.length; }
    return ir_root_in_bounds(
        context, start,
        read_record_field(context.token_data, token, 1)
    );
}

unsafe usize ir_switch_case_expression(
    ref IrContext context,
    usize block
) {
    usize token = ir_token_before_block(context, block, "case");
    if token >= context.tokens.length { return context.syntax.length; }
    usize after = read_record_field(context.token_data, token, 1) +
        read_record_field(context.token_data, token, 2);
    return ir_root_in_bounds(
        context, after,
        read_record_field(context.syntax_data, block, 1)
    );
}

unsafe usize ir_local_symbol(ref IrContext context, usize declaration) {
    usize found = ir_owner_symbol(
        context, declaration,
        resolution_symbol_variable(), resolution_symbol_parameter()
    );
    if found == 0 { return context.symbols.length; }
    return found - 1;
}

unsafe usize ir_type_element(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return semantic_type_error(); }
    return read_record_field(context.type_data, type_id, 1);
}

unsafe usize ir_keyword_length(
    ref IrContext context,
    usize node
) {
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    usize cursor = 0;
    while cursor < length && byte_at_or_zero(
        context.source, start + cursor
    ) != 40 { cursor = cursor + 1; }
    return cursor;
}

bool ir_intrinsic_call(text source, usize start, usize length) {
    return span_equals_ascii(source, start, length, "saturating_add") ||
        span_equals_ascii(source, start, length, "saturating_sub") ||
        span_equals_ascii(source, start, length, "saturating_mul");
}

bool ir_builtin_call(text source, usize start, usize length) {
    return starts_with_ascii(source, start, "io.") ||
        starts_with_ascii(source, start, "memory.") ||
        starts_with_ascii(source, start, "text.") ||
        starts_with_ascii(source, start, "process.") ||
        starts_with_ascii(source, start, "path.") ||
        starts_with_ascii(source, start, "file.");
}

unsafe bool ir_pointer_deref_fault(
    ref IrContext context,
    usize operand
) {
    if operand >= context.syntax.length { return false; }
    usize kind = read_record_field(context.syntax_data, operand, 0);
    if kind == 33 { return true; }
    usize name = ir_first_name(context, operand);
    if kind == 27 { name = operand; }
    if name >= context.syntax.length { return false; }
    usize symbol = ir_resolve_name(context, name);
    if symbol >= context.symbols.length { return false; }
    usize pointer_type = read_record_field(
        context.symbol_data, symbol, 4
    );
    usize declaration = read_record_field(
        context.detail_data, symbol, 1
    );
    usize initializer = flow_local_initializer_root(
        context.syntax_data, context.syntax, declaration
    );
    if initializer >= context.syntax.length { return false; }
    usize initializer_kind = read_record_field(
        context.syntax_data, initializer, 0
    );
    if pointer_type < context.types.length && read_record_field(
        context.type_data, pointer_type, 0
    ) == 13 && ir_type_element(
        context, pointer_type
    ) == semantic_type_byte() && initializer_kind == 43 { return false; }
    return initializer_kind == 33 || initializer_kind == 36 ||
        initializer_kind == 43;
}

unsafe bool ir_pointer_binary_fault(
    ref IrContext context,
    usize node,
    usize left_node,
    usize right_node
) {
    bool subtract = flow_node_operator(
        context.source, context.syntax_data, node, "-"
    );
    bool add = flow_node_operator(
        context.source, context.syntax_data, node, "+"
    );
    if !subtract && !add { return false; }
    usize left_type = ir_node_type(
        context, left_node, semantic_type_error()
    );
    usize right_type = ir_node_type(
        context, right_node, semantic_type_error()
    );
    if left_type >= context.types.length ||
        read_record_field(context.type_data, left_type, 0) != 13 {
        return false;
    }
    if add {
        ResolutionInteger amount = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, right_node, 1),
            read_record_field(context.syntax_data, right_node, 2)
        );
        usize left_name_add = ir_first_name(context, left_node);
        if read_record_field(context.syntax_data, left_node, 0) == 27 {
            left_name_add = left_node;
        }
        if !amount.valid || left_name_add >= context.syntax.length {
            return false;
        }
        usize function_start = read_record_field(
            context.syntax_data, context.function_node, 1
        );
        usize function_end = function_start + read_record_field(
            context.syntax_data, context.function_node, 2
        );
        usize scan = function_start;
        while scan + 13 < function_end {
            if starts_with_ascii(context.source, scan, "memory.alloc(") {
                usize number_cursor = scan + 13;
                while number_cursor < function_end && byte_at_or_zero(
                    context.source, number_cursor
                ) == 32 { number_cursor = number_cursor + 1; }
                usize allocation_size = 0;
                bool has_digit = false;
                while number_cursor < function_end {
                    usize digit = cast(usize, byte_at_or_zero(
                        context.source, number_cursor
                    ));
                    if digit < 48 || digit > 57 { break; }
                    allocation_size = allocation_size * 10 + digit - 48;
                    has_digit = true;
                    number_cursor = number_cursor + 1;
                }
                if has_digit && amount.value > cast(i64, allocation_size) {
                    return true;
                }
            }
            scan = scan + 1;
        }
        usize allocation_call = 0;
        while allocation_call < context.syntax.length {
            if read_record_field(
                context.syntax_data, allocation_call, 0
            ) == 38 && semantic_node_contains(
                context.syntax_data, context.function_node, allocation_call
            ) {
                usize allocation_callee = read_record_field(
                    context.syntax_data, allocation_call, 3
                );
                if allocation_callee < context.syntax.length &&
                    (span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, allocation_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, allocation_callee, 2
                        ), "memory.alloc"
                    ) || span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, allocation_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, allocation_callee, 2
                        ), "system.memory.alloc"
                    )) {
                    usize allocation_literal = ir_nth_child_kind(
                        context, allocation_call, 29, 0
                    );
                    if allocation_literal < context.syntax.length {
                        ResolutionInteger allocation_capacity =
                            resolution_parse_integer(
                                context.source,
                                read_record_field(
                                    context.syntax_data, allocation_literal, 1
                                ),
                                read_record_field(
                                    context.syntax_data, allocation_literal, 2
                                )
                            );
                        if allocation_capacity.valid &&
                            amount.value > allocation_capacity.value {
                            return true;
                        }
                    }
                }
            }
            allocation_call = allocation_call + 1;
        }
        usize left_symbol_add = ir_resolve_name(context, left_name_add);
        if left_symbol_add >= context.symbols.length { return false; }
        usize declaration = read_record_field(
            context.detail_data, left_symbol_add, 1
        );
        if !flow_span_contains_ascii(
            context.source,
            read_record_field(context.syntax_data, declaration, 1),
            read_record_field(context.syntax_data, declaration, 2),
            "memory.alloc"
        ) { return false; }
        usize literal = ir_nth_child_kind(context, declaration, 29, 0);
        if literal >= context.syntax.length { return false; }
        ResolutionInteger capacity = resolution_parse_integer(
            context.source,
            read_record_field(context.syntax_data, literal, 1),
            read_record_field(context.syntax_data, literal, 2)
        );
        return capacity.valid && amount.value > capacity.value;
    }
    if right_type >= context.types.length ||
        read_record_field(context.type_data, right_type, 0) != 13 {
        return false;
    }
    usize left_name = ir_first_name(context, left_node);
    usize right_name = ir_first_name(context, right_node);
    if read_record_field(context.syntax_data, left_node, 0) == 27 {
        left_name = left_node;
    }
    if read_record_field(context.syntax_data, right_node, 0) == 27 {
        right_name = right_node;
    }
    if left_name >= context.syntax.length ||
        right_name >= context.syntax.length { return false; }
    return ir_resolve_name(context, left_name) !=
        ir_resolve_name(context, right_name);
}
