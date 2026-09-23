import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_json_symbol_identity(ref IrContext context, usize symbol) {
    io.print("\"");
    usize kind = read_record_field(context.symbol_data, symbol, 0);
    if read_record_field(context.detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        usize module_index = read_record_field(
            context.detail_data, symbol, 0
        );
        io.print(project_slice(
            context.project_source,
            read_record_field(context.module_data, module_index, 0),
            read_record_field(context.module_data, module_index, 1)
        ));
        io.print(".");
    }
    text symbol_source;
    status loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, symbol, 1), out symbol_source
    );
    if loaded.ok {
        io.print(project_slice(
            symbol_source,
            read_record_field(context.symbol_data, symbol, 2),
            read_record_field(context.symbol_data, symbol, 3)
        ));
    }
    io.print("\"");
}

unsafe usize ir_type_ref_within(ref IrContext context, usize node) {
    usize selected = context.syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize index = 0;
    usize candidate_count = context.syntax.length;
    if context.type_ref_nodes != null {
        candidate_count = context.type_ref_count;
    }
    context.profile_syntax_candidates =
        context.profile_syntax_candidates + candidate_count;
    while index < candidate_count {
        usize record = index;
        if context.type_ref_nodes != null {
            record = read_usize(
                context.type_ref_nodes, index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, record, 0) == 26 &&
            semantic_node_contains(context.syntax_data, node, record) {
            usize start = read_record_field(context.syntax_data, record, 1);
            if start < selected_start {
                selected = record;
                selected_start = start;
            }
        }
        index = index + 1;
    }
    return selected;
}

unsafe usize ir_resolve_type_node(ref IrContext context, usize type_node) {
    if type_node >= context.syntax.length { return semantic_type_error(); }
    if context.resolved_type_ref_cache != null {
        usize cached = read_usize(
            context.resolved_type_ref_cache,
            type_node * size_of(usize)
        );
        if cached != 0 { return cached - 1; }
    }
    usize resolved = semantic_resolve_type(
        context.project_source, context.project_root,
        context.module_data, context.modules, context.source_data,
        context.source_record, context.source,
        context.token_data, context.tokens,
        context.type_data, context.types,
        read_record_field(context.syntax_data, type_node, 1),
        read_record_field(context.syntax_data, type_node, 2)
    );
    if context.resolved_type_ref_cache != null {
        write_usize(
            context.resolved_type_ref_cache,
            type_node * size_of(usize), resolved + 1
        );
    }
    return resolved;
}

unsafe usize ir_expression_child_after(
    ref IrContext context,
    usize parent,
    usize after,
    bool largest
) {
    if context.expression_start_heads != null &&
        context.expression_start_next != null &&
        context.expression_start_capacity != 0 {
        usize selected = context.syntax.length;
        usize measure = 0;
        usize parent_end = read_record_field(
            context.syntax_data, parent, 1
        ) + read_record_field(context.syntax_data, parent, 2);
        if parent_end > after && context.expression_next_start == null {
            context.profile_expression_positions =
                context.profile_expression_positions + parent_end - after;
        }
        usize cursor = after;
        while cursor < parent_end &&
            cursor < context.expression_start_capacity {
            if context.expression_next_start != null {
                usize next_encoded = read_usize(
                    context.expression_next_start,
                    cursor * size_of(usize)
                );
                if next_encoded == 0 { break; }
                cursor = next_encoded - 1;
                if cursor >= parent_end { break; }
                context.profile_expression_positions =
                    context.profile_expression_positions + 1;
            }
            usize encoded = read_usize(
                context.expression_start_heads,
                cursor * size_of(usize)
            );
            while encoded != 0 {
                usize record = encoded - 1;
                if record != parent && semantic_node_contains(
                    context.syntax_data, parent, record
                ) {
                    usize length = read_record_field(
                        context.syntax_data, record, 2
                    );
                    if largest {
                        if selected == context.syntax.length ||
                            length > measure || (length == measure &&
                            record < selected) {
                            selected = record;
                            measure = length;
                        }
                    } else if selected == context.syntax.length ||
                        record < selected {
                        selected = record;
                    }
                }
                encoded = read_usize(
                    context.expression_start_next,
                    record * size_of(usize)
                );
            }
            if !largest && selected < context.syntax.length {
                return selected;
            }
            cursor = cursor + 1;
        }
        return selected;
    }
    usize fallback_selected = context.syntax.length;
    usize fallback_measure = 0;
    usize fallback_selected_start = cast(usize, 4294967295);
    usize fallback_record = 0;
    while fallback_record < context.syntax.length {
        usize kind = read_record_field(context.syntax_data, fallback_record, 0);
        usize start = read_record_field(context.syntax_data, fallback_record, 1);
        if resolution_expression_kind(kind) && fallback_record != parent &&
            start >= after && semantic_node_contains(
                context.syntax_data, parent, fallback_record
            ) {
            usize length = read_record_field(
                context.syntax_data, fallback_record, 2
            );
            if largest {
                if fallback_selected == context.syntax.length ||
                    length > fallback_measure {
                    fallback_selected = fallback_record;
                    fallback_measure = length;
                }
            } else if start < fallback_selected_start {
                fallback_selected = fallback_record;
                fallback_selected_start = start;
            }
        }
        fallback_record = fallback_record + 1;
    }
    return fallback_selected;
}

unsafe usize ir_enum_value(ref IrContext context, usize symbol) {
    if context.enum_item_value != null && symbol < context.symbols.length {
        usize encoded = read_usize(
            context.enum_item_value, symbol * size_of(usize)
        );
        if encoded != 0 { return encoded - 1; }
    }
    usize owner = read_record_field(context.detail_data, symbol, 2);
    if owner == 0 { return 0; }
    usize requested_node = read_record_field(context.detail_data, symbol, 1);
    usize value = 0;
    usize candidate = 0;
    context.profile_symbol_candidates =
        context.profile_symbol_candidates + context.symbols.length;
    while candidate < context.symbols.length {
        if read_record_field(context.symbol_data, candidate, 0) ==
                resolution_symbol_enum_item() &&
            read_record_field(context.detail_data, candidate, 2) == owner {
            if read_record_field(context.detail_data, candidate, 1) ==
                requested_node { return value; }
            value = value + 1;
        }
        candidate = candidate + 1;
    }
    return value;
}

unsafe usize ir_node_type(
    ref IrContext context,
    usize node,
    usize expected
) {
    if context.profile_type_queries_enabled {
        context.profile_type_queries = context.profile_type_queries + 1;
    }
    bool has_cache = context.type_cache != null &&
        node < context.syntax.length;
    bool cacheable = expected == semantic_type_error() && has_cache;
    if has_cache {
        usize cached = read_usize(
            context.type_cache, node * size_of(usize)
        );
        if cached != 0 {
            usize cached_type = cached - 1;
            if cacheable {
                if context.profile_type_queries_enabled {
                    context.profile_type_cache_hits =
                        context.profile_type_cache_hits + 1;
                }
                return cached_type;
            }
            usize kind = read_record_field(
                context.syntax_data, node, 0
            );
            bool expectation_independent = kind == 27 || kind == 31 ||
                kind == 32 || kind == 38 || kind == 42 || kind == 43 ||
                kind == 44 || kind == 45 || kind == 46 || kind == 47;
            if expectation_independent ||
                ((kind == 39 || kind == 40 || kind == 41) &&
                 cached_type != semantic_type_error()) {
                if context.profile_type_queries_enabled {
                    context.profile_type_cache_hits =
                        context.profile_type_cache_hits + 1;
                }
                return cached_type;
            }
        }
    }
    if context.profile_type_queries_enabled {
        context.profile_type_uncached =
            context.profile_type_uncached + 1;
    }
    usize resolved = ir_node_type_uncached(context, node, expected);
    if context.profile_type_queries_enabled &&
        resolved == semantic_type_error() {
        context.profile_type_failures =
            context.profile_type_failures + 1;
    }
    // A failed lookup can be transient while validation selects a different
    // function/source context or finishes indexing call arguments. Caching
    // only resolved types prevents an early miss from poisoning the fused
    // acceptance/lowering pass while retaining the successful hot path.
    if cacheable && resolved != semantic_type_error() {
        write_usize(
            context.type_cache,
            node * size_of(usize),
            resolved + 1
        );
    }
    return resolved;
}
