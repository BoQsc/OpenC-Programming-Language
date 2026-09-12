import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
    context.call_count = 0;
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
        if kind == 38 && context.call_nodes != null {
            write_usize(
                context.call_nodes,
                context.call_count * size_of(usize), node
            );
            context.call_count = context.call_count + 1;
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
