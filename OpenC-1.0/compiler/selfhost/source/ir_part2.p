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

unsafe usize ir_resolve_name(ref IrContext context, usize node) {
    ir_select_node_function(context, node);
    if node >= context.syntax.length { return context.symbols.length; }
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
    ptr byte argument_types,
    usize call,
    usize argument,
    usize start,
    usize end
) {
    usize argument_type = semantic_type_error();
    usize argument_node = ir_root_in_bounds(context, start, end);
    if argument_node < context.syntax.length {
        ir_record_call_argument(context, call, argument_node);
        argument_type = ir_node_type(
            context, argument_node, semantic_type_error()
        );
    }
    write_usize(
        argument_types, argument * size_of(usize), argument_type
    );
}

unsafe usize ir_indexed_call_selection(
    ref IrContext context,
    usize call,
    usize first
) {
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_bucket_capacity == 0 ||
        first >= context.symbols.length || read_record_field(
            context.symbol_data, first, 0
        ) != resolution_symbol_function() {
        return flow_call_selection(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.type_data, context.symbol_data,
            context.detail_data, context.symbols,
            context.token_data, context.tokens,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            call, context.source
        );
    }

    usize argument_count = read_record_field(
        context.syntax_data, call, 4
    );
    ptr byte argument_types = memory.alloc(
        (argument_count + 1) * size_of(usize)
    );
    scope memory.free(argument_types);
    usize argument = 0;
    while argument < argument_count {
        write_usize(
            argument_types, argument * size_of(usize),
            semantic_type_error()
        );
        argument = argument + 1;
    }

    usize callee = read_record_field(context.syntax_data, call, 3);
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
    argument = 0;
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
                    context, argument_types, call, argument,
                    argument_start, token_start
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
                        context, argument_types, call, argument,
                        argument_start, token_start
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
    usize callee_start = read_record_field(
        context.syntax_data, callee, 1
    );
    usize callee_length = read_record_field(
        context.syntax_data, callee, 2
    );
    usize scan = 0;
    while scan < callee_length {
        if byte_at_or_zero(context.source, callee_start + scan) == 46 {
            callee_start = callee_start + scan + 1;
            callee_length = callee_length - scan - 1;
            scan = 0;
        } else { scan = scan + 1; }
    }
    usize target_module = read_record_field(
        context.detail_data, first, 0
    );
    usize hash = ir_name_hash(
        context.source, callee_start, callee_length, target_module
    );
    usize encoded = read_usize(
        context.function_bucket_heads,
        (hash % context.function_bucket_capacity) * size_of(usize)
    );
    usize selected = context.symbols.length;
    usize best_conversions = cast(usize, 4294967295);
    bool ambiguous = false;
    while encoded != 0 {
        usize candidate = encoded - 1;
        if read_record_field(context.symbol_data, candidate, 0) ==
                resolution_symbol_function() && read_record_field(
                context.detail_data, candidate, 0
            ) == target_module && resolution_symbol_name_equals(
                context.project_source, context.project_root,
                context.source_data, context.symbol_data,
                candidate, context.source, callee_start, callee_length
            ) && ir_parameter_count(
                context, candidate
            ) == argument_count {
            bool valid = true;
            usize conversions = 0;
            argument = 0;
            while argument < argument_count {
                usize parameter = ir_parameter_at(
                    context, candidate, argument
                );
                if parameter >= context.symbols.length {
                    valid = false;
                    break;
                }
                usize argument_type = read_usize(
                    argument_types, argument * size_of(usize)
                );
                usize parameter_type = read_record_field(
                    context.symbol_data, parameter, 4
                );
                if argument_type != parameter_type {
                    if resolution_lossless(
                        context.type_data, argument_type, parameter_type
                    ) { conversions = conversions + 1; }
                    else { valid = false; }
                }
                argument = argument + 1;
            }
            if valid {
                if selected == context.symbols.length ||
                    conversions < best_conversions {
                    selected = candidate;
                    best_conversions = conversions;
                    ambiguous = false;
                } else if conversions == best_conversions {
                    ambiguous = true;
                }
            }
        }
        encoded = read_usize(
            context.function_bucket_next,
            candidate * size_of(usize)
        );
    }
    if ambiguous { return context.symbols.length; }
    return selected;
}

unsafe usize ir_select_call(ref IrContext context, usize call) {
    ir_select_node_function(context, call);
    if context.call_cache != null && call < context.syntax.length {
        usize cached = read_usize(
            context.call_cache, call * size_of(usize)
        );
        if cached != 0 { return cached - 1; }
    }
    usize selected = context.symbols.length;
    if context.function_bucket_heads == null ||
        context.function_bucket_next == null ||
        context.function_bucket_capacity == 0 {
        selected = flow_call_selection(
            context.project_source, context.project_root,
            context.module_data, context.modules, context.source_data,
            context.type_data, context.symbol_data,
            context.detail_data, context.symbols,
            context.token_data, context.tokens,
            context.syntax_data, context.syntax,
            context.module_index, context.source_record,
            call, context.source
        );
    } else {
        usize callee = read_record_field(context.syntax_data, call, 3);
        usize first = context.symbols.length;
        if callee < context.syntax.length {
            first = ir_resolve_name(context, callee);
        }
        selected = ir_indexed_call_selection(context, call, first);
    }
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
