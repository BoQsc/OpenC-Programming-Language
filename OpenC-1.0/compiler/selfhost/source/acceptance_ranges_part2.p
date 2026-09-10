import system.file;
import system.memory;
import system.text;

unsafe usize acceptance_construct_storage(
    ref IrContext context,
    usize construct_node
) {
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, construct_node
    );
    if name >= context.syntax.length { return context.symbols.length; }
    return ir_resolve_name(context, name);
}

unsafe usize acceptance_construct_result(
    ref IrContext context,
    usize construct_node
) {
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 12 &&
            semantic_node_contains(
                context.syntax_data, declaration, construct_node
            ) { return ir_local_symbol(context, declaration); }
        declaration = declaration + 1;
    }
    return context.symbols.length;
}

unsafe usize acceptance_destroyed_symbol(
    ref IrContext context,
    usize destroy_node
) {
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, destroy_node
    );
    if name >= context.syntax.length { return context.symbols.length; }
    return ir_resolve_name(context, name);
}

unsafe usize acceptance_root_symbol(
    ref IrContext context,
    usize node
) {
    if node >= context.syntax.length { return context.symbols.length; }
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, node
    );
    if read_record_field(context.syntax_data, node, 0) == 27 { name = node; }
    if name >= context.syntax.length { return context.symbols.length; }
    usize start = read_record_field(context.syntax_data, name, 1);
    usize length = read_record_field(context.syntax_data, name, 2);
    usize root_length = 0;
    while root_length < length && byte_at_or_zero(
        context.source, start + root_length
    ) != 46 { root_length = root_length + 1; }
    if root_length < length {
        usize symbol = 0;
        while symbol < context.symbols.length {
            usize kind = read_record_field(context.symbol_data, symbol, 0);
            if (kind == resolution_symbol_variable() ||
                kind == resolution_symbol_parameter()) &&
                resolution_symbol_name_equals(
                    context.project_source, context.project_root,
                    context.source_data, context.symbol_data, symbol,
                    context.source, start, root_length
                ) { return symbol; }
            symbol = symbol + 1;
        }
    }
    return ir_resolve_name(context, name);
}

unsafe bool acceptance_destroy_between(
    ref IrContext context,
    usize symbol,
    usize after,
    usize before
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 45 {
            usize start = read_record_field(context.syntax_data, node, 1);
            if start > after && start < before &&
                acceptance_destroyed_symbol(context, node) == symbol {
                return true;
            }
        }
        node = node + 1;
    }
    return false;
}

unsafe bool acceptance_symbol_used_after(
    ref IrContext context,
    usize symbol,
    usize after
) {
    usize node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 27 &&
            read_record_field(context.syntax_data, node, 1) > after &&
            acceptance_root_symbol(context, node) == symbol {
            return true;
        }
        node = node + 1;
    }
    return false;
}

unsafe usize acceptance_validate_storage(ref IrContext context) {
    usize errors = 0;
    usize first = 0;
    while first < context.syntax.length {
        if read_record_field(context.syntax_data, first, 0) == 44 {
            usize first_storage = acceptance_construct_storage(context, first);
            usize first_result = acceptance_construct_result(context, first);
            usize second = first + 1;
            while second < context.syntax.length {
                if read_record_field(context.syntax_data, second, 0) == 44 &&
                    acceptance_construct_storage(context, second) ==
                        first_storage {
                    usize first_start = read_record_field(
                        context.syntax_data, first, 1
                    );
                    usize second_start = read_record_field(
                        context.syntax_data, second, 1
                    );
                    bool destroyed = acceptance_destroy_between(
                        context, first_result, first_start, second_start
                    );
                    if !destroyed { errors = errors + 1; }
                    else if acceptance_symbol_used_after(
                        context, first_result, second_start
                    ) { errors = errors + 1; }
                }
                second = second + 1;
            }
            if first_result < context.symbols.length &&
                !acceptance_destroy_between(
                    context, first_result,
                    read_record_field(context.syntax_data, first, 1),
                    read_record_field(context.syntax_data, first, 1) +
                        read_record_field(context.syntax_data, first, 2) +
                        text.byte_length(context.source)
                ) { errors = errors + 1; }
        }
        first = first + 1;
    }

    usize destroy_node = 0;
    while destroy_node < context.syntax.length {
        if read_record_field(context.syntax_data, destroy_node, 0) == 45 {
            usize destroyed_symbol = acceptance_destroyed_symbol(
                context, destroy_node
            );
            usize local = acceptance_source_symbol_first(context);
            usize local_end = acceptance_source_symbol_end(context, local);
            while local < local_end {
                if read_record_field(context.symbol_data, local, 0) ==
                        resolution_symbol_variable() &&
                    read_record_field(context.symbol_data, local, 1) ==
                        context.source_record && acceptance_kind(
                            context,
                            read_record_field(context.symbol_data, local, 4)
                        ) == 12 {
                    usize initializer = ir_local_initializer_root(
                        context,
                        read_record_field(context.detail_data, local, 1)
                    );
                    if initializer < context.syntax.length &&
                        acceptance_root_symbol(context, initializer) == destroyed_symbol &&
                        acceptance_symbol_used_after(
                            context, local,
                            read_record_field(context.syntax_data, destroy_node, 1)
                        ) { errors = errors + 1; }
                }
                local = local + 1;
            }
        }
        destroy_node = destroy_node + 1;
    }
    return errors;
}

unsafe bool acceptance_inside_import(
    ref IrContext context,
    usize node,
    ptr byte import_data,
    usize import_count
) {
    usize index = 0;
    while index < import_count {
        usize declaration = read_usize(
            import_data, index * size_of(usize)
        );
        if semantic_node_contains(
            context.syntax_data, declaration, node
        ) { return true; }
        index = index + 1;
    }
    return false;
}

unsafe usize acceptance_last_segment(
    text source,
    usize start,
    usize length
) {
    usize segment = start;
    usize cursor = 0;
    while cursor < length {
        if byte_at_or_zero(source, start + cursor) == 46 {
            segment = start + cursor + 1;
        }
        cursor = cursor + 1;
    }
    return segment;
}
