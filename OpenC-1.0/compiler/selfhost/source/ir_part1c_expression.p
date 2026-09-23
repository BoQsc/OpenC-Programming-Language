import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
    if (context.left_expression_cache != null ||
        context.typed_expression_cache != null) &&
        parent < context.syntax.length {
        usize cached = 0;
        if context.typed_expression_cache != null {
            cached = ir_typed_expression_read(context, parent, 2);
        } else {
            cached = read_usize(
                context.left_expression_cache,
                parent * size_of(usize)
            );
        }
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
        if context.typed_expression_cache != null {
            ir_typed_expression_write(context, parent, 2, cached);
        } else {
            write_usize(
                context.left_expression_cache,
                parent * size_of(usize), cached
            );
        }
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
    if (context.right_expression_cache != null ||
        context.typed_expression_cache != null) &&
        parent < context.syntax.length {
        usize cached = 0;
        if context.typed_expression_cache != null {
            cached = ir_typed_expression_read(context, parent, 3);
        } else {
            cached = read_usize(
                context.right_expression_cache,
                parent * size_of(usize)
            );
        }
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
        if context.typed_expression_cache != null {
            ir_typed_expression_write(context, parent, 3, cached);
        } else {
            write_usize(
                context.right_expression_cache,
                parent * size_of(usize), cached
            );
        }
        return cached;
    }
    return resolution_right_expression(
        context.syntax_data, parent, operator_end
    );
}
