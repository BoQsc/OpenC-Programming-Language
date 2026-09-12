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
    ptr byte function_at_position;
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
    ptr byte symbol_export_cache;
    ptr byte native_layout_size_cache;
    ptr byte native_layout_alignment_cache;
    ptr byte native_layout_state_cache;
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
            text loaded_symbol_source;
            status loaded = project_read_source_record(
                context.project_source, context.project_root,
                context.source_data, source_record,
                out loaded_symbol_source
            );
            if loaded.ok {
                symbol_source = loaded_symbol_source;
                loaded_source_record = source_record;
            }
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
            kind == resolution_symbol_resource() ||
            kind == resolution_symbol_enum() {
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

unsafe void ir_initialize_function_positions(ref IrContext context) {
    if context.function_at_position == null ||
        context.expression_start_capacity == 0 { return; }
    usize position = 0;
    while position < context.expression_start_capacity {
        write_usize(
            context.function_at_position, position * size_of(usize), 0
        );
        position = position + 1;
    }
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() && read_record_field(
                context.symbol_data, symbol, 1
            ) == context.source_record {
            usize declaration = read_record_field(
                context.detail_data, symbol, 1
            );
            if declaration < context.syntax.length {
                usize start = read_record_field(
                    context.syntax_data, declaration, 1
                );
                usize end = start + read_record_field(
                    context.syntax_data, declaration, 2
                );
                if end > context.expression_start_capacity {
                    end = context.expression_start_capacity;
                }
                while start < end {
                    write_usize(
                        context.function_at_position,
                        start * size_of(usize), symbol + 1
                    );
                    start = start + 1;
                }
            }
        }
        symbol = symbol + 1;
    }
}

unsafe void ir_initialize_parent_position_kind(
    ref IrContext context,
    bool blocks,
    ptr byte second_at_position
) {
    if context.function_at_position == null ||
        context.expression_start_capacity == 0 { return; }
    usize position = 0;
    while position < context.expression_start_capacity {
        write_usize(
            context.function_at_position, position * size_of(usize), 0
        );
        write_usize(
            second_at_position, position * size_of(usize), 0
        );
        position = position + 1;
    }
    usize candidate_count = context.control_count;
    ptr byte candidates = context.control_nodes;
    if blocks {
        candidate_count = context.block_count;
        candidates = context.block_nodes;
    }
    usize index = 0;
    while index < candidate_count {
        usize candidate = read_usize(
            candidates, index * size_of(usize)
        );
        usize candidate_length = read_record_field(
            context.syntax_data, candidate, 2
        );
        usize start = read_record_field(
            context.syntax_data, candidate, 1
        );
        usize end = start + candidate_length;
        if end > context.expression_start_capacity {
            end = context.expression_start_capacity;
        }
        while start < end {
            usize best = read_usize(
                context.function_at_position, start * size_of(usize)
            );
            if best == 0 || candidate_length < read_record_field(
                    context.syntax_data, best - 1, 2
                ) {
                write_usize(
                    second_at_position, start * size_of(usize), best
                );
                write_usize(
                    context.function_at_position,
                    start * size_of(usize), candidate + 1
                );
            } else {
                usize second = read_usize(
                    second_at_position, start * size_of(usize)
                );
                if candidate + 1 != best && (second == 0 ||
                    candidate_length < read_record_field(
                        context.syntax_data, second - 1, 2
                    )) {
                    write_usize(
                        second_at_position,
                        start * size_of(usize), candidate + 1
                    );
                }
            }
            start = start + 1;
        }
        index = index + 1;
    }
    ptr byte parent_cache = context.control_parent_cache;
    if blocks { parent_cache = context.block_parent_cache; }
    usize node = 0;
    while node < context.syntax.length {
        usize start = read_record_field(context.syntax_data, node, 1);
        usize parent = 0;
        if start < context.expression_start_capacity {
            parent = read_usize(
                context.function_at_position, start * size_of(usize)
            );
            if parent == node + 1 {
                parent = read_usize(
                    second_at_position, start * size_of(usize)
                );
            }
        }
        usize selected = context.syntax.length;
        if parent != 0 && semantic_node_contains(
            context.syntax_data, parent - 1, node
        ) { selected = parent - 1; }
        write_usize(parent_cache, node * size_of(usize), selected);
        node = node + 1;
    }
}

unsafe void ir_initialize_parent_position_caches(ref IrContext context) {
    if context.function_at_position == null ||
        context.expression_start_capacity == 0 { return; }
    ptr byte second_at_position = memory.alloc(
        context.expression_start_capacity * size_of(usize)
    );
    scope memory.free(second_at_position);
    ir_initialize_parent_position_kind(
        context, true, second_at_position
    );
    ir_initialize_parent_position_kind(
        context, false, second_at_position
    );
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
