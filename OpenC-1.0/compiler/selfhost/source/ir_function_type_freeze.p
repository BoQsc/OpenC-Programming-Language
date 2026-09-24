// This opt-in pass examines only indexed calls after acceptance. It interns
// address types that mode-2 lowering will need for non-address arguments to
// ref parameters. Other late constructors remain guarded by the per-function
// type-length assertion; this pass does not claim a complete closure.
unsafe bool ir_ref_argument_needs_address_type(
    ref IrContext context,
    usize node,
    usize actual_type
) {
    if node >= context.syntax.length ||
        actual_type == semantic_type_error() ||
        actual_type >= context.types.length { return false; }
    if read_record_field(context.type_data, actual_type, 0) == 13 {
        return false;
    }
    usize kind = read_record_field(context.syntax_data, node, 0);
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    bool direct_address = kind == 39 || kind == 40 ||
        (kind == 35 && flow_node_operator(
            context.source, context.syntax_data, node, "*"
        ));
    if kind == 27 && flow_span_has_byte(
        context.source, start, length, 46
    ) { direct_address = true; }
    if direct_address { return false; }
    if kind == 27 {
        usize local = ir_resolve_name(context, node);
        if local < context.symbols.length {
            usize local_type = read_record_field(
                context.symbol_data, local, 4
            );
            if local_type < context.types.length &&
                (read_record_field(context.type_data, local_type, 0) == 12 ||
                 read_record_field(context.detail_data, local, 3) == 1) {
                return false;
            }
        }
    }
    return true;
}

unsafe usize ir_prematerialize_ref_call_pointer_types(
    ref IrContext context
) {
    usize before = context.types.length;
    if context.call_nodes == null { return 0; }
    usize call_index = 0;
    while call_index < context.call_count {
        usize call = read_usize(
            context.call_nodes, call_index * size_of(usize)
        );
        if call < context.syntax.length {
            usize selected = ir_select_call(context, call);
            if selected < context.symbols.length {
                usize argument_count = read_record_field(
                    context.syntax_data, call, 4
                );
                usize argument = 0;
                while argument < argument_count {
                    usize parameter = ir_parameter_at(
                        context, selected, argument
                    );
                    if parameter < context.symbols.length {
                        usize expected = read_record_field(
                            context.symbol_data, parameter, 4
                        );
                        if expected < context.types.length &&
                            read_record_field(
                                context.type_data, expected, 0
                            ) == 12 {
                            usize child = ir_call_argument_node(
                                context, call, argument
                            );
                            if child >= context.syntax.length {
                                IrBounds bounds = ir_argument_bounds(
                                    context, call, argument
                                );
                                if bounds.valid {
                                    child = ir_root_in_bounds(
                                        context, bounds.start, bounds.end
                                    );
                                }
                            }
                            if child < context.syntax.length {
                                usize actual = ir_node_type(
                                    context, child, semantic_type_error()
                                );
                                if ir_ref_argument_needs_address_type(
                                    context, child, actual
                                ) {
                                    usize element = actual;
                                    if read_record_field(
                                        context.type_data, actual, 0
                                    ) == 12 {
                                        element = ir_type_element(
                                            context, actual
                                        );
                                    }
                                    semantic_derived_type(
                                        context.type_data, context.types,
                                        13, element, 0, false, false
                                    );
                                }
                            }
                        }
                    }
                    argument = argument + 1;
                }
            }
        }
        call_index = call_index + 1;
    }
    return context.types.length - before;
}
