import system.file;
import system.memory;
import system.text;

unsafe bool acceptance_prefix_has(
    ref IrContext context,
    usize declaration,
    text expected
) {
    return semantic_prefix_has(
        context.source, context.token_data, context.tokens,
        read_record_field(context.syntax_data, declaration, 1),
        read_record_field(context.syntax_data, declaration, 3),
        expected
    );
}

unsafe bool acceptance_symbol_named(
    ref IrContext context,
    usize left,
    usize right
) {
    text left_source;
    status left_loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, left, 1), out left_source
    );
    if !left_loaded.ok { return false; }
    text right_source;
    status right_loaded = project_read_source_record(
        context.project_source, context.project_root, context.source_data,
        read_record_field(context.symbol_data, right, 1), out right_source
    );
    if !right_loaded.ok { return false; }
    return semantic_spans_equal(
        left_source,
        read_record_field(context.symbol_data, left, 2),
        read_record_field(context.symbol_data, left, 3),
        right_source,
        read_record_field(context.symbol_data, right, 2),
        read_record_field(context.symbol_data, right, 3)
    );
}

unsafe bool acceptance_known_named_type(
    ref IrContext context,
    usize type_id
) {
    if acceptance_kind(context, type_id) != 9 { return true; }
    if context.type_aggregate_symbols != null &&
        type_id < context.types.length && read_usize(
            context.type_aggregate_symbols, type_id * size_of(usize)
        ) != 0 { return true; }
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if (kind == resolution_symbol_struct() ||
            kind == resolution_symbol_resource() ||
            kind == resolution_symbol_enum()) {
            usize declared = read_record_field(
                context.symbol_data, symbol, 4
            );
            if (declared == type_id) { return true; }
            if acceptance_kind(context, declared) == 9 &&
                read_record_field(context.type_data, declared, 1) ==
                    read_record_field(context.type_data, type_id, 1) &&
                read_record_field(context.type_data, declared, 2) ==
                    read_record_field(context.type_data, type_id, 2) &&
                read_record_field(context.type_data, declared, 3) ==
                    read_record_field(context.type_data, type_id, 3) {
                return true;
            }
        }
        symbol = symbol + 1;
    }
    return false;
}

unsafe usize acceptance_validate_type_refs(ref IrContext context) {
    usize errors = 0;
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.type_ref_nodes != null { node_count = context.type_ref_count; }
    while node_index < node_count {
        usize node = node_index;
        if context.type_ref_nodes != null {
            node = read_usize(
                context.type_ref_nodes, node_index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, node, 0) == 26 {
            usize type_id = ir_resolve_type_node(context, node);
            usize kind = acceptance_kind(context, type_id);
            usize element = type_id;
            while kind >= 10 && kind <= 15 && element < context.types.length {
                element = read_record_field(context.type_data, element, 1);
                kind = acceptance_kind(context, element);
            }
            if !acceptance_known_named_type(context, element) {
                errors = errors + 1;
            }
        }
        node_index = node_index + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_fields(ref IrContext context) {
    usize errors = 0;
    usize symbol = acceptance_source_symbol_first(context);
    usize symbol_end = acceptance_source_symbol_end(context, symbol);
    while symbol < symbol_end {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_field() {
            usize type_id = read_record_field(
                context.symbol_data, symbol, 4
            );
            usize kind = acceptance_kind(context, type_id);
            if kind == 1 || kind == 11 || kind == 12 || kind == 15 {
                errors = errors + 1;
            }
        }
        symbol = symbol + 1;
    }
    return errors;
}

unsafe usize acceptance_validate_locals(ref IrContext context) {
    usize errors = 0;
    usize node_index = 0;
    usize node_count = context.syntax.length;
    if context.statement_nodes != null { node_count = context.statement_count; }
    while node_index < node_count {
        usize node = node_index;
        if context.statement_nodes != null {
            node = read_usize(
                context.statement_nodes, node_index * size_of(usize)
            );
        }
        if read_record_field(context.syntax_data, node, 0) == 12 {
            usize symbol = ir_local_symbol(context, node);
            if symbol < context.symbols.length {
                usize expected = read_record_field(
                    context.symbol_data, symbol, 4
                );
                usize kind = acceptance_kind(context, expected);
                usize initializer = ir_local_initializer_root(context, node);
                if kind == 1 { errors = errors + 1; }
                if kind == 12 && initializer >= context.syntax.length {
                    errors = errors + 1;
                }
                if kind == 14 && acceptance_resource(
                    context, read_record_field(context.type_data, expected, 1)
                ) { errors = errors + 1; }
                if kind == 15 && acceptance_resource(
                    context, read_record_field(context.type_data, expected, 1)
                ) { errors = errors + 1; }
                if acceptance_prefix_has(context, node, "optional") &&
                    flow_span_contains_ascii(
                        context.source,
                        read_record_field(context.syntax_data, node, 1),
                        read_record_field(context.syntax_data, node, 2), "[]"
                    ) { errors = errors + 1; }
                if acceptance_prefix_has(context, node, "const") &&
                    acceptance_resource(context, expected) {
                    errors = errors + 1;
                }
                if initializer < context.syntax.length {
                    usize actual = ir_node_type(
                        context, initializer, semantic_type_error()
                    );
                    if !acceptance_can_initialize(
                        context, initializer, actual, expected
                    ) { errors = errors + 1; }
                }
            }
        }
        node_index = node_index + 1;
    }
    return errors;
}

unsafe bool acceptance_lvalue(ref IrContext context, usize node) {
    if node >= context.syntax.length { return false; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 39 || kind == 40 { return true; }
    if kind == 35 && flow_node_operator(
        context.source, context.syntax_data, node, "*"
    ) { return true; }
    if kind != 27 { return false; }
    if flow_span_has_byte(
        context.source,
        read_record_field(context.syntax_data, node, 1),
        read_record_field(context.syntax_data, node, 2), 46
    ) { return true; }
    usize symbol = ir_resolve_name(context, node);
    if symbol >= context.symbols.length { return false; }
    usize symbol_kind = read_record_field(context.symbol_data, symbol, 0);
    return symbol_kind == resolution_symbol_variable() ||
        symbol_kind == resolution_symbol_parameter() ||
        symbol_kind == resolution_symbol_field();
}

unsafe bool acceptance_mutable(ref IrContext context, usize node) {
    if node >= context.syntax.length { return false; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    if kind == 35 && flow_node_operator(
        context.source, context.syntax_data, node, "*"
    ) {
        usize operator_start = read_record_field(context.syntax_data, node, 3);
        usize child = ir_right_expression(
            context, node,
            operator_start + read_record_field(context.syntax_data, node, 4)
        );
        usize pointer = ir_node_type(
            context, child, semantic_type_error()
        );
        return acceptance_kind(context, pointer) == 13 &&
            !acceptance_const_type(context, pointer);
    }
    usize name = flow_event_first_name(
        context.syntax_data, context.syntax, node
    );
    if kind == 27 { name = node; }
    if name >= context.syntax.length { return true; }
    usize symbol = ir_resolve_name(context, name);
    if symbol >= context.symbols.length { return true; }
    usize declaration = read_record_field(context.detail_data, symbol, 1);
    usize type_id = read_record_field(context.symbol_data, symbol, 4);
    if acceptance_const_type(context, type_id) { return false; }
    return !acceptance_prefix_has(context, declaration, "const");
}
