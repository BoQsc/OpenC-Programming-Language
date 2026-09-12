import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
            usize module_start = read_record_field(
                context.module_data, candidate_module, 0
            );
            usize short_start = module_start;
            usize module_cursor = 0;
            while module_cursor < module_length {
                if byte_at_or_zero(
                    context.project_source, module_start + module_cursor
                ) == 46 {
                    short_start = module_start + module_cursor + 1;
                }
                module_cursor = module_cursor + 1;
            }
            usize short_length = module_start + module_length - short_start;
            usize qualifier_length = module_length;
            bool full_qualifier = module_length < length && byte_at_or_zero(
                context.source, start + module_length
            ) == 46 && resolution_module_name_equals(
                context.project_source, context.module_data,
                candidate_module, context.source, start, module_length
            );
            bool short_qualifier = short_length == first_length &&
                first_length < length && semantic_spans_equal(
                    context.source, start, first_length,
                    context.project_source, short_start, short_length
                );
            if short_qualifier { qualifier_length = first_length; }
            if full_qualifier || short_qualifier {
                usize direct = ir_find_top_unqualified(
                    context, candidate_module,
                    start + qualifier_length + 1,
                    length - qualifier_length - 1
                );
                if direct < context.symbols.length &&
                    (candidate_module == context.module_index ||
                    resolution_is_exported(context.project_source,
                        context.project_root, context.source_data,
                        context.symbol_data, direct)) { return direct; }
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
    usize fallback_selected = context.syntax.length;
    usize fallback_selected_start = cast(usize, 4294967295);
    usize index = 0;
    while index < context.name_count {
        usize record = read_usize(
            context.name_nodes, index * size_of(usize)
        );
        if semantic_node_contains(context.syntax_data, event, record) {
            usize start = read_record_field(
                context.syntax_data, record, 1
            );
            if start < fallback_selected_start {
                fallback_selected = record;
                fallback_selected_start = start;
            }
        }
        index = index + 1;
    }
    return fallback_selected;
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
