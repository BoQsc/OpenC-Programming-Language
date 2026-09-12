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
