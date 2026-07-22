import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_select_function_locals(
    ref IrContext context,
    usize function_symbol
) {
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

unsafe usize ir_resolve_name(ref IrContext context, usize node) {
    ir_select_node_function(context, node);
    if context.name_cache != null && node < context.syntax.length {
        usize cached = read_usize(
            context.name_cache, node * size_of(usize)
        );
        if cached != 0 { return cached - 1; }
    }
    usize resolved = context.symbols.length;
    if context.function_node < context.syntax.length &&
        read_record_field(
            context.syntax_data, context.function_node, 0
        ) == 2 && semantic_node_contains(
            context.syntax_data, context.function_node, node
        ) {
        usize start = read_record_field(context.syntax_data, node, 1);
        usize length = read_record_field(context.syntax_data, node, 2);
        usize first_length = length;
        usize dot = 0;
        while dot < length {
            if byte_at_or_zero(context.source, start + dot) == 46 {
                first_length = dot;
                break;
            }
            dot = dot + 1;
        }
        usize local = resolution_find_local(
            context.project_source, context.project_root,
            context.source_data, context.symbol_data, context.detail_data,
            context.symbols,
            context.function_local_first, context.function_local_end,
            context.syntax_data, context.syntax,
            context.source_record, context.function_symbol + 1,
            context.source, start, first_length, start
        );
        if local < context.symbols.length {
            if first_length == length {
                resolved = local;
                if context.name_cache != null {
                    write_usize(
                        context.name_cache, node * size_of(usize), resolved + 1
                    );
                }
                return resolved;
            }
            usize aggregate = resolution_find_aggregate_for_type(
                context.symbol_data, context.symbols,
                read_record_field(context.symbol_data, local, 4)
            );
            if aggregate < context.symbols.length {
                usize member = resolution_find_member(
                    context.project_source, context.project_root,
                    context.source_data, context.symbol_data,
                    context.detail_data, context.symbols,
                    aggregate + 1, resolution_symbol_field(),
                    context.source, start + first_length + 1,
                    length - first_length - 1
                );
                if member < context.symbols.length {
                    resolved = member;
                    if context.name_cache != null {
                        write_usize(
                            context.name_cache, node * size_of(usize), resolved + 1
                        );
                    }
                    return resolved;
                }
            }
        }
        resolved = resolution_find_nonlocal_name(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.symbol_data, context.detail_data, context.symbols,
            context.module_index, context.source_record, context.source,
            start, length, first_length
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
    if context.name_cache != null && node < context.syntax.length {
        write_usize(
            context.name_cache, node * size_of(usize), resolved + 1
        );
    }
    return resolved;
}

unsafe usize ir_select_call(ref IrContext context, usize call) {
    ir_select_node_function(context, call);
    if context.call_cache != null && call < context.syntax.length {
        usize cached = read_usize(
            context.call_cache, call * size_of(usize)
        );
        if cached != 0 { return cached - 1; }
    }
    usize selected = flow_call_selection(
        context.project_source, context.project_root,
        context.module_data, context.modules, context.source_data,
        context.type_data, context.symbol_data,
        context.detail_data, context.symbols,
        context.token_data, context.tokens,
        context.syntax_data, context.syntax,
        context.module_index, context.source_record,
        call, context.source
    );
    if selected >= context.symbols.length {
        selected = flow_call_declared_target(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.symbol_data, context.detail_data, context.symbols,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            call, context.source
        );
    }
    if context.call_cache != null && call < context.syntax.length {
        write_usize(
            context.call_cache, call * size_of(usize), selected + 1
        );
    }
    return selected;
}

void ir_json_hex4(usize value) {
    io.print(project_hex_digit((value / 4096) % 16));
    io.print(project_hex_digit((value / 256) % 16));
    io.print(project_hex_digit((value / 16) % 16));
    io.print(project_hex_digit(value % 16));
}

void ir_json_slice(text value, usize start, usize length) {
    // Emit Unicode escapes from byte spans. This keeps byte-addressed source
    // spans exact even when text.slice would interpret offsets as code points.
    io.print("\"");
    usize cursor = 0;
    while cursor < length {
        usize first = cast(usize, byte_at_or_zero(value, start + cursor));
        usize codepoint = first;
        usize consumed = 1;
        if first >= 194 && first <= 223 && cursor + 1 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            codepoint = (first % 32) * 64 + second % 64;
            consumed = 2;
        } else if first >= 224 && first <= 239 && cursor + 2 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            usize third = cast(usize, byte_at_or_zero(
                value, start + cursor + 2
            ));
            codepoint = (first % 16) * 4096 +
                (second % 64) * 64 + third % 64;
            consumed = 3;
        } else if first >= 240 && first <= 244 && cursor + 3 < length {
            usize second = cast(usize, byte_at_or_zero(
                value, start + cursor + 1
            ));
            usize third = cast(usize, byte_at_or_zero(
                value, start + cursor + 2
            ));
            usize fourth = cast(usize, byte_at_or_zero(
                value, start + cursor + 3
            ));
            codepoint = (first % 8) * 262144 +
                (second % 64) * 4096 +
                (third % 64) * 64 + fourth % 64;
            consumed = 4;
        }
        if codepoint <= 65535 {
            io.print("\\u");
            ir_json_hex4(codepoint);
        } else {
            usize scalar = codepoint - 65536;
            io.print("\\u");
            ir_json_hex4(55296 + scalar / 1024);
            io.print("\\u");
            ir_json_hex4(56320 + scalar % 1024);
        }
        cursor = cursor + consumed;
    }
    io.print("\"");
}

void ir_json_text(text value) {
    ir_json_slice(value, 0, text.byte_length(value));
}

unsafe void ir_emit_symbol_name(ref IrContext context, usize symbol) {
    usize kind = read_record_field(context.symbol_data, symbol, 0);
    if read_record_field(context.detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        usize module_index = read_record_field(
            context.detail_data, symbol, 0
        );
        ir_json_slice(
            context.project_source,
            read_record_field(context.module_data, module_index, 0),
            read_record_field(context.module_data, module_index, 1)
        );
        // Symbol identities need one JSON string. The caller uses the
        // dedicated combined form below instead of this helper.
    }
}
