import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool ir_indexed_symbol_name_equals(
    ref IrContext context,
    usize symbol,
    usize start,
    usize length
) {
    if read_record_field(
        context.symbol_data, symbol, 1
    ) == context.source_record {
        return semantic_spans_equal(
            context.source, start, length,
            context.source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)
        );
    }
    return resolution_symbol_name_equals(
        context.project_source, context.project_root,
        context.source_data, context.symbol_data,
        symbol, context.source, start, length
    );
}

unsafe usize ir_indexed_find_local(
    ref IrContext context,
    usize function_owner,
    usize name_start,
    usize name_length,
    usize use_start
) {
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_bucket_capacity == 0 {
        return resolution_find_local(
            context.project_source, context.project_root,
            context.source_data, context.symbol_data,
            context.detail_data, context.symbols,
            context.function_local_first, context.function_local_end,
            context.syntax_data, context.syntax,
            context.source_record, function_owner,
            context.source, name_start, name_length, use_start
        );
    }
    usize namespace = context.modules.length + function_owner;
    usize hash = ir_name_hash(
        context.source, name_start, name_length, namespace
    );
    usize encoded = read_usize(
        context.function_bucket_heads,
        (hash % context.function_bucket_capacity) * size_of(usize)
    );
    usize selected = context.symbols.length;
    usize selected_start = 0;
    while encoded != 0 {
        context.profile_symbol_candidates =
            context.profile_symbol_candidates + 1;
        usize symbol = encoded - 1;
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if read_record_field(context.symbol_data, symbol, 1) ==
                context.source_record && read_record_field(
                context.detail_data, symbol, 2
            ) == function_owner && (kind == resolution_symbol_parameter() ||
             kind == resolution_symbol_variable()) &&
            ir_indexed_symbol_name_equals(
                context, symbol, name_start, name_length
            ) {
            usize declaration_start = read_record_field(
                context.syntax_data,
                read_record_field(context.detail_data, symbol, 1), 1
            );
            if kind == resolution_symbol_parameter() ||
                (declaration_start < use_start &&
                 resolution_block_contains_use(
                    context.syntax_data, context.syntax,
                    read_record_field(context.detail_data, symbol, 1),
                    use_start
                 )) {
                if selected == context.symbols.length ||
                    declaration_start >= selected_start {
                    selected = symbol;
                    selected_start = declaration_start;
                }
            }
        }
        encoded = read_usize(
            context.function_bucket_next,
            symbol * size_of(usize)
        );
    }
    return selected;
}

unsafe usize ir_indexed_find_member(
    ref IrContext context,
    usize owner,
    usize required_kind,
    usize start,
    usize length
) {
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_bucket_capacity == 0 {
        return resolution_find_member(
            context.project_source, context.project_root,
            context.source_data, context.symbol_data,
            context.detail_data, context.symbols,
            owner, required_kind, context.source, start, length
        );
    }
    usize namespace = context.modules.length + owner;
    usize hash = ir_name_hash(
        context.source, start, length, namespace
    );
    usize encoded = read_usize(
        context.function_bucket_heads,
        (hash % context.function_bucket_capacity) * size_of(usize)
    );
    usize selected = context.symbols.length;
    while encoded != 0 {
        context.profile_symbol_candidates =
            context.profile_symbol_candidates + 1;
        usize symbol = encoded - 1;
        if read_record_field(context.detail_data, symbol, 2) == owner &&
            read_record_field(context.symbol_data, symbol, 0) ==
                required_kind && ir_indexed_symbol_name_equals(
                context, symbol, start, length
            ) && (selected == context.symbols.length || symbol < selected) {
            selected = symbol;
        }
        encoded = read_usize(
            context.function_bucket_next,
            symbol * size_of(usize)
        );
    }
    return selected;
}

unsafe usize ir_aggregate_for_type(
    ref IrContext context,
    usize type_id
) {
    if context.type_aggregate_symbols != null &&
        type_id < context.types.length {
        usize encoded = read_usize(
            context.type_aggregate_symbols,
            type_id * size_of(usize)
        );
        if encoded != 0 { return encoded - 1; }
    }
    usize exact = resolution_find_aggregate_for_type(
        context.symbol_data, context.symbols, type_id
    );
    if exact < context.symbols.length { return exact; }
    if type_id < context.types.length && read_record_field(
        context.type_data, type_id, 0
    ) == 9 {
        usize symbol = 0;
        while symbol < context.symbols.length {
            usize kind = read_record_field(context.symbol_data, symbol, 0);
            usize candidate = read_record_field(
                context.symbol_data, symbol, 4
            );
            if (kind == resolution_symbol_struct() ||
                kind == resolution_symbol_resource() ||
                kind == resolution_symbol_enum()) &&
                candidate < context.types.length && read_record_field(
                    context.type_data, candidate, 0
                ) == 9 && read_record_field(
                    context.type_data, candidate, 1
                ) == read_record_field(
                    context.type_data, type_id, 1
                ) && read_record_field(
                    context.type_data, candidate, 2
                ) == read_record_field(
                    context.type_data, type_id, 2
                ) && read_record_field(
                    context.type_data, candidate, 3
                ) == read_record_field(
                    context.type_data, type_id, 3
                ) { return symbol; }
            symbol = symbol + 1;
        }
    }
    return context.symbols.length;
}

unsafe usize ir_first_aggregate_field(
    ref IrContext context,
    usize aggregate_symbol
) {
    if context.aggregate_field_first == null ||
        aggregate_symbol >= context.symbols.length {
        return context.symbols.length;
    }
    usize encoded = read_usize(
        context.aggregate_field_first,
        aggregate_symbol * size_of(usize)
    );
    if encoded == 0 { return context.symbols.length; }
    return encoded - 1;
}

unsafe usize ir_next_aggregate_field(
    ref IrContext context,
    usize field_symbol
) {
    if context.field_next == null ||
        field_symbol >= context.symbols.length {
        return context.symbols.length;
    }
    usize encoded = read_usize(
        context.field_next, field_symbol * size_of(usize)
    );
    if encoded == 0 { return context.symbols.length; }
    return encoded - 1;
}

unsafe usize ir_parameter_count(
    ref IrContext context,
    usize function_symbol
) {
    if context.function_parameter_count != null &&
        function_symbol < context.symbols.length {
        return read_usize(
            context.function_parameter_count,
            function_symbol * size_of(usize)
        );
    }
    usize count = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 { count = count + 1; }
        symbol = symbol + 1;
    }
    return count;
}

unsafe usize ir_parameter_at(
    ref IrContext context,
    usize function_symbol,
    usize requested
) {
    if context.function_parameter_first != null &&
        context.parameter_next != null &&
        function_symbol < context.symbols.length {
        usize encoded = read_usize(
            context.function_parameter_first,
            function_symbol * size_of(usize)
        );
        usize index = 0;
        while encoded != 0 && index < requested {
            encoded = read_usize(
                context.parameter_next,
                (encoded - 1) * size_of(usize)
            );
            index = index + 1;
        }
        if encoded != 0 { return encoded - 1; }
        return context.symbols.length;
    }
    usize found = 0;
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_parameter() &&
            read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 {
            if found == requested { return symbol; }
            found = found + 1;
        }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}
