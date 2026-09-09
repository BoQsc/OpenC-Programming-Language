import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_field_symbol(
    ref IrContext context,
    usize aggregate_symbol,
    usize name_start,
    usize name_length
) {
    return ir_indexed_find_member(
        context, aggregate_symbol + 1,
        resolution_symbol_field(), name_start, name_length
    );
}

unsafe usize ir_qualified_member_type(
    ref IrContext context,
    usize base_symbol,
    usize member_start,
    usize member_length
) {
    usize current_type = read_record_field(
        context.symbol_data, base_symbol, 4
    );
    usize cursor = 0;
    while cursor < member_length {
        usize segment_length = 0;
        while cursor + segment_length < member_length && byte_at_or_zero(
            context.source, member_start + cursor + segment_length
        ) != 46 { segment_length = segment_length + 1; }
        if current_type < context.types.length && read_record_field(
            context.type_data, current_type, 0
        ) == 12 { current_type = ir_type_element(context, current_type); }
        usize current_kind = read_record_field(
            context.type_data, current_type, 0
        );
        if current_type == semantic_type_text() {
            if !span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "length"
            ) { return semantic_type_error(); }
            current_type = semantic_builtin_type("usize", 0, 5);
        } else if current_kind == 10 || current_kind == 11 {
            current_type = semantic_builtin_type("usize", 0, 5);
        } else if current_kind == 14 {
            if span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "present"
            ) { current_type = semantic_type_bool(); }
            else { current_type = ir_type_element(context, current_type); }
        } else if current_type == semantic_type_status() {
            if span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "ok"
            ) { current_type = semantic_type_bool(); }
            else if span_equals_ascii(
                context.source, member_start + cursor,
                segment_length, "code"
            ) { current_type = semantic_builtin_type("i32", 0, 3); }
            else { current_type = semantic_type_text(); }
        } else {
            usize aggregate_symbol = ir_aggregate_for_type(
                context, current_type
            );
            if aggregate_symbol >= context.symbols.length {
                return semantic_type_error();
            }
            usize field = ir_field_symbol(
                context, aggregate_symbol,
                member_start + cursor, segment_length
            );
            if field >= context.symbols.length {
                return semantic_type_error();
            }
            current_type = read_record_field(
                context.symbol_data, field, 4
            );
        }
        cursor = cursor + segment_length + 1;
    }
    return current_type;
}

unsafe usize ir_first_block_start(ref IrContext context, usize parent) {
    usize selected = read_record_field(context.syntax_data, parent, 1) +
        read_record_field(context.syntax_data, parent, 2);
    usize index = 0;
    usize count = context.syntax.length;
    if context.block_nodes != null { count = context.block_count; }
    while index < count {
        usize record = index;
        if context.block_nodes != null {
            record = read_usize(
                context.block_nodes, index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, record, 0) == 11 &&
            semantic_node_contains(context.syntax_data, parent, record) {
            usize start = read_record_field(context.syntax_data, record, 1);
            if start < selected { selected = start; }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_largest_expression_before(
    ref IrContext context,
    usize parent,
    usize before
) {
    if context.expression_start_heads != null &&
        context.expression_start_next != null &&
        context.expression_start_capacity != 0 {
        usize selected = context.syntax.length;
        usize selected_length = 0;
        usize cursor = read_record_field(
            context.syntax_data, parent, 1
        );
        if before > cursor && context.expression_next_start == null {
            context.profile_expression_positions =
                context.profile_expression_positions + before - cursor;
        }
        while cursor < before &&
            cursor < context.expression_start_capacity {
            if context.expression_next_start != null {
                usize next_encoded = read_usize(
                    context.expression_next_start,
                    cursor * size_of(usize)
                );
                if next_encoded == 0 { break; }
                cursor = next_encoded - 1;
                if cursor >= before { break; }
                context.profile_expression_positions =
                    context.profile_expression_positions + 1;
            }
            usize encoded = read_usize(
                context.expression_start_heads,
                cursor * size_of(usize)
            );
            while encoded != 0 {
                usize record = encoded - 1;
                usize length = read_record_field(
                    context.syntax_data, record, 2
                );
                if record != parent && cursor + length <= before &&
                    semantic_node_contains(
                        context.syntax_data, parent, record
                    ) && (selected == context.syntax.length ||
                        length > selected_length ||
                        (length == selected_length && record < selected)) {
                    selected = record;
                    selected_length = length;
                }
                encoded = read_usize(
                    context.expression_start_next,
                    record * size_of(usize)
                );
            }
            cursor = cursor + 1;
        }
        return selected;
    }
    usize fallback_selected = context.syntax.length;
    usize fallback_selected_length = 0;
    usize fallback_record = 0;
    while fallback_record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, fallback_record, 0);
        usize start = read_record_field(context.syntax_data, fallback_record, 1);
        usize end = start + read_record_field(
            context.syntax_data, fallback_record, 2
        );
        if resolution_expression_kind(kind) && fallback_record != parent &&
            end <= before && semantic_node_contains(
                context.syntax_data, parent, fallback_record
            ) {
            usize length = read_record_field(
                context.syntax_data, fallback_record, 2
            );
            if fallback_selected == context.syntax.length ||
                length > fallback_selected_length {
                fallback_selected = fallback_record;
                fallback_selected_length = length;
            }
        }
        fallback_record = fallback_record + 1;
    }
    return fallback_selected;
}

unsafe usize ir_direct_block(
    ref IrContext context,
    usize parent,
    usize requested
) {
    if context.control_block_first != null &&
        context.block_next != null && parent < context.syntax.length {
        usize encoded = read_usize(
            context.control_block_first,
            parent * size_of(usize)
        );
        usize count = 0;
        while encoded != 0 {
            usize block = encoded - 1;
            if count == requested { return block; }
            count = count + 1;
            encoded = read_usize(
                context.block_next, block * size_of(usize)
            );
        }
        return context.syntax.length;
    }
    usize fallback_count = 0;
    usize previous_start = 0;
    usize previous_record = 0;
    bool first = true;
    while true {
        usize selected = context.syntax.length;
        usize selected_start = cast(usize, 4294967295);
        usize selected_record = cast(usize, 4294967295);
        usize index = 0;
        usize candidate_count = context.syntax.length;
        if context.block_nodes != null {
            candidate_count = context.block_count;
        }
        context.profile_parent_candidates =
            context.profile_parent_candidates + candidate_count;
        while index < candidate_count {
            usize record = index;
            if context.block_nodes != null {
                record = read_usize(
                    context.block_nodes, index * size_of(usize)
                );
            }
            if read_record_field(context.syntax_data, record, 0) == 11 &&
                semantic_node_contains(context.syntax_data, parent, record) &&
                ir_control_parent(context, record) == parent {
                usize start = read_record_field(context.syntax_data, record, 1);
                bool after = first || start > previous_start ||
                    (start == previous_start && record > previous_record);
                if after && (selected == context.syntax.length ||
                    start < selected_start ||
                    (start == selected_start && record < selected_record)) {
                    selected = record;
                    selected_start = start;
                    selected_record = record;
                }
            }
            index = index + 1;
        }
        if selected >= context.syntax.length { return context.syntax.length; }
        if fallback_count == requested { return selected; }
        previous_start = selected_start;
        previous_record = selected;
        first = false;
        fallback_count = fallback_count + 1;
    }
    return context.syntax.length;
}

unsafe usize ir_switch_item(
    ref IrContext context,
    usize switch_node,
    usize requested
) {
    if context.control_child_first != null &&
        context.control_child_next != null &&
        switch_node < context.syntax.length {
        usize count = 0;
        usize encoded = read_usize(
            context.control_child_first,
            switch_node * size_of(usize)
        );
        while encoded != 0 {
            usize record = encoded - 1;
            usize kind = read_record_field(
                context.syntax_data, record, 0
            );
            if kind == 18 || kind == 19 {
                if count == requested { return record; }
                count = count + 1;
            }
            encoded = read_usize(
                context.control_child_next,
                record * size_of(usize)
            );
        }
        return context.syntax.length;
    }
    usize fallback_count = 0;
    usize index = 0;
    usize candidate_count = context.syntax.length;
    if context.control_nodes != null {
        candidate_count = context.control_count;
    }
    context.profile_parent_candidates =
        context.profile_parent_candidates + candidate_count;
    while index < candidate_count {
        usize record = index;
        if context.control_nodes != null {
            record = read_usize(
                context.control_nodes, index * size_of(usize)
            );
        }
        usize kind = read_record_field(context.syntax_data, record, 0);
        if (kind == 18 || kind == 19) && semantic_node_contains(
            context.syntax_data, switch_node, record
        ) && ir_control_parent(context, record) == switch_node {
            if fallback_count == requested { return record; }
            fallback_count = fallback_count + 1;
        }
        index = index + 1;
    }
    return context.syntax.length;
}
