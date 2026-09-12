import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
