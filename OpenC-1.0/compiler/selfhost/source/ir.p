import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct IrContext {
    text project_source;
    text project_root;
    text source;
    ptr byte module_data;
    PackedBuffer modules;
    ptr byte source_data;
    ptr byte type_data;
    PackedBuffer types;
    ptr byte symbol_data;
    ptr byte detail_data;
    PackedBuffer symbols;
    ptr byte token_data;
    PackedBuffer tokens;
    ptr byte syntax_data;
    PackedBuffer syntax;
    usize module_index;
    usize source_record;
    usize function_node;
    usize function_symbol;
    usize function_result;
    usize function_local_first;
    usize function_local_end;
    ptr byte name_cache;
    ptr byte spelling_cache;
    usize spelling_cache_capacity;
    ptr byte call_cache;
    ptr byte call_argument_first;
    ptr byte call_argument_last;
    ptr byte argument_next;
    ptr byte type_cache;
    ptr byte resolved_type_ref_cache;
    ptr byte left_expression_cache;
    ptr byte right_expression_cache;
    ptr byte block_parent_cache;
    ptr byte control_parent_cache;
    ptr byte statement_nodes;
    usize statement_count;
    ptr byte block_statement_first;
    ptr byte statement_next;
    ptr byte control_block_first;
    ptr byte block_next;
    ptr byte control_child_first;
    ptr byte control_child_next;
    ptr byte initializer_field_first;
    ptr byte initializer_field_next;
    ptr byte initializer_field_owner;
    ptr byte array_element_first;
    ptr byte array_element_next;
    ptr byte block_nodes;
    usize block_count;
    ptr byte control_nodes;
    usize control_count;
    ptr byte expression_nodes;
    usize expression_count;
    ptr byte expression_start_heads;
    usize expression_start_capacity;
    ptr byte expression_start_next;
    ptr byte expression_next_start;
    ptr byte name_nodes;
    usize name_count;
    ptr byte type_ref_nodes;
    usize type_ref_count;
    ptr byte declaration_symbol_cache;
    ptr byte top_symbols;
    usize top_symbol_count;
    ptr byte function_bucket_heads;
    usize function_bucket_capacity;
    ptr byte function_bucket_next;
    ptr byte function_parameter_first;
    ptr byte function_parameter_count;
    ptr byte parameter_next;
    ptr byte function_local_range_first;
    ptr byte function_local_range_end;
    ptr byte type_aggregate_symbols;
    ptr byte aggregate_field_first;
    ptr byte field_next;
    ptr byte enum_item_value;
    ptr byte local_values;
    ptr byte block_data;
    PackedBuffer blocks;
    ptr byte instruction_data;
    ptr byte instruction_detail;
    PackedBuffer instructions;
    ptr byte operand_data;
    PackedBuffer operands;
    ptr byte break_data;
    usize break_depth;
    ptr byte continue_data;
    usize continue_depth;
    usize current_block;
    usize next_value;
    usize profile_statement_candidates;
    usize profile_parent_candidates;
    usize profile_expression_positions;
    usize profile_syntax_candidates;
    usize profile_symbol_candidates;
}

struct IrBounds {
    bool valid;
    usize start;
    usize end;
}

struct IrMemberBase {
    usize symbol;
    usize start;
    usize length;
}

usize ir_index_capacity(usize requested) {
    usize capacity = 16;
    while capacity < requested { capacity = capacity * 2; }
    return capacity;
}

usize ir_name_hash(
    text source,
    usize start,
    usize length,
    usize owner
) {
    usize hash = (owner % 16777213) + 1;
    usize cursor = 0;
    while cursor < length {
        hash = (
            hash * 131 + cast(usize, byte_at_or_zero(
                source, start + cursor
            )) + 1
        ) % 16777213;
        cursor = cursor + 1;
    }
    return hash;
}

unsafe void ir_initialize_symbol_indexes(
    ref IrContext context,
    ptr byte parameter_last
) {
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_parameter_first == null ||
        context.function_parameter_count == null ||
        context.parameter_next == null ||
        context.function_local_range_first == null ||
        context.function_local_range_end == null ||
        context.type_aggregate_symbols == null ||
        context.aggregate_field_first == null ||
        context.field_next == null || parameter_last == null {
        return;
    }
    usize index = 0;
    while index < context.function_bucket_capacity {
        write_usize(
            context.function_bucket_heads, index * size_of(usize), 0
        );
        index = index + 1;
    }
    index = 0;
    while index <= context.symbols.length {
        write_usize(
            context.function_bucket_next, index * size_of(usize), 0
        );
        write_usize(
            context.function_parameter_first, index * size_of(usize), 0
        );
        write_usize(
            context.function_parameter_count, index * size_of(usize), 0
        );
        write_usize(
            context.parameter_next, index * size_of(usize), 0
        );
        write_usize(
            context.function_local_range_first,
            index * size_of(usize), context.symbols.length
        );
        write_usize(
            context.function_local_range_end,
            index * size_of(usize), context.symbols.length
        );
        write_usize(
            context.aggregate_field_first,
            index * size_of(usize), 0
        );
        write_usize(
            context.field_next, index * size_of(usize), 0
        );
        if context.enum_item_value != null {
            write_usize(
                context.enum_item_value, index * size_of(usize), 0
            );
        }
        write_usize(parameter_last, index * size_of(usize), 0);
        index = index + 1;
    }
    index = 0;
    while index <= context.types.length {
        write_usize(
            context.type_aggregate_symbols,
            index * size_of(usize), 0
        );
        index = index + 1;
    }

    usize loaded_source_record = context.symbols.length + 1;
    text symbol_source = "";
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        usize source_record = read_record_field(
            context.symbol_data, symbol, 1
        );
        if source_record != loaded_source_record {
            status loaded = project_read_source_record(
                context.project_source, context.project_root,
                context.source_data, source_record,
                out symbol_source
            );
            if loaded.ok { loaded_source_record = source_record; }
        }
        if source_record == loaded_source_record {
            usize owner = read_record_field(
                context.detail_data, symbol, 2
            );
            usize namespace = read_record_field(
                context.detail_data, symbol, 0
            );
            if owner != 0 {
                namespace = context.modules.length + owner;
            }
            usize hash = ir_name_hash(
                symbol_source,
                read_record_field(context.symbol_data, symbol, 2),
                read_record_field(context.symbol_data, symbol, 3),
                namespace
            );
            usize bucket = hash % context.function_bucket_capacity;
            usize previous = read_usize(
                context.function_bucket_heads,
                bucket * size_of(usize)
            );
            write_usize(
                context.function_bucket_next,
                symbol * size_of(usize), previous
            );
            write_usize(
                context.function_bucket_heads,
                bucket * size_of(usize), symbol + 1
            );
        }
        if kind == resolution_symbol_struct() ||
            kind == resolution_symbol_resource() {
            usize type_id = read_record_field(
                context.symbol_data, symbol, 4
            );
            if type_id < context.types.length && read_usize(
                context.type_aggregate_symbols,
                type_id * size_of(usize)
            ) == 0 {
                write_usize(
                    context.type_aggregate_symbols,
                    type_id * size_of(usize), symbol + 1
                );
            }
        }
        if kind == resolution_symbol_parameter() ||
            kind == resolution_symbol_variable() {
            usize local_owner = read_record_field(
                context.detail_data, symbol, 2
            );
            if local_owner != 0 &&
                local_owner - 1 < context.symbols.length {
                usize local_function = local_owner - 1;
                if read_usize(
                    context.function_local_range_first,
                    local_function * size_of(usize)
                ) == context.symbols.length {
                    write_usize(
                        context.function_local_range_first,
                        local_function * size_of(usize), symbol
                    );
                }
                write_usize(
                    context.function_local_range_end,
                    local_function * size_of(usize), symbol + 1
                );
            }
        }
        if kind == resolution_symbol_parameter() {
            usize owner = read_record_field(
                context.detail_data, symbol, 2
            );
            if owner != 0 && owner - 1 < context.symbols.length {
                usize function_symbol = owner - 1;
                usize last = read_usize(
                    parameter_last,
                    function_symbol * size_of(usize)
                );
                if last == 0 {
                    write_usize(
                        context.function_parameter_first,
                        function_symbol * size_of(usize), symbol + 1
                    );
                } else {
                    write_usize(
                        context.parameter_next,
                        (last - 1) * size_of(usize), symbol + 1
                    );
                }
                write_usize(
                    parameter_last,
                    function_symbol * size_of(usize), symbol + 1
                );
                usize count = read_usize(
                    context.function_parameter_count,
                    function_symbol * size_of(usize)
                );
                write_usize(
                    context.function_parameter_count,
                    function_symbol * size_of(usize), count + 1
                );
            }
        }
        symbol = symbol + 1;
    }
    index = 0;
    while index <= context.symbols.length {
        write_usize(parameter_last, index * size_of(usize), 0);
        index = index + 1;
    }
    symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_field() {
            usize owner = read_record_field(
                context.detail_data, symbol, 2
            );
            if owner != 0 && owner - 1 < context.symbols.length {
                usize aggregate_symbol = owner - 1;
                usize last = read_usize(
                    parameter_last,
                    aggregate_symbol * size_of(usize)
                );
                if last == 0 {
                    write_usize(
                        context.aggregate_field_first,
                        aggregate_symbol * size_of(usize), symbol + 1
                    );
                } else {
                    write_usize(
                        context.field_next,
                        (last - 1) * size_of(usize), symbol + 1
                    );
                }
                write_usize(
                    parameter_last,
                    aggregate_symbol * size_of(usize), symbol + 1
                );
            }
        }
        symbol = symbol + 1;
    }
    if context.enum_item_value != null {
        index = 0;
        while index <= context.symbols.length {
            write_usize(parameter_last, index * size_of(usize), 0);
            index = index + 1;
        }
        symbol = 0;
        while symbol < context.symbols.length {
            if read_record_field(context.symbol_data, symbol, 0) ==
                    resolution_symbol_enum_item() {
                usize owner = read_record_field(
                    context.detail_data, symbol, 2
                );
                if owner != 0 && owner - 1 < context.symbols.length {
                    usize count = read_usize(
                        parameter_last,
                        (owner - 1) * size_of(usize)
                    );
                    write_usize(
                        context.enum_item_value,
                        symbol * size_of(usize), count + 1
                    );
                    write_usize(
                        parameter_last,
                        (owner - 1) * size_of(usize), count + 1
                    );
                }
            }
            symbol = symbol + 1;
        }
    }
}

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
    return resolution_find_aggregate_for_type(
        context.symbol_data, context.symbols, type_id
    );
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

unsafe void ir_initialize_local_values(ref IrContext context) {
    if context.local_values == null { return; }
    usize symbol = 0;
    while symbol <= context.symbols.length {
        write_usize(
            context.local_values, symbol * size_of(usize), 0
        );
        symbol = symbol + 1;
    }
}

unsafe void ir_initialize_node_indexes(ref IrContext context) {
    context.statement_count = 0;
    context.block_count = 0;
    context.control_count = 0;
    context.expression_count = 0;
    context.name_count = 0;
    context.type_ref_count = 0;
    if context.resolved_type_ref_cache != null {
        usize type_node = 0;
        while type_node <= context.syntax.length {
            write_usize(
                context.resolved_type_ref_cache,
                type_node * size_of(usize), 0
            );
            type_node = type_node + 1;
        }
    }
    if context.call_argument_first != null &&
        context.call_argument_last != null && context.argument_next != null {
        usize call_node = 0;
        while call_node <= context.syntax.length {
            write_usize(
                context.call_argument_first,
                call_node * size_of(usize), 0
            );
            write_usize(
                context.call_argument_last,
                call_node * size_of(usize), 0
            );
            write_usize(
                context.argument_next,
                call_node * size_of(usize), 0
            );
            call_node = call_node + 1;
        }
    }
    if context.expression_start_heads != null &&
        context.expression_start_next != null {
        usize start = 0;
        while start < context.expression_start_capacity {
            write_usize(
                context.expression_start_heads,
                start * size_of(usize), 0
            );
            start = start + 1;
        }
        usize expression = 0;
        while expression <= context.syntax.length {
            write_usize(
                context.expression_start_next,
                expression * size_of(usize), 0
            );
            expression = expression + 1;
        }
    }
    if context.statement_nodes == null || context.block_nodes == null ||
        context.control_nodes == null || context.expression_nodes == null ||
        context.name_nodes == null {
        return;
    }
    usize node = 0;
    while node < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, node, 0);
        if flow_statement_kind(kind) {
            write_usize(
                context.statement_nodes,
                context.statement_count * size_of(usize), node
            );
            context.statement_count = context.statement_count + 1;
        }
        if kind == 11 {
            write_usize(
                context.block_nodes,
                context.block_count * size_of(usize), node
            );
            context.block_count = context.block_count + 1;
        }
        if (kind >= 14 && kind <= 19) || kind == 24 || kind == 25 {
            write_usize(
                context.control_nodes,
                context.control_count * size_of(usize), node
            );
            context.control_count = context.control_count + 1;
        }
        if flow_expression_kind(kind) || kind == 52 {
            write_usize(
                context.expression_nodes,
                context.expression_count * size_of(usize), node
            );
            context.expression_count = context.expression_count + 1;
            usize start = read_record_field(
                context.syntax_data, node, 1
            );
            if context.expression_start_heads != null &&
                context.expression_start_next != null &&
                start < context.expression_start_capacity {
                usize previous = read_usize(
                    context.expression_start_heads,
                    start * size_of(usize)
                );
                write_usize(
                    context.expression_start_next,
                    node * size_of(usize), previous
                );
                write_usize(
                    context.expression_start_heads,
                    start * size_of(usize), node + 1
                );
            }
        }
        if kind == 27 {
            write_usize(
                context.name_nodes,
                context.name_count * size_of(usize), node
            );
            context.name_count = context.name_count + 1;
        }
        if kind == 26 && context.type_ref_nodes != null {
            write_usize(
                context.type_ref_nodes,
                context.type_ref_count * size_of(usize), node
            );
            context.type_ref_count = context.type_ref_count + 1;
        }
        node = node + 1;
    }
    if context.expression_next_start != null &&
        context.expression_start_heads != null {
        usize encoded = 0;
        usize position = context.expression_start_capacity;
        while position != 0 {
            position = position - 1;
            if read_usize(
                context.expression_start_heads,
                position * size_of(usize)
            ) != 0 {
                encoded = position + 1;
            }
            write_usize(
                context.expression_next_start,
                position * size_of(usize), encoded
            );
        }
    }
}

unsafe void ir_record_call_argument(
    ref IrContext context,
    usize call,
    usize argument_node
) {
    if context.call_argument_first == null ||
        context.call_argument_last == null || context.argument_next == null ||
        call >= context.syntax.length ||
        argument_node >= context.syntax.length { return; }
    usize last = read_usize(
        context.call_argument_last, call * size_of(usize)
    );
    if last == 0 {
        write_usize(
            context.call_argument_first,
            call * size_of(usize), argument_node + 1
        );
    } else {
        write_usize(
            context.argument_next,
            (last - 1) * size_of(usize), argument_node + 1
        );
    }
    write_usize(
        context.call_argument_last,
        call * size_of(usize), argument_node + 1
    );
}

unsafe usize ir_call_argument_node(
    ref IrContext context,
    usize call,
    usize requested
) {
    if context.call_argument_first == null ||
        context.argument_next == null || call >= context.syntax.length {
        return context.syntax.length;
    }
    usize encoded = read_usize(
        context.call_argument_first, call * size_of(usize)
    );
    usize index = 0;
    while encoded != 0 && index < requested {
        encoded = read_usize(
            context.argument_next,
            (encoded - 1) * size_of(usize)
        );
        index = index + 1;
    }
    if encoded == 0 { return context.syntax.length; }
    return encoded - 1;
}

unsafe void ir_initialize_statement_adjacency(ref IrContext context) {
    if context.block_statement_first == null ||
        context.statement_next == null { return; }
    usize node = 0;
    while node <= context.syntax.length {
        write_usize(
            context.block_statement_first,
            node * size_of(usize), 0
        );
        write_usize(
            context.statement_next,
            node * size_of(usize), 0
        );
        node = node + 1;
    }
    usize index = 0;
    while index < context.statement_count {
        usize record = read_usize(
            context.statement_nodes, index * size_of(usize)
        );
        usize block = ir_block_parent(context, record);
        if block < context.syntax.length {
            usize control = ir_control_parent(context, record);
            bool direct = control >= context.syntax.length;
            if !direct {
                direct = ir_block_parent(context, control) != block;
            }
            if direct {
                usize start = read_record_field(
                    context.syntax_data, record, 1
                );
                usize previous = 0;
                usize encoded = read_usize(
                    context.block_statement_first,
                    block * size_of(usize)
                );
                while encoded != 0 {
                    usize current = encoded - 1;
                    usize current_start = read_record_field(
                        context.syntax_data, current, 1
                    );
                    if current_start > start ||
                        (current_start == start && current > record) {
                        break;
                    }
                    previous = encoded;
                    encoded = read_usize(
                        context.statement_next,
                        current * size_of(usize)
                    );
                }
                if previous == 0 {
                    write_usize(
                        context.block_statement_first,
                        block * size_of(usize), record + 1
                    );
                } else {
                    write_usize(
                        context.statement_next,
                        (previous - 1) * size_of(usize), record + 1
                    );
                }
                write_usize(
                    context.statement_next,
                    record * size_of(usize), encoded
                );
            }
        }
        index = index + 1;
    }
}

unsafe void ir_initialize_control_adjacency(ref IrContext context) {
    if context.control_block_first == null || context.block_next == null ||
        context.control_child_first == null ||
        context.control_child_next == null { return; }
    usize node = 0;
    while node <= context.syntax.length {
        write_usize(
            context.control_block_first,
            node * size_of(usize), 0
        );
        write_usize(context.block_next, node * size_of(usize), 0);
        write_usize(
            context.control_child_first,
            node * size_of(usize), 0
        );
        write_usize(
            context.control_child_next,
            node * size_of(usize), 0
        );
        node = node + 1;
    }
    usize index = 0;
    while index < context.block_count {
        usize block = read_usize(
            context.block_nodes, index * size_of(usize)
        );
        usize parent = ir_control_parent(context, block);
        if parent < context.syntax.length {
            usize start = read_record_field(context.syntax_data, block, 1);
            usize previous = 0;
            usize encoded = read_usize(
                context.control_block_first,
                parent * size_of(usize)
            );
            while encoded != 0 {
                usize current = encoded - 1;
                usize current_start = read_record_field(
                    context.syntax_data, current, 1
                );
                if current_start > start ||
                    (current_start == start && current > block) { break; }
                previous = encoded;
                encoded = read_usize(
                    context.block_next,
                    current * size_of(usize)
                );
            }
            if previous == 0 {
                write_usize(
                    context.control_block_first,
                    parent * size_of(usize), block + 1
                );
            } else {
                write_usize(
                    context.block_next,
                    (previous - 1) * size_of(usize), block + 1
                );
            }
            write_usize(
                context.block_next, block * size_of(usize), encoded
            );
        }
        index = index + 1;
    }
    index = 0;
    while index < context.control_count {
        usize child = read_usize(
            context.control_nodes, index * size_of(usize)
        );
        usize parent = ir_control_parent(context, child);
        if parent < context.syntax.length {
            usize start = read_record_field(context.syntax_data, child, 1);
            usize previous = 0;
            usize encoded = read_usize(
                context.control_child_first,
                parent * size_of(usize)
            );
            while encoded != 0 {
                usize current = encoded - 1;
                usize current_start = read_record_field(
                    context.syntax_data, current, 1
                );
                if current_start > start ||
                    (current_start == start && current > child) { break; }
                previous = encoded;
                encoded = read_usize(
                    context.control_child_next,
                    current * size_of(usize)
                );
            }
            if previous == 0 {
                write_usize(
                    context.control_child_first,
                    parent * size_of(usize), child + 1
                );
            } else {
                write_usize(
                    context.control_child_next,
                    (previous - 1) * size_of(usize), child + 1
                );
            }
            write_usize(
                context.control_child_next,
                child * size_of(usize), encoded
            );
        }
        index = index + 1;
    }
}

unsafe void ir_initialize_initializer_fields(ref IrContext context) {
    if context.initializer_field_first == null ||
        context.initializer_field_next == null ||
        context.initializer_field_owner == null { return; }
    usize node = 0;
    while node <= context.syntax.length {
        write_usize(
            context.initializer_field_first,
            node * size_of(usize), 0
        );
        write_usize(
            context.initializer_field_next,
            node * size_of(usize), 0
        );
        write_usize(
            context.initializer_field_owner,
            node * size_of(usize), 0
        );
        node = node + 1;
    }
    node = 0;
    while node < context.syntax.length {
        if read_record_field(context.syntax_data, node, 0) == 49 {
            usize owner = resolution_smallest_parent(
                context.syntax_data, context.syntax,
                node, 47, 48, 999
            );
            if owner < context.syntax.length {
                write_usize(
                    context.initializer_field_owner,
                    node * size_of(usize), owner + 1
                );
                usize start = read_record_field(
                    context.syntax_data, node, 1
                );
                usize previous = 0;
                usize encoded = read_usize(
                    context.initializer_field_first,
                    owner * size_of(usize)
                );
                while encoded != 0 {
                    usize current = encoded - 1;
                    usize current_start = read_record_field(
                        context.syntax_data, current, 1
                    );
                    if current_start > start ||
                        (current_start == start && current > node) {
                        break;
                    }
                    previous = encoded;
                    encoded = read_usize(
                        context.initializer_field_next,
                        current * size_of(usize)
                    );
                }
                if previous == 0 {
                    write_usize(
                        context.initializer_field_first,
                        owner * size_of(usize), node + 1
                    );
                } else {
                    write_usize(
                        context.initializer_field_next,
                        (previous - 1) * size_of(usize), node + 1
                    );
                }
                write_usize(
                    context.initializer_field_next,
                    node * size_of(usize), encoded
                );
            }
        }
        node = node + 1;
    }
}

unsafe usize ir_first_initializer_field(
    ref IrContext context,
    usize initializer
) {
    if context.initializer_field_first == null ||
        initializer >= context.syntax.length {
        return context.syntax.length;
    }
    usize encoded = read_usize(
        context.initializer_field_first,
        initializer * size_of(usize)
    );
    if encoded == 0 { return context.syntax.length; }
    return encoded - 1;
}

unsafe usize ir_next_initializer_field(
    ref IrContext context,
    usize field
) {
    if context.initializer_field_next == null ||
        field >= context.syntax.length {
        return context.syntax.length;
    }
    usize encoded = read_usize(
        context.initializer_field_next,
        field * size_of(usize)
    );
    if encoded == 0 { return context.syntax.length; }
    return encoded - 1;
}

unsafe void ir_initialize_array_elements(ref IrContext context) {
    if context.array_element_first == null ||
        context.array_element_next == null ||
        context.expression_nodes == null { return; }
    usize node = 0;
    while node <= context.syntax.length {
        write_usize(
            context.array_element_first,
            node * size_of(usize), 0
        );
        write_usize(
            context.array_element_next,
            node * size_of(usize), 0
        );
        node = node + 1;
    }
    usize parent = 0;
    while parent < context.syntax.length {
        if read_record_field(context.syntax_data, parent, 0) == 50 {
            usize index = 0;
            while index < context.expression_count {
                usize record = read_usize(
                    context.expression_nodes, index * size_of(usize)
                );
                if record != parent && semantic_node_contains(
                    context.syntax_data, parent, record
                ) && resolution_smallest_parent(
                    context.syntax_data, context.syntax, record,
                    50, 999, 998
                ) == parent {
                    usize start = read_record_field(
                        context.syntax_data, record, 1
                    );
                    usize previous = 0;
                    usize encoded = read_usize(
                        context.array_element_first,
                        parent * size_of(usize)
                    );
                    while encoded != 0 {
                        usize current = encoded - 1;
                        usize current_start = read_record_field(
                            context.syntax_data, current, 1
                        );
                        if current_start > start ||
                            (current_start == start && current > record) {
                            break;
                        }
                        previous = encoded;
                        encoded = read_usize(
                            context.array_element_next,
                            current * size_of(usize)
                        );
                    }
                    if previous == 0 {
                        write_usize(
                            context.array_element_first,
                            parent * size_of(usize), record + 1
                        );
                    } else {
                        write_usize(
                            context.array_element_next,
                            (previous - 1) * size_of(usize), record + 1
                        );
                    }
                    write_usize(
                        context.array_element_next,
                        record * size_of(usize), encoded
                    );
                }
                index = index + 1;
            }
        }
        parent = parent + 1;
    }
}

unsafe usize ir_first_array_element(
    ref IrContext context,
    usize parent
) {
    if context.array_element_first == null ||
        parent >= context.syntax.length {
        return context.syntax.length;
    }
    usize encoded = read_usize(
        context.array_element_first,
        parent * size_of(usize)
    );
    if encoded == 0 { return context.syntax.length; }
    return encoded - 1;
}

unsafe usize ir_next_array_element(
    ref IrContext context,
    usize element
) {
    if context.array_element_next == null ||
        element >= context.syntax.length {
        return context.syntax.length;
    }
    usize encoded = read_usize(
        context.array_element_next,
        element * size_of(usize)
    );
    if encoded == 0 { return context.syntax.length; }
    return encoded - 1;
}

unsafe void ir_initialize_declaration_symbols(ref IrContext context) {
    context.top_symbol_count = 0;
    if context.declaration_symbol_cache == null { return; }
    usize node = 0;
    while node <= context.syntax.length {
        write_usize(
            context.declaration_symbol_cache,
            node * size_of(usize), 0
        );
        node = node + 1;
    }
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if read_record_field(
            context.symbol_data, symbol, 1
        ) == context.source_record {
            usize declaration = read_record_field(
                context.detail_data, symbol, 1
            );
            if declaration < context.syntax.length && read_usize(
                context.declaration_symbol_cache,
                declaration * size_of(usize)
            ) == 0 {
                write_usize(
                    context.declaration_symbol_cache,
                    declaration * size_of(usize), symbol + 1
                );
            }
        }
        if context.top_symbols != null && read_record_field(
            context.detail_data, symbol, 0
        ) == context.module_index && read_record_field(
            context.detail_data, symbol, 2
        ) == 0 && kind != resolution_symbol_field() &&
            kind != resolution_symbol_enum_item() {
            write_usize(
                context.top_symbols,
                context.top_symbol_count * size_of(usize), symbol
            );
            context.top_symbol_count = context.top_symbol_count + 1;
        }
        symbol = symbol + 1;
    }
}

unsafe usize ir_owner_symbol(
    ref IrContext context,
    usize declaration,
    usize kind_one,
    usize kind_two
) {
    if context.declaration_symbol_cache != null &&
        declaration < context.syntax.length {
        usize cached = read_usize(
            context.declaration_symbol_cache,
            declaration * size_of(usize)
        );
        if cached != 0 {
            usize kind = read_record_field(
                context.symbol_data, cached - 1, 0
            );
            if kind == kind_one || kind == kind_two { return cached; }
        }
    }
    return resolution_find_owner_symbol(
        context.symbol_data, context.detail_data, context.symbols,
        context.source_record, declaration, kind_one, kind_two
    );
}

unsafe usize ir_find_top_unqualified(
    ref IrContext context,
    usize module_index,
    usize start,
    usize length
) {
    if context.function_bucket_heads != null &&
        context.function_bucket_next != null &&
        context.function_bucket_capacity != 0 {
        usize hash = ir_name_hash(
            context.source, start, length, module_index
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
            usize kind = read_record_field(
                context.symbol_data, symbol, 0
            );
            if read_record_field(context.detail_data, symbol, 0) ==
                    module_index && read_record_field(
                    context.detail_data, symbol, 2
                ) == 0 && kind != resolution_symbol_field() &&
                kind != resolution_symbol_enum_item() &&
                ir_indexed_symbol_name_equals(
                    context, symbol, start, length
                ) && (selected == context.symbols.length ||
                    symbol < selected) {
                selected = symbol;
            }
            encoded = read_usize(
                context.function_bucket_next,
                symbol * size_of(usize)
            );
        }
        return selected;
    }
    if context.top_symbols == null || module_index != context.module_index {
        return resolution_find_top_unqualified(
            context.project_source, context.project_root,
            context.source_data, context.symbol_data, context.detail_data,
            context.symbols, module_index, context.source_record,
            context.source, start, length
        );
    }
    usize index = 0;
    while index < context.top_symbol_count {
        usize symbol = read_usize(
            context.top_symbols, index * size_of(usize)
        );
        bool same_name = false;
        if read_record_field(
            context.symbol_data, symbol, 1
        ) == context.source_record {
            same_name = semantic_spans_equal(
                context.source, start, length,
                context.source,
                read_record_field(context.symbol_data, symbol, 2),
                read_record_field(context.symbol_data, symbol, 3)
            );
        } else {
            same_name = resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data, symbol,
                context.source, start, length
            );
        }
        if same_name { return symbol; }
        index = index + 1;
    }
    return context.symbols.length;
}

unsafe usize ir_find_nonlocal_name(
    ref IrContext context,
    usize start,
    usize length,
    usize first_length
) {
    if first_length != length {
        usize enum_symbol = ir_find_top_unqualified(
            context, context.module_index, start, first_length
        );
        if enum_symbol < context.symbols.length && read_record_field(
            context.symbol_data, enum_symbol, 0
        ) == resolution_symbol_enum() {
            usize item = ir_indexed_find_member(
                context,
                enum_symbol + 1, resolution_symbol_enum_item(),
                start + first_length + 1,
                length - first_length - 1
            );
            if item < context.symbols.length { return item; }
        }
        usize candidate_module = 0;
        while candidate_module < context.modules.length {
            usize module_length = read_record_field(
                context.module_data, candidate_module, 1
            );
            if module_length < length && byte_at_or_zero(
                context.source, start + module_length
            ) == 46 && resolution_module_name_equals(
                context.project_source, context.module_data,
                candidate_module, context.source, start, module_length
            ) {
                usize direct = ir_find_top_unqualified(
                    context, candidate_module,
                    start + module_length + 1,
                    length - module_length - 1
                );
                if direct < context.symbols.length { return direct; }
            }
            candidate_module = candidate_module + 1;
        }
    } else {
        usize top = ir_find_top_unqualified(
            context, context.module_index, start, length
        );
        if top < context.symbols.length { return top; }
    }
    return context.symbols.length;
}

unsafe void ir_initialize_parent_caches(
    ref PackedBuffer syntax,
    ptr byte block_parent_cache,
    ptr byte control_parent_cache
) {
    usize node = 0;
    while node <= syntax.length {
        write_usize(
            block_parent_cache,
            node * size_of(usize),
            syntax.length + 1
        );
        write_usize(
            control_parent_cache,
            node * size_of(usize),
            syntax.length + 1
        );
        node = node + 1;
    }
}

unsafe usize ir_block_parent(
    ref IrContext context,
    usize node
) {
    if context.block_parent_cache != null && node < context.syntax.length {
        usize cached = read_usize(
            context.block_parent_cache, node * size_of(usize)
        );
        if cached <= context.syntax.length { return cached; }
        cached = context.syntax.length;
        usize selected_length = cast(usize, 4294967295);
        usize index = 0;
        context.profile_parent_candidates =
            context.profile_parent_candidates + context.block_count;
        while index < context.block_count {
            usize candidate = read_usize(
                context.block_nodes, index * size_of(usize)
            );
            if candidate != node && semantic_node_contains(
                context.syntax_data, candidate, node
            ) {
                usize length = read_record_field(
                    context.syntax_data, candidate, 2
                );
                if length < selected_length {
                    cached = candidate;
                    selected_length = length;
                }
            }
            index = index + 1;
        }
        write_usize(
            context.block_parent_cache,
            node * size_of(usize),
            cached
        );
        return cached;
    }
    return flow_smallest_block_parent(
        context.syntax_data, context.syntax, node
    );
}

unsafe usize ir_control_parent(
    ref IrContext context,
    usize node
) {
    if context.control_parent_cache != null && node < context.syntax.length {
        usize cached = read_usize(
            context.control_parent_cache, node * size_of(usize)
        );
        if cached <= context.syntax.length { return cached; }
        cached = context.syntax.length;
        usize selected_length = cast(usize, 4294967295);
        usize index = 0;
        context.profile_parent_candidates =
            context.profile_parent_candidates + context.control_count;
        while index < context.control_count {
            usize candidate = read_usize(
                context.control_nodes, index * size_of(usize)
            );
            if candidate != node && semantic_node_contains(
                context.syntax_data, candidate, node
            ) {
                usize length = read_record_field(
                    context.syntax_data, candidate, 2
                );
                if length < selected_length {
                    cached = candidate;
                    selected_length = length;
                }
            }
            index = index + 1;
        }
        write_usize(
            context.control_parent_cache,
            node * size_of(usize),
            cached
        );
        return cached;
    }
    return flow_control_parent(
        context.syntax_data, context.syntax, node
    );
}

unsafe usize ir_next_direct_statement(
    ref IrContext context,
    usize block,
    usize after_start,
    usize after_record
) {
    if context.block_statement_first != null &&
        context.statement_next != null && block < context.syntax.length {
        usize encoded = 0;
        if after_start == 0 && after_record == 0 {
            encoded = read_usize(
                context.block_statement_first,
                block * size_of(usize)
            );
        } else if after_record < context.syntax.length {
            encoded = read_usize(
                context.statement_next,
                after_record * size_of(usize)
            );
        }
        if encoded == 0 { return context.syntax.length; }
        return encoded - 1;
    }
    usize selected = context.syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize selected_record = cast(usize, 4294967295);
    usize index = 0;
    usize candidate_count = context.syntax.length;
    if context.statement_nodes != null {
        candidate_count = context.statement_count;
    }
    context.profile_statement_candidates =
        context.profile_statement_candidates + candidate_count;
    while index < candidate_count {
        usize record = index;
        if context.statement_nodes != null {
            record = read_usize(
                context.statement_nodes, index * size_of(usize)
            );
        }
        usize kind = read_record_field(context.syntax_data, record, 0);
        usize start = read_record_field(context.syntax_data, record, 1);
        bool after = start > after_start ||
            (start == after_start && record > after_record);
        bool earlier = selected == context.syntax.length ||
            start < selected_start ||
            (start == selected_start && record < selected_record);
        if flow_statement_kind(kind) && record != block && after && earlier &&
            ir_block_parent(context, record) == block {
            usize control_parent = ir_control_parent(context, record);
            bool direct_control = control_parent >= context.syntax.length;
            if !direct_control {
                direct_control =
                    ir_block_parent(context, control_parent) != block;
            }
            if direct_control {
                selected = record;
                selected_start = start;
                selected_record = record;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_largest_direct_block(
    ref IrContext context,
    usize parent
) {
    if context.block_nodes == null {
        return flow_largest_direct_block(
            context.syntax_data, context.syntax, parent
        );
    }
    usize selected = context.syntax.length;
    usize selected_length = 0;
    usize index = 0;
    while index < context.block_count {
        usize record = read_usize(
            context.block_nodes, index * size_of(usize)
        );
        if semantic_node_contains(context.syntax_data, parent, record) {
            usize length = read_record_field(
                context.syntax_data, record, 2
            );
            if selected == context.syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_root_expression(
    ref IrContext context,
    usize parent
) {
    if context.expression_start_heads != null &&
        context.expression_start_next != null &&
        context.expression_start_capacity != 0 {
        usize start = read_record_field(context.syntax_data, parent, 1);
        usize end = start + read_record_field(
            context.syntax_data, parent, 2
        );
        return ir_root_in_bounds(context, start, end);
    }
    if context.expression_nodes == null {
        return flow_root_expression(
            context.syntax_data, context.syntax, parent
        );
    }
    usize selected = context.syntax.length;
    usize selected_length = 0;
    usize index = 0;
    while index < context.expression_count {
        usize record = read_usize(
            context.expression_nodes, index * size_of(usize)
        );
        usize kind = read_record_field(context.syntax_data, record, 0);
        if flow_expression_kind(kind) &&
            semantic_node_contains(context.syntax_data, parent, record) {
            usize length = read_record_field(
                context.syntax_data, record, 2
            );
            if selected == context.syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_first_name(
    ref IrContext context,
    usize event
) {
    if context.expression_start_heads != null &&
        context.expression_start_next != null &&
        context.expression_start_capacity != 0 {
        usize event_start = read_record_field(
            context.syntax_data, event, 1
        );
        usize event_end = event_start + read_record_field(
            context.syntax_data, event, 2
        );
        if context.expression_next_start == null {
            context.profile_expression_positions =
                context.profile_expression_positions + event_end - event_start;
        }
        usize cursor = event_start;
        while cursor < event_end &&
            cursor < context.expression_start_capacity {
            if context.expression_next_start != null {
                usize next_encoded = read_usize(
                    context.expression_next_start,
                    cursor * size_of(usize)
                );
                if next_encoded == 0 { break; }
                cursor = next_encoded - 1;
                if cursor >= event_end { break; }
                context.profile_expression_positions =
                    context.profile_expression_positions + 1;
            }
            usize encoded = read_usize(
                context.expression_start_heads,
                cursor * size_of(usize)
            );
            usize selected = context.syntax.length;
            while encoded != 0 {
                usize record = encoded - 1;
                if read_record_field(
                        context.syntax_data, record, 0
                    ) == 27 && semantic_node_contains(
                        context.syntax_data, event, record
                    ) && (selected == context.syntax.length ||
                        record < selected) {
                    selected = record;
                }
                encoded = read_usize(
                    context.expression_start_next,
                    record * size_of(usize)
                );
            }
            if selected < context.syntax.length { return selected; }
            cursor = cursor + 1;
        }
        return context.syntax.length;
    }
    if context.name_nodes == null {
        return flow_event_first_name(
            context.syntax_data, context.syntax, event
        );
    }
    usize selected = context.syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize index = 0;
    while index < context.name_count {
        usize record = read_usize(
            context.name_nodes, index * size_of(usize)
        );
        if semantic_node_contains(context.syntax_data, event, record) {
            usize start = read_record_field(
                context.syntax_data, record, 1
            );
            if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_local_initializer_root(
    ref IrContext context,
    usize declaration
) {
    usize name_start = read_record_field(
        context.syntax_data, declaration, 3
    );
    usize declaration_start = read_record_field(
        context.syntax_data, declaration, 1
    );
    usize declaration_end = declaration_start + read_record_field(
        context.syntax_data, declaration, 2
    );
    if context.expression_start_heads != null &&
        context.expression_start_next != null {
        return ir_root_in_bounds(
            context, name_start + 1, declaration_end
        );
    }
    return flow_local_initializer_root(
        context.syntax_data, context.syntax, declaration
    );
}

unsafe usize ir_left_expression(
    ref IrContext context,
    usize parent,
    usize operator_start
) {
    if context.left_expression_cache != null &&
        parent < context.syntax.length {
        usize cached = read_usize(
            context.left_expression_cache,
            parent * size_of(usize)
        );
        if cached <= context.syntax.length { return cached; }
        if context.expression_start_heads != null {
            usize parent_start = read_record_field(
                context.syntax_data, parent, 1
            );
            cached = parent;
            usize selected_end = parent_start;
            if parent_start < context.expression_start_capacity {
                context.profile_expression_positions =
                    context.profile_expression_positions + 1;
                usize encoded = read_usize(
                    context.expression_start_heads,
                    parent_start * size_of(usize)
                );
                while encoded != 0 {
                    usize record = encoded - 1;
                    usize kind = read_record_field(
                        context.syntax_data, record, 0
                    );
                    usize end = parent_start + read_record_field(
                        context.syntax_data, record, 2
                    );
                    if record < parent && resolution_expression_kind(kind) &&
                        end <= operator_start &&
                        (cached == parent || end > selected_end ||
                         (end == selected_end && record > cached)) {
                        cached = record;
                        selected_end = end;
                    }
                    encoded = read_usize(
                        context.expression_start_next,
                        record * size_of(usize)
                    );
                }
            }
        } else {
            cached = resolution_left_expression(
                context.syntax_data, parent, operator_start
            );
        }
        write_usize(
            context.left_expression_cache,
            parent * size_of(usize),
            cached
        );
        return cached;
    }
    return resolution_left_expression(
        context.syntax_data, parent, operator_start
    );
}

unsafe usize ir_right_expression(
    ref IrContext context,
    usize parent,
    usize operator_end
) {
    if context.right_expression_cache != null &&
        parent < context.syntax.length {
        usize cached = read_usize(
            context.right_expression_cache,
            parent * size_of(usize)
        );
        if cached <= context.syntax.length { return cached; }
        if context.expression_start_heads != null {
            usize parent_end = read_record_field(
                context.syntax_data, parent, 1
            ) + read_record_field(context.syntax_data, parent, 2);
            cached = parent;
            usize selected_start = parent_end;
            usize cursor = operator_end;
            while cursor <= parent_end &&
                cursor < context.expression_start_capacity {
                if context.expression_next_start != null {
                    usize next_encoded = read_usize(
                        context.expression_next_start,
                        cursor * size_of(usize)
                    );
                    if next_encoded == 0 { break; }
                    cursor = next_encoded - 1;
                    if cursor > parent_end { break; }
                }
                context.profile_expression_positions =
                    context.profile_expression_positions + 1;
                usize encoded = read_usize(
                    context.expression_start_heads,
                    cursor * size_of(usize)
                );
                while encoded != 0 {
                    usize record = encoded - 1;
                    usize kind = read_record_field(
                        context.syntax_data, record, 0
                    );
                    usize end = cursor + read_record_field(
                        context.syntax_data, record, 2
                    );
                    if record < parent && resolution_expression_kind(kind) &&
                        end == parent_end &&
                        (cached == parent || cursor < selected_start ||
                         (cursor == selected_start && record > cached)) {
                        cached = record;
                        selected_start = cursor;
                    }
                    encoded = read_usize(
                        context.expression_start_next,
                        record * size_of(usize)
                    );
                }
                cursor = cursor + 1;
            }
        } else {
            cached = resolution_right_expression(
                context.syntax_data, parent, operator_end
            );
        }
        write_usize(
            context.right_expression_cache,
            parent * size_of(usize),
            cached
        );
        return cached;
    }
    return resolution_right_expression(
        context.syntax_data, parent, operator_end
    );
}

usize ir_op_nop() { return 1; }
usize ir_op_const_integer() { return 2; }
usize ir_op_const_float() { return 3; }
usize ir_op_const_text() { return 4; }
usize ir_op_const_bool() { return 5; }
usize ir_op_local_alloc() { return 6; }
usize ir_op_load() { return 7; }
usize ir_op_store() { return 8; }
usize ir_op_unary() { return 9; }
usize ir_op_binary() { return 10; }
usize ir_op_short_begin() { return 11; }
usize ir_op_short_end() { return 12; }
usize ir_op_compare() { return 13; }
usize ir_op_cast() { return 14; }
usize ir_op_reinterpret() { return 15; }
usize ir_op_address() { return 16; }
usize ir_op_bounds() { return 17; }
usize ir_op_call() { return 18; }
usize ir_op_branch() { return 19; }
usize ir_op_branch_conditional() { return 20; }
usize ir_op_return() { return 21; }
usize ir_op_return_void() { return 22; }
usize ir_op_aggregate_create() { return 23; }
usize ir_op_aggregate_field() { return 24; }
usize ir_op_array_create() { return 25; }
usize ir_op_slice_create() { return 26; }
usize ir_op_optional_none() { return 27; }
usize ir_op_optional_some() { return 28; }
usize ir_op_status_create() { return 29; }
usize ir_op_scope_register() { return 30; }
usize ir_op_object_construct() { return 31; }
usize ir_op_object_destroy() { return 32; }
usize ir_op_target_fault() { return 33; }

text ir_opcode_text(usize opcode) {
    if opcode == ir_op_nop() { return "nop"; }
    if opcode == ir_op_const_integer() { return "const.integer"; }
    if opcode == ir_op_const_float() { return "const.float"; }
    if opcode == ir_op_const_text() { return "const.text"; }
    if opcode == ir_op_const_bool() { return "const.bool"; }
    if opcode == ir_op_local_alloc() { return "local.alloc"; }
    if opcode == ir_op_load() { return "load"; }
    if opcode == ir_op_store() { return "store"; }
    if opcode == ir_op_unary() { return "unary"; }
    if opcode == ir_op_binary() { return "binary"; }
    if opcode == ir_op_short_begin() { return "short_circuit.begin"; }
    if opcode == ir_op_short_end() { return "short_circuit.end"; }
    if opcode == ir_op_compare() { return "compare"; }
    if opcode == ir_op_cast() { return "cast"; }
    if opcode == ir_op_reinterpret() { return "reinterpret"; }
    if opcode == ir_op_address() { return "address_of"; }
    if opcode == ir_op_bounds() { return "bounds.check"; }
    if opcode == ir_op_call() { return "call"; }
    if opcode == ir_op_branch() { return "branch"; }
    if opcode == ir_op_branch_conditional() { return "branch.conditional"; }
    if opcode == ir_op_return() { return "return"; }
    if opcode == ir_op_return_void() { return "return.void"; }
    if opcode == ir_op_aggregate_create() { return "aggregate.create"; }
    if opcode == ir_op_aggregate_field() { return "aggregate.field"; }
    if opcode == ir_op_array_create() { return "array.create"; }
    if opcode == ir_op_slice_create() { return "slice.create"; }
    if opcode == ir_op_optional_none() { return "optional.none"; }
    if opcode == ir_op_optional_some() { return "optional.some"; }
    if opcode == ir_op_status_create() { return "status.create"; }
    if opcode == ir_op_scope_register() { return "scope.register"; }
    if opcode == ir_op_object_construct() { return "object.construct"; }
    if opcode == ir_op_object_destroy() { return "object.destroy"; }
    return "target.fault";
}

text ir_block_name(usize code) {
    if code == 1 { return "entry"; }
    if code == 2 { return "if.then"; }
    if code == 3 { return "if.else"; }
    if code == 4 { return "if.merge"; }
    if code == 5 { return "while.header"; }
    if code == 6 { return "while.body"; }
    if code == 7 { return "while.after"; }
    if code == 8 { return "for.header"; }
    if code == 9 { return "for.body"; }
    if code == 10 { return "for.step"; }
    if code == 11 { return "for.after"; }
    if code == 12 { return "switch.after"; }
    if code == 13 { return "switch.case"; }
    if code == 14 { return "switch.default"; }
    return "switch.next";
}

text ir_static_text(usize code) {
    if code == 1 { return "null"; }
    if code == 2 { return "&"; }
    if code == 3 { return "index"; }
    if code == 4 { return "index:address"; }
    if code == 5 { return "range"; }
    if code == 6 { return "status"; }
    if code == 7 { return "some"; }
    if code == 8 { return "destroy"; }
    if code == 9 { return "unsupported"; }
    if code == 10 { return "target-fault"; }
    if code == 11 { return "invalid pointer operation"; }
    if code == 12 { return "invalid pointer dereference"; }
    return "==";
}

unsafe usize ir_add_block(ref IrContext context, usize name_code) {
    usize block = context.blocks.length;
    write_record_field(context.block_data, block, 0, block);
    write_record_field(context.block_data, block, 1, name_code);
    context.blocks.length = context.blocks.length + 1;
    return block;
}

unsafe void ir_add_operand(
    ref IrContext context,
    usize value,
    usize immediate_kind,
    usize immediate_one,
    usize immediate_two
) {
    usize operand = context.operands.length;
    write_record_field(context.operand_data, operand, 0, value);
    write_record_field(context.operand_data, operand, 1, immediate_kind);
    write_record_field(context.operand_data, operand, 2, immediate_one);
    write_record_field(context.operand_data, operand, 3, immediate_two);
    context.operands.length = context.operands.length + 1;
}

unsafe usize ir_emit_instruction(
    ref IrContext context,
    usize opcode,
    usize type_id,
    usize start,
    usize length,
    usize text_kind,
    usize text_one,
    usize text_two,
    usize operand_first,
    usize operand_count,
    bool has_result
) {
    usize result = 0;
    if has_result {
        result = context.next_value;
        context.next_value = context.next_value + 1;
    }
    usize record = context.instructions.length;
    write_record_field(context.instruction_data, record, 0, context.current_block);
    write_record_field(context.instruction_data, record, 1, result);
    write_record_field(context.instruction_data, record, 2, opcode);
    write_record_field(context.instruction_data, record, 3, type_id);
    write_record_field(
        context.instruction_data, record, 4,
        resolution_pack_span(start, length)
    );
    write_record_field(context.instruction_detail, record, 0, text_kind);
    write_record_field(context.instruction_detail, record, 1, text_one);
    write_record_field(context.instruction_detail, record, 2, text_two);
    write_record_field(context.instruction_detail, record, 3, operand_first);
    write_record_field(context.instruction_detail, record, 4, operand_count);
    context.instructions.length = context.instructions.length + 1;
    return result;
}
