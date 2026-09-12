import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_select_function_locals(
    ref IrContext context,
    usize function_symbol
) {
    if context.function_local_range_first != null &&
        context.function_local_range_end != null &&
        function_symbol < context.symbols.length {
        context.function_local_first = read_usize(
            context.function_local_range_first,
            function_symbol * size_of(usize)
        );
        context.function_local_end = read_usize(
            context.function_local_range_end,
            function_symbol * size_of(usize)
        );
        return;
    }
    context.function_local_first = context.symbols.length;
    context.function_local_end = context.symbols.length;
    usize symbol = 0;
    while symbol < context.symbols.length {
        usize kind = read_record_field(context.symbol_data, symbol, 0);
        if read_record_field(context.detail_data, symbol, 2) ==
                function_symbol + 1 &&
            (kind == resolution_symbol_parameter() ||
             kind == resolution_symbol_variable()) {
            if context.function_local_first == context.symbols.length {
                context.function_local_first = symbol;
            }
            context.function_local_end = symbol + 1;
        }
        symbol = symbol + 1;
    }
}

unsafe void ir_select_node_function(
    ref IrContext context,
    usize node
) {
    if node >= context.syntax.length { return; }
    if context.function_at_position != null {
        usize start = read_record_field(context.syntax_data, node, 1);
        if start < context.expression_start_capacity {
            usize encoded = read_usize(
                context.function_at_position, start * size_of(usize)
            );
            if encoded != 0 {
                usize selected_symbol = encoded - 1;
                context.function_node = read_record_field(
                    context.detail_data, selected_symbol, 1
                );
                context.function_symbol = selected_symbol;
                context.function_result = read_record_field(
                    context.symbol_data, selected_symbol, 4
                );
                ir_select_function_locals(context, selected_symbol);
                return;
            }
            context.function_node = context.syntax.length;
            context.function_symbol = context.symbols.length;
            context.function_result = semantic_type_void();
            context.function_local_first = context.symbols.length;
            context.function_local_end = context.symbols.length;
            return;
        }
    }
    if context.function_node < context.syntax.length &&
        read_record_field(
            context.syntax_data, context.function_node, 0
        ) == 2 && semantic_node_contains(
            context.syntax_data, context.function_node, node
        ) { return; }
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            read_record_field(context.symbol_data, symbol, 1) ==
                context.source_record {
            usize declaration = read_record_field(
                context.detail_data, symbol, 1
            );
            if declaration < context.syntax.length &&
                semantic_node_contains(
                    context.syntax_data, declaration, node
                ) {
                context.function_node = declaration;
                context.function_symbol = symbol;
                context.function_result = read_record_field(
                    context.symbol_data, symbol, 4
                );
                ir_select_function_locals(context, symbol);
                return;
            }
        }
        symbol = symbol + 1;
    }
    context.function_node = context.syntax.length;
    context.function_symbol = context.symbols.length;
    context.function_result = semantic_type_void();
    context.function_local_first = context.symbols.length;
    context.function_local_end = context.symbols.length;
}

unsafe usize ir_emit_value(
    ref IrContext context,
    usize opcode,
    usize type_id,
    usize node,
    usize text_kind,
    usize text_one,
    usize text_two,
    usize operand_first,
    usize operand_count
) {
    return ir_emit_instruction(
        context, opcode, type_id,
        read_record_field(context.syntax_data, node, 1),
        read_record_field(context.syntax_data, node, 2),
        text_kind, text_one, text_two,
        operand_first, operand_count, true
    );
}

unsafe void ir_emit_void(
    ref IrContext context,
    usize opcode,
    usize node,
    usize text_kind,
    usize text_one,
    usize text_two,
    usize operand_first,
    usize operand_count
) {
    ir_emit_instruction(
        context, opcode, semantic_type_void(),
        read_record_field(context.syntax_data, node, 1),
        read_record_field(context.syntax_data, node, 2),
        text_kind, text_one, text_two,
        operand_first, operand_count, false
    );
}

unsafe usize ir_spelling_cache_entry(
    ref IrContext context,
    usize start,
    usize length,
    usize hash
) {
    if context.spelling_cache == null ||
        context.spelling_cache_capacity == 0 {
        return context.spelling_cache_capacity;
    }
    usize entry = hash % context.spelling_cache_capacity;
    usize probes = 0;
    while probes < context.spelling_cache_capacity {
        usize encoded = read_record_field(
            context.spelling_cache, entry, 4
        );
        if encoded == 0 { return context.spelling_cache_capacity; }
        if read_record_field(context.spelling_cache, entry, 0) ==
                context.function_symbol + 1 &&
            read_record_field(context.spelling_cache, entry, 1) == hash &&
            read_record_field(context.spelling_cache, entry, 3) == length &&
            semantic_spans_equal(
                context.source, start, length,
                context.source,
                read_record_field(context.spelling_cache, entry, 2),
                length
            ) { return entry; }
        entry = (entry + 1) % context.spelling_cache_capacity;
        probes = probes + 1;
    }
    return context.spelling_cache_capacity;
}

unsafe void ir_cache_name_resolution(
    ref IrContext context,
    usize node,
    usize start,
    usize length,
    usize hash,
    usize resolved
) {
    if context.name_cache != null && node < context.syntax.length {
        write_usize(
            context.name_cache, node * size_of(usize), resolved + 1
        );
    }
    if context.spelling_cache == null ||
        context.spelling_cache_capacity == 0 { return; }
    usize entry = hash % context.spelling_cache_capacity;
    usize probes = 0;
    while probes < context.spelling_cache_capacity {
        usize encoded = read_record_field(
            context.spelling_cache, entry, 4
        );
        bool same = encoded != 0 && read_record_field(
                context.spelling_cache, entry, 0
            ) == context.function_symbol + 1 && read_record_field(
                context.spelling_cache, entry, 1
            ) == hash && read_record_field(
                context.spelling_cache, entry, 3
            ) == length && semantic_spans_equal(
                context.source, start, length,
                context.source,
                read_record_field(context.spelling_cache, entry, 2),
                length
            );
        if encoded == 0 || same {
            write_record_field(
                context.spelling_cache, entry, 0,
                context.function_symbol + 1
            );
            write_record_field(context.spelling_cache, entry, 1, hash);
            write_record_field(context.spelling_cache, entry, 2, start);
            write_record_field(context.spelling_cache, entry, 3, length);
            write_record_field(
                context.spelling_cache, entry, 4, resolved + 1
            );
            return;
        }
        entry = (entry + 1) % context.spelling_cache_capacity;
        probes = probes + 1;
    }
}
