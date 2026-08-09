import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_call_range(
    ref IrContext context,
    usize node,
    usize expected,
    usize kind,
    usize start,
    usize length,
    usize type_id
) {
    if kind == 38 {
        usize selected = ir_select_call(context, node);
        usize argument_count = read_record_field(context.syntax_data, node, 4);
        ptr byte argument_values = memory.alloc(
            (argument_count + 1) * size_of(usize)
        );
        usize argument = 0;
        while argument < argument_count {
            usize child = ir_call_argument_node(
                context, node, argument
            );
            if child >= context.syntax.length {
                IrBounds argument_bounds = ir_argument_bounds(
                    context, node, argument
                );
                if argument_bounds.valid {
                    child = ir_root_in_bounds(
                        context,
                        argument_bounds.start, argument_bounds.end
                    );
                }
            }
            if child < context.syntax.length {
                usize argument_expected = semantic_type_error();
                if selected < context.symbols.length {
                    usize parameter = ir_parameter_at(
                        context, selected, argument
                    );
                    if parameter < context.symbols.length {
                        argument_expected = read_record_field(
                            context.symbol_data, parameter, 4
                        );
                    }
                }
                usize builtin_callee = read_record_field(
                    context.syntax_data, node, 3
                );
                if builtin_callee < context.syntax.length && argument == 0 &&
                    (span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, builtin_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, builtin_callee, 2
                        ), "process.argument"
                    ) || span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, builtin_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, builtin_callee, 2
                        ), "system.process.argument"
                    )) {
                    argument_expected = semantic_builtin_type("usize", 0, 5);
                }
                if builtin_callee < context.syntax.length && argument == 0 &&
                    (span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, builtin_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, builtin_callee, 2
                        ), "memory.alloc"
                    ) || span_equals_ascii(
                        context.source,
                        read_record_field(
                            context.syntax_data, builtin_callee, 1
                        ),
                        read_record_field(
                            context.syntax_data, builtin_callee, 2
                        ), "system.memory.alloc"
                    )) {
                    argument_expected = semantic_builtin_type("usize", 0, 5);
                }
                usize value = 0;
                if argument_expected < context.types.length &&
                    read_record_field(
                        context.type_data, argument_expected, 0
                    ) == 12 {
                    value = ir_lower_node(
                        context, child, semantic_type_error(), 2
                    );
                } else {
                    value = ir_lower_node(
                        context, child, argument_expected, 0
                    );
                }
                write_usize(
                    argument_values, argument * size_of(usize), value
                );
            } else {
                write_usize(
                    argument_values, argument * size_of(usize), 0
                );
            }
            argument = argument + 1;
        }
        usize first = context.operands.length;
        argument = 0;
        while argument < argument_count {
            ir_operand_empty(context, read_usize(
                argument_values, argument * size_of(usize)
            ));
            argument = argument + 1;
        }
        memory.free(argument_values);
        usize text_kind = 1;
        usize text_one = start;
        usize text_two = length;
        if selected < context.symbols.length {
            text_kind = 3;
            text_one = selected;
            text_two = 0;
        } else {
            usize callee = read_record_field(context.syntax_data, node, 3);
            if callee < context.syntax.length {
                text_one = read_record_field(context.syntax_data, callee, 1);
                text_two = read_record_field(context.syntax_data, callee, 2);
            }
        }
        usize call_callee = read_record_field(context.syntax_data, node, 3);
        if call_callee < context.syntax.length {
            usize call_start = read_record_field(
                context.syntax_data, call_callee, 1
            );
            usize call_length = read_record_field(
                context.syntax_data, call_callee, 2
            );
            if selected >= context.symbols.length && ir_builtin_call(
                context.source, call_start, call_length
            ) {
                text_kind = 7;
                text_one = call_start;
                text_two = call_length;
            } else if selected >= context.symbols.length && ir_intrinsic_call(
                context.source, call_start, call_length
            ) {
                usize intrinsic_symbol = ir_find_top_unqualified(
                    context, context.module_index,
                    call_start, call_length
                );
                if intrinsic_symbol < context.symbols.length &&
                    read_record_field(
                        context.symbol_data, intrinsic_symbol, 0
                    ) != resolution_symbol_function() {
                    intrinsic_symbol = context.symbols.length;
                }
                if intrinsic_symbol >= context.symbols.length {
                    usize intrinsic_candidate = 0;
                    while intrinsic_candidate < context.symbols.length {
                        if read_record_field(
                            context.symbol_data, intrinsic_candidate, 0
                        ) == resolution_symbol_function() &&
                            read_record_field(
                                context.detail_data, intrinsic_candidate, 0
                            ) == context.module_index &&
                            read_record_field(
                                context.detail_data, intrinsic_candidate, 2
                            ) == 0 && resolution_symbol_name_equals(
                                context.project_source, context.project_root,
                                context.source_data, context.symbol_data,
                                intrinsic_candidate, context.source,
                                call_start, call_length
                            ) {
                            intrinsic_symbol = intrinsic_candidate;
                            break;
                        }
                        intrinsic_candidate = intrinsic_candidate + 1;
                    }
                }
                if intrinsic_symbol < context.symbols.length {
                    text_kind = 3;
                    text_one = intrinsic_symbol;
                    text_two = 0;
                } else {
                    text_kind = 8;
                    text_one = call_start;
                    text_two = call_length;
                }
            }
        }
        return ir_emit_value(
            context, ir_op_call(), type_id, node,
            text_kind, text_one, text_two,
            first, context.operands.length - first
        );
    }
    if kind == 39 {
        usize member_start = read_record_field(context.syntax_data, node, 3);
        usize base_node = ir_left_expression(
            context, node, member_start
        );
        usize base = ir_lower_node(
            context, base_node, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, base);
        return ir_emit_value(
            context, ir_op_aggregate_field(), type_id, node,
            1, member_start,
            read_record_field(context.syntax_data, node, 4), first, 1
        );
    }
    if kind == 40 {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize base_node = ir_left_expression(
            context, node, operator_start
        );
        usize index_node = ir_root_in_bounds(
            context, operator_start + 1, start + length - 1
        );
        usize base = ir_lower_node(
            context, base_node, semantic_type_error(), 0
        );
        usize index = ir_lower_node(
            context, index_node, semantic_type_error(), 0
        );
        usize first = context.operands.length;
        ir_operand_empty(context, base);
        ir_operand_empty(context, index);
        ir_emit_void(context, ir_op_bounds(), node, 0, 0, 0, first, 2);
        first = context.operands.length;
        ir_operand_empty(context, base);
        ir_operand_empty(context, index);
        return ir_emit_value(
            context, ir_op_aggregate_field(), type_id, node,
            2, 3, 0, first, 2
        );
    }
    if kind == 41 {
        usize bracket_start = read_record_field(
            context.syntax_data, node, 3
        );
        usize base_node = ir_left_expression(
            context, node, bracket_start
        );
        usize dots_start = start + length;
        usize close_start = start + length;
        usize token = semantic_token_at_or_after(
            context.token_data, context.tokens, bracket_start
        );
        while token < context.tokens.length && read_record_field(
            context.token_data, token, 1
        ) < start + length {
            usize token_start_value = read_record_field(
                context.token_data, token, 1
            );
            usize token_length_value = read_record_field(
                context.token_data, token, 2
            );
            if span_equals_ascii(
                context.source, token_start_value, token_length_value, ".."
            ) { dots_start = token_start_value; }
            if span_equals_ascii(
                context.source, token_start_value, token_length_value, "]"
            ) { close_start = token_start_value; }
            token = token + 1;
        }
        usize lower_node = ir_root_in_bounds(
            context, bracket_start + 1, dots_start
        );
        usize upper_node = ir_root_in_bounds(
            context, dots_start + 2, close_start
        );
        usize base_value = ir_lower_node(
            context, base_node, semantic_type_error(), 0
        );
        usize lower_value = 0;
        if lower_node < context.syntax.length {
            lower_value = ir_lower_node(
                context, lower_node, semantic_type_error(), 0
            );
        }
        usize upper_value = 0;
        if upper_node < context.syntax.length {
            upper_value = ir_lower_node(
                context, upper_node, semantic_type_error(), 0
            );
        }
        usize first = context.operands.length;
        ir_operand_empty(context, base_value);
        usize range_count = 1;
        if lower_node < context.syntax.length {
            ir_operand_empty(context, lower_value);
            range_count = range_count + 1;
        }
        if upper_node < context.syntax.length {
            ir_operand_empty(context, upper_value);
            range_count = range_count + 1;
        }
        return ir_emit_value(
            context, ir_op_slice_create(), type_id, node,
            2, 5, 0, first, range_count
        );
    }
    return 0;
}
