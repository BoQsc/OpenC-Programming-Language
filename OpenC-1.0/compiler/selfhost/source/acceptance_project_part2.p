import system.file;
import system.memory;
import system.text;

unsafe bool acceptance_module_imports(
    text project_source,
    text project_root,
    ptr byte module_data,
    ptr byte source_data,
    usize from_module,
    usize to_module
) {
    usize first = read_record_field(module_data, from_module, 2);
    usize count = read_record_field(module_data, from_module, 3);
    usize index = 0;
    while index < count {
        text source;
        status loaded = project_read_source_record(
            project_source, project_root, source_data, first + index,
            out source
        );
        if loaded.ok {
            if acceptance_source_imports(
                source, project_source,
                read_record_field(module_data, to_module, 0),
                read_record_field(module_data, to_module, 1)
            ) { return true; }
        }
        index = index + 1;
    }
    return false;
}

unsafe usize acceptance_validate_module_cycles(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data
) {
    usize errors = 0;
    usize left = 0;
    while left < modules.length {
        usize right = left + 1;
        while right < modules.length {
            if acceptance_module_imports(
                project_source, project_root, module_data, source_data,
                left, right
            ) && acceptance_module_imports(
                project_source, project_root, module_data, source_data,
                right, left
            ) { errors = errors + 1; }
            right = right + 1;
        }
        left = left + 1;
    }
    return errors;
}

unsafe usize acceptance_overload_candidate_count(
    ref IrContext context,
    usize callee
) {
    usize count = 0;
    usize symbol = 0;
    usize encoded = 0;
    bool indexed = context.function_bucket_heads != null &&
        context.function_bucket_next != null &&
        context.function_bucket_capacity != 0;
    if indexed {
        usize hash = ir_name_hash(
            context.source,
            read_record_field(context.syntax_data, callee, 1),
            read_record_field(context.syntax_data, callee, 2),
            context.module_index
        );
        encoded = read_usize(
            context.function_bucket_heads,
            (hash % context.function_bucket_capacity) * size_of(usize)
        );
    }
    while (indexed && encoded != 0) ||
        (!indexed && symbol < context.symbols.length) {
        usize candidate = symbol;
        if indexed { candidate = encoded - 1; }
        if read_record_field(context.symbol_data, candidate, 0) ==
                resolution_symbol_function() &&
            read_record_field(context.detail_data, candidate, 0) ==
                context.module_index &&
            resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data, candidate,
                context.source,
                read_record_field(context.syntax_data, callee, 1),
                read_record_field(context.syntax_data, callee, 2)
            ) && acceptance_parameter_count(context, candidate) == 1 {
            count = count + 1;
        }
        if indexed {
            encoded = read_usize(
                context.function_bucket_next,
                candidate * size_of(usize)
            );
        } else {
            symbol = symbol + 1;
        }
    }
    return count;
}

unsafe usize acceptance_validate_overload_calls(ref IrContext context) {
    usize errors = 0;
    usize call_index = 0;
    usize call_count = context.syntax.length;
    if context.expression_nodes != null {
        call_count = context.expression_count;
    }
    while call_index < call_count {
        usize call = call_index;
        if context.expression_nodes != null {
            call = read_usize(
                context.expression_nodes, call_index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, call, 0) == 38 &&
            read_record_field(context.syntax_data, call, 4) == 1 {
            usize callee = read_record_field(context.syntax_data, call, 3);
            if callee < context.syntax.length &&
                !flow_span_has_byte(
                    context.source,
                    read_record_field(context.syntax_data, callee, 1),
                    read_record_field(context.syntax_data, callee, 2), 46
                ) {
                if acceptance_overload_candidate_count(
                    context, callee
                ) > 1 {
                    IrBounds argument_bounds = ir_argument_bounds(
                        context, call, 0
                    );
                    if argument_bounds.valid {
                    usize argument = ir_root_in_bounds(
                        context, argument_bounds.start, argument_bounds.end
                    );
                    usize argument_type = ir_node_type(
                        context, argument, semantic_type_error()
                    );
                    if acceptance_integer(context, argument_type) {
                        usize exact = 0;
                        usize viable = 0;
                        usize symbol = 0;
                        usize encoded = 0;
                        bool indexed = context.function_bucket_heads != null &&
                            context.function_bucket_next != null &&
                            context.function_bucket_capacity != 0;
                        if indexed {
                            usize hash = ir_name_hash(
                                context.source,
                                read_record_field(
                                    context.syntax_data, callee, 1
                                ),
                                read_record_field(
                                    context.syntax_data, callee, 2
                                ), context.module_index
                            );
                            encoded = read_usize(
                                context.function_bucket_heads,
                                (hash % context.function_bucket_capacity) *
                                    size_of(usize)
                            );
                        }
                        while (indexed && encoded != 0) ||
                            (!indexed && symbol < context.symbols.length) {
                            usize candidate = symbol;
                            if indexed { candidate = encoded - 1; }
                            if read_record_field(
                                context.symbol_data, candidate, 0
                            ) == resolution_symbol_function() &&
                                read_record_field(
                                    context.detail_data, candidate, 0
                                ) == context.module_index &&
                                resolution_symbol_name_equals(
                                    context.project_source,
                                    context.project_root,
                                    context.source_data,
                                    context.symbol_data, candidate,
                                    context.source,
                                    read_record_field(
                                        context.syntax_data, callee, 1
                                    ),
                                    read_record_field(
                                        context.syntax_data, callee, 2
                                    )
                                ) && acceptance_parameter_count(
                                    context, candidate
                                ) == 1 {
                                    usize parameter = acceptance_parameter_at(
                                        context, candidate, 0
                                    );
                                usize parameter_type = read_record_field(
                                    context.symbol_data, parameter, 4
                                );
                                if parameter_type == argument_type {
                                    exact = exact + 1;
                                } else if acceptance_integer(
                                    context, parameter_type
                                ) && acceptance_bits(
                                    context, parameter_type
                                ) > acceptance_bits(context, argument_type) {
                                    viable = viable + 1;
                                }
                            }
                            if indexed {
                                encoded = read_usize(
                                    context.function_bucket_next,
                                    candidate * size_of(usize)
                                );
                            } else {
                                symbol = symbol + 1;
                            }
                        }
                        if exact == 0 && viable > 1 {
                            errors = errors + 1;
                        }
                    }
                    }
                }
            }
        }
        call_index = call_index + 1;
    }
    return errors;
}
