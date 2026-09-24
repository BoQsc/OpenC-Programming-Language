import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_resolve_name(ref IrContext context, usize node) {
    ir_select_node_function(context, node);
    if node >= context.syntax.length { return context.symbols.length; }
    // Integer literals use this otherwise vacant slot for their typed value.
    if read_record_field(context.syntax_data, node, 0) == 29 {
        return context.symbols.length;
    }
    if context.name_cache != null && node < context.syntax.length {
        usize cached = read_usize(
            context.name_cache, node * size_of(usize)
        );
        if cached != 0 { return cached - 1; }
    }
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    usize hash = 0;
    if context.spelling_cache != null &&
        context.spelling_cache_capacity != 0 {
        hash = ir_name_hash(
            context.source, start, length, context.function_symbol + 1
        );
        usize spelling_entry = ir_spelling_cache_entry(
            context, start, length, hash
        );
        if spelling_entry < context.spelling_cache_capacity {
            usize cached = read_record_field(
                context.spelling_cache, spelling_entry, 4
            ) - 1;
            if context.name_cache != null {
                write_usize(
                    context.name_cache, node * size_of(usize), cached + 1
                );
            }
            return cached;
        }
    }
    usize resolved = context.symbols.length;
    if context.function_node < context.syntax.length &&
        read_record_field(
            context.syntax_data, context.function_node, 0
        ) == 2 && semantic_node_contains(
            context.syntax_data, context.function_node, node
        ) {
        usize first_length = length;
        usize dot = 0;
        while dot < length {
            if byte_at_or_zero(context.source, start + dot) == 46 {
                first_length = dot;
                break;
            }
            dot = dot + 1;
        }
        usize local = ir_indexed_find_local(
            context, context.function_symbol + 1,
            start, first_length, start
        );
        if local < context.symbols.length {
            if first_length == length {
                resolved = local;
                ir_cache_name_resolution(
                    context, node, start, length, hash, resolved
                );
                return resolved;
            }
            usize aggregate = ir_aggregate_for_type(
                context,
                read_record_field(context.symbol_data, local, 4)
            );
            if aggregate < context.symbols.length {
                usize member = ir_indexed_find_member(
                    context,
                    aggregate + 1, resolution_symbol_field(),
                    start + first_length + 1,
                    length - first_length - 1
                );
                if member < context.symbols.length {
                    resolved = member;
                    ir_cache_name_resolution(
                        context, node, start, length, hash, resolved
                    );
                    return resolved;
                }
            }
        }
        resolved = ir_find_nonlocal_name(
            context, start, length, first_length
        );
    } else {
        resolved = flow_name_symbol(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.symbol_data, context.detail_data, context.symbols,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            node, context.source
        );
    }
    ir_cache_name_resolution(
        context, node, start, length, hash, resolved
    );
    return resolved;
}

unsafe void ir_record_argument_type(
    ref IrContext context,
    usize call,
    usize start,
    usize end
) {
    usize argument_node = ir_root_in_bounds(context, start, end);
    if argument_node < context.syntax.length {
        ir_record_call_argument(context, call, argument_node);
    }
}

unsafe void ir_index_call_arguments(
    ref IrContext context,
    usize call
) {
    if call >= context.syntax.length { return; }
    usize argument_count = read_record_field(
        context.syntax_data, call, 4
    );
    if argument_count == 0 || context.call_argument_first == null ||
        context.call_argument_last == null || context.argument_next == null ||
        read_usize(
            context.call_argument_first, call * size_of(usize)
        ) != 0 { return; }
    usize callee = read_record_field(context.syntax_data, call, 3);
    if callee >= context.syntax.length { return; }
    usize callee_end = read_record_field(
        context.syntax_data, callee, 1
    ) + read_record_field(context.syntax_data, callee, 2);
    usize token = semantic_token_at_or_after(
        context.token_data, context.tokens, callee_end
    );
    while token < context.tokens.length && !span_equals_ascii(
        context.source,
        read_record_field(context.token_data, token, 1),
        read_record_field(context.token_data, token, 2), "("
    ) { token = token + 1; }
    if token < context.tokens.length { token = token + 1; }
    usize argument = 0;
    usize depth = 0;
    usize argument_start = callee_end;
    if token < context.tokens.length {
        argument_start = read_record_field(
            context.token_data, token, 1
        );
    }
    usize call_end = read_record_field(context.syntax_data, call, 1) +
        read_record_field(context.syntax_data, call, 2);
    while token < context.tokens.length &&
        read_record_field(context.token_data, token, 1) < call_end {
        usize token_start = read_record_field(
            context.token_data, token, 1
        );
        usize token_length = read_record_field(
            context.token_data, token, 2
        );
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
        if close && depth == 0 {
            if argument < argument_count && token_start > argument_start {
                ir_record_argument_type(
                    context, call, argument_start, token_start
                );
            }
            token = context.tokens.length;
        } else {
            if open { depth = depth + 1; }
            if close && depth != 0 { depth = depth - 1; }
            if depth == 0 && span_equals_ascii(
                context.source, token_start, token_length, ","
            ) {
                if argument < argument_count {
                    ir_record_argument_type(
                        context, call, argument_start, token_start
                    );
                }
                argument = argument + 1;
                if token + 1 < context.tokens.length {
                    argument_start = read_record_field(
                        context.token_data, token + 1, 1
                    );
                }
            }
            token = token + 1;
        }
    }
}
