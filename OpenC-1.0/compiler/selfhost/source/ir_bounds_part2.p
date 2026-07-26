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
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_field() &&
            read_record_field(context.detail_data, symbol, 2) ==
                aggregate_symbol + 1 &&
            resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data, symbol,
                context.source, name_start, name_length
            ) { return symbol; }
        symbol = symbol + 1;
    }
    return context.symbols.length;
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
            usize aggregate_symbol = context.symbols.length;
            usize candidate = 0;
            while candidate < context.symbols.length {
                usize candidate_kind = read_record_field(
                    context.symbol_data, candidate, 0
                );
                if (candidate_kind == resolution_symbol_struct() ||
                    candidate_kind == resolution_symbol_resource()) &&
                    read_record_field(
                        context.symbol_data, candidate, 4
                    ) == current_type {
                    aggregate_symbol = candidate;
                    break;
                }
                candidate = candidate + 1;
            }
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
    usize record = 0;
    while record < context.syntax.length {
        if read_record_field(context.syntax_data, record, 0) == 11 &&
            semantic_node_contains(context.syntax_data, parent, record) {
            usize start = read_record_field(context.syntax_data, record, 1);
            if start < selected { selected = start; }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_largest_expression_before(
    ref IrContext context,
    usize parent,
    usize before
) {
    usize selected = context.syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, record, 0);
        usize start = read_record_field(context.syntax_data, record, 1);
        usize end = start + read_record_field(context.syntax_data, record, 2);
        if resolution_expression_kind(kind) && record != parent &&
            end <= before && semantic_node_contains(
                context.syntax_data, parent, record
            ) {
            usize length = read_record_field(context.syntax_data, record, 2);
            if selected == context.syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize ir_direct_block(
    ref IrContext context,
    usize parent,
    usize requested
) {
    usize count = 0;
    usize previous_start = 0;
    usize previous_record = 0;
    bool first = true;
    while true {
        usize selected = context.syntax.length;
        usize selected_start = cast(usize, 4294967295);
        usize selected_record = cast(usize, 4294967295);
        usize record = 0;
        while record < context.syntax.length {
            if read_record_field(context.syntax_data, record, 0) == 11 &&
                semantic_node_contains(context.syntax_data, parent, record) &&
                flow_control_parent(
                    context.syntax_data, context.syntax, record
                ) == parent {
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
            record = record + 1;
        }
        if selected >= context.syntax.length { return context.syntax.length; }
        if count == requested { return selected; }
        previous_start = selected_start;
        previous_record = selected;
        first = false;
        count = count + 1;
    }
    return context.syntax.length;
}

unsafe usize ir_switch_item(
    ref IrContext context,
    usize switch_node,
    usize requested
) {
    usize count = 0;
    usize record = 0;
    while record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, record, 0);
        if (kind == 18 || kind == 19) && semantic_node_contains(
            context.syntax_data, switch_node, record
        ) && resolution_smallest_parent(
            context.syntax_data, context.syntax, record, 17, 999, 998
        ) == switch_node {
            if count == requested { return record; }
            count = count + 1;
        }
        record = record + 1;
    }
    return context.syntax.length;
}
