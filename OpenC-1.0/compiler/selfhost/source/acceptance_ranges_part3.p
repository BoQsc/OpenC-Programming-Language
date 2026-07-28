import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_import_alias_count(
    ref IrContext context,
    usize prefix_start,
    usize prefix_length
) {
    usize count = 0;
    usize first_name_start = 0;
    usize first_name_length = 0;
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 1 {
            usize name = 0;
            while name < context.syntax.length {
                if read_record_field(context.syntax_data, name, 0) == 27 &&
                    semantic_node_contains(
                        context.syntax_data, declaration, name
                    ) {
                    usize name_start = read_record_field(
                        context.syntax_data, name, 1
                    );
                    usize name_length = read_record_field(
                        context.syntax_data, name, 2
                    );
                    usize alias_start = acceptance_last_segment(
                        context.source, name_start, name_length
                    );
                    usize alias_length = name_start + name_length - alias_start;
                    if semantic_spans_equal(
                        context.source, prefix_start, prefix_length,
                        context.source, alias_start, alias_length
                    ) {
                        if count == 0 {
                            count = 1;
                            first_name_start = name_start;
                            first_name_length = name_length;
                        } else if !semantic_spans_equal(
                            context.source, first_name_start, first_name_length,
                            context.source, name_start, name_length
                        ) { count = count + 1; }
                    }
                    break;
                }
                name = name + 1;
            }
        }
        declaration = declaration + 1;
    }
    return count;
}

unsafe bool acceptance_builtin_alias(
    text source,
    usize start,
    usize length
) {
    return span_equals_ascii(source, start, length, "io") ||
        span_equals_ascii(source, start, length, "memory") ||
        span_equals_ascii(source, start, length, "text") ||
        span_equals_ascii(source, start, length, "file") ||
        span_equals_ascii(source, start, length, "path") ||
        span_equals_ascii(source, start, length, "process");
}

unsafe bool acceptance_value_shadows_builtin_alias(
    ref IrContext context,
    usize start,
    usize length
) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(
            context.symbol_data, symbol, 0
        );
        if (kind == resolution_symbol_parameter() ||
            kind == resolution_symbol_variable()) &&
            read_record_field(
                context.symbol_data, symbol, 1
            ) == context.source_record &&
            resolution_symbol_name_equals(
                context.project_source,
                context.project_root,
                context.source_data,
                context.symbol_data,
                symbol,
                context.source,
                start,
                length
            ) {
            return true;
        }
        symbol = symbol + 1;
    }
    return false;
}

unsafe usize acceptance_validate_import_aliases(ref IrContext context) {
    usize errors = 0;
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 27 &&
            !acceptance_inside_import(context, node) {
            usize start = read_record_field(context.syntax_data, node, 1);
            usize length = read_record_field(context.syntax_data, node, 2);
            usize dot = 0;
            while dot < length && byte_at_or_zero(
                context.source, start + dot
            ) != 46 { dot = dot + 1; }
            if dot < length {
                usize aliases = acceptance_import_alias_count(
                    context, start, dot
                );
                if aliases > 1 || (aliases == 0 &&
                    acceptance_builtin_alias(
                        context.source, start, dot
                    ) && !acceptance_value_shadows_builtin_alias(
                        context, start, dot
                    )) {
                    errors = errors + 1;
                }
            }
        }
        node = node + 1;
    }
    return errors;
}

unsafe bool acceptance_same_prefix(
    ref IrContext context,
    usize left_start,
    usize left_length,
    usize right_start,
    usize right_length
) {
    return semantic_spans_equal(
        context.source, left_start, left_length,
        context.source, right_start, right_length
    );
}

unsafe usize acceptance_validate_optional_proofs(ref IrContext context) {
    usize errors = 0;
    usize if_node = 0;
    while if_node < context.syntax.length {
        if read_record_field(context.syntax_data, if_node, 0) == 14 {
            usize body = ir_direct_block(context, if_node, 0);
            if body < context.syntax.length {
                usize condition = ir_largest_expression_before(
                    context, if_node,
                    read_record_field(context.syntax_data, body, 1)
                );
                if condition < context.syntax.length {
                    usize condition_start = read_record_field(
                        context.syntax_data, condition, 1
                    );
                    usize condition_length = read_record_field(
                        context.syntax_data, condition, 2
                    );
                    usize dot = 0;
                    while dot < condition_length && byte_at_or_zero(
                        context.source, condition_start + dot
                    ) != 46 { dot = dot + 1; }
                    if dot < condition_length && span_equals_ascii(
                        context.source, condition_start + dot + 1,
                        condition_length - dot - 1, "present"
                    ) {
                        usize invalidated_at = 0;
                        usize assignment = 0;
                        while assignment < context.syntax.length {
                            if read_record_field(
                                context.syntax_data, assignment, 0
                            ) == 37 && semantic_node_contains(
                                context.syntax_data, body, assignment
                            ) {
                                usize left = resolution_left_expression(
                                    context.syntax_data, assignment,
                                    read_record_field(
                                        context.syntax_data, assignment, 3
                                    )
                                );
                                usize right = resolution_right_expression(
                                    context.syntax_data, assignment,
                                    read_record_field(
                                        context.syntax_data, assignment, 3
                                    ) + read_record_field(
                                        context.syntax_data, assignment, 4
                                    )
                                );
                                if left < context.syntax.length &&
                                    right < context.syntax.length &&
                                    read_record_field(
                                        context.syntax_data, right, 0
                                    ) == 34 && acceptance_same_prefix(
                                        context,
                                        read_record_field(
                                            context.syntax_data, left, 1
                                        ),
                                        read_record_field(
                                            context.syntax_data, left, 2
                                        ), condition_start, dot
                                    ) {
                                    invalidated_at = read_record_field(
                                        context.syntax_data, assignment, 1
                                    );
                                }
                            }
                            assignment = assignment + 1;
                        }
                        if invalidated_at != 0 {
                            usize name = 0;
                            while name < context.syntax.length {
                                if read_record_field(
                                    context.syntax_data, name, 0
                                ) == 27 && read_record_field(
                                    context.syntax_data, name, 1
                                ) > invalidated_at && semantic_node_contains(
                                    context.syntax_data, body, name
                                ) {
                                    usize name_start = read_record_field(
                                        context.syntax_data, name, 1
                                    );
                                    usize name_length = read_record_field(
                                        context.syntax_data, name, 2
                                    );
                                    if name_length == dot + 6 &&
                                        acceptance_same_prefix(
                                            context, name_start, dot,
                                            condition_start, dot
                                        ) && span_equals_ascii(
                                            context.source, name_start + dot,
                                            6, ".value"
                                        ) { errors = errors + 1; }
                                }
                                name = name + 1;
                            }
                        }
                    }
                }
            }
        }
        if_node = if_node + 1;
    }
    return errors;
}
