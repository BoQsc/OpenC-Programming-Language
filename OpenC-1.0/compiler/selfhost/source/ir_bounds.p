import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe IrBounds ir_argument_bounds(
    ref IrContext context,
    usize call,
    usize requested
) {
    usize callee = read_record_field(context.syntax_data, call, 3);
    if callee >= context.syntax.length {
        return IrBounds{ valid = false, start = 0, end = 0 };
    }
    usize callee_end = read_record_field(context.syntax_data, callee, 1) +
        read_record_field(context.syntax_data, callee, 2);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, callee_end
    );
    while token < context.tokens.length && !span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "("
    ) { token = token + 1; }
    if token >= context.tokens.length {
        return IrBounds{ valid = false, start = 0, end = 0 };
    }
    token = token + 1;
    if token >= context.tokens.length {
        return IrBounds{ valid = false, start = 0, end = 0 };
    }
    usize current_start = read_record_field(context.token_data, token, 1);
    usize depth = 0;
    usize index = 0;
    usize call_end = read_record_field(context.syntax_data, call, 1) +
        read_record_field(context.syntax_data, call, 2);
    while token < context.tokens.length &&
        read_record_field(context.token_data, token, 1) < call_end {
        usize start = read_record_field(context.token_data, token, 1);
        usize length = read_record_field(context.token_data, token, 2);
        bool open = span_equals_ascii(context.source, start, length, "(") ||
            span_equals_ascii(context.source, start, length, "[") ||
            span_equals_ascii(context.source, start, length, "{");
        bool close = span_equals_ascii(context.source, start, length, ")") ||
            span_equals_ascii(context.source, start, length, "]") ||
            span_equals_ascii(context.source, start, length, "}");
        if close && depth == 0 {
            if index == requested && start > current_start {
                return IrBounds{
                    valid = true, start = current_start, end = start
                };
            }
            return IrBounds{ valid = false, start = 0, end = 0 };
        }
        if open { depth = depth + 1; }
        if close && depth != 0 { depth = depth - 1; }
        if depth == 0 && span_equals_ascii(
            context.source, start, length, ","
        ) {
            if index == requested {
                return IrBounds{
                    valid = true, start = current_start, end = start
                };
            }
            index = index + 1;
            if token + 1 < context.tokens.length {
                current_start = read_record_field(
                    context.token_data, token + 1, 1
                );
            }
        }
        token = token + 1;
    }
    return IrBounds{ valid = false, start = 0, end = 0 };
}

unsafe usize ir_root_in_bounds(
    ref IrContext context,
    usize start,
    usize end
) {
    usize selected = context.syntax.length;
    usize selected_length = 0;
    usize index = 0;
    usize candidate_count = context.syntax.length;
    if context.expression_nodes != null {
        candidate_count = context.expression_count;
    }
    while index < candidate_count {
        usize record = index;
        if context.expression_nodes != null {
            record = read_usize(
                context.expression_nodes, index * size_of(usize)
            );
        }
        usize kind = read_record_field(context.syntax_data, record, 0);
        usize node_start = read_record_field(context.syntax_data, record, 1);
        usize node_end = node_start +
            read_record_field(context.syntax_data, record, 2);
        if resolution_expression_kind(kind) &&
            node_start >= start && node_end <= end {
            usize length = node_end - node_start;
            if selected == context.syntax.length || length > selected_length {
                selected = record;
                selected_length = length;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_initializer_field_value(
    ref IrContext context,
    usize initializer,
    usize field
) {
    usize after = read_record_field(context.syntax_data, field, 3) +
        read_record_field(context.syntax_data, field, 4);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, after
    );
    if token < context.tokens.length && span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "="
    ) { token = token + 1; }
    if token >= context.tokens.length { return context.syntax.length; }
    usize start = read_record_field(context.token_data, token, 1);
    usize end = read_record_field(context.syntax_data, initializer, 1) +
        read_record_field(context.syntax_data, initializer, 2);
    usize depth = 0;
    while token < context.tokens.length &&
        read_record_field(context.token_data, token, 1) < end {
        usize token_start = read_record_field(context.token_data, token, 1);
        usize token_length = read_record_field(context.token_data, token, 2);
        bool open = span_equals_ascii(
            context.source, token_start, token_length, "("
        ) || span_equals_ascii(
            context.source, token_start, token_length, "["
        ) || span_equals_ascii(
            context.source, token_start, token_length, "{"
        );
        bool close = span_equals_ascii(
            context.source, token_start, token_length, ")"
        ) || span_equals_ascii(
            context.source, token_start, token_length, "]"
        ) || span_equals_ascii(
            context.source, token_start, token_length, "}"
        );
        if depth == 0 && (close || span_equals_ascii(
            context.source, token_start, token_length, ","
        )) { return ir_root_in_bounds(context, start, token_start); }
        if open { depth = depth + 1; }
        if close && depth != 0 { depth = depth - 1; }
        token = token + 1;
    }
    return ir_root_in_bounds(context, start, end);
}

unsafe bool ir_initializer_direct_field(
    ref IrContext context,
    usize initializer,
    usize field
) {
    if field >= context.syntax.length || read_record_field(
        context.syntax_data, field, 0
    ) != 49 || !semantic_node_contains(
        context.syntax_data, initializer, field
    ) { return false; }
    return resolution_smallest_parent(
        context.syntax_data, context.syntax, field, 47, 48, 999
    ) == initializer;
}

unsafe usize ir_nth_child_kind(
    ref IrContext context,
    usize parent,
    usize requested_kind,
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
            if read_record_field(context.syntax_data, record, 0) ==
                    requested_kind && record != parent &&
                semantic_node_contains(context.syntax_data, parent, record) {
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

unsafe IrMemberBase ir_find_local_base(
    ref IrContext context,
    usize node
) {
    ir_select_node_function(context, node);
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    usize dot = 0;
    while dot < length && byte_at_or_zero(context.source, start + dot) != 46 {
        dot = dot + 1;
    }
    if dot >= length {
        return IrMemberBase{
            symbol = context.symbols.length, start = 0, length = 0
        };
    }
    usize member_start = start + dot + 1;
    usize member_length = length - dot - 1;
    usize symbol = resolution_find_local(
        context.project_source, context.project_root,
        context.source_data, context.symbol_data, context.detail_data,
        context.symbols,
        context.function_local_first, context.function_local_end,
        context.syntax_data, context.syntax,
        context.source_record, context.function_symbol + 1,
        context.source, start, dot, start
    );
    if symbol < context.symbols.length && read_usize(
        context.local_values, symbol * size_of(usize)
    ) != 0 {
        return IrMemberBase{
            symbol = symbol, start = member_start,
            length = member_length
        };
    }
    return IrMemberBase{
        symbol = context.symbols.length, start = 0, length = 0
    };
}
