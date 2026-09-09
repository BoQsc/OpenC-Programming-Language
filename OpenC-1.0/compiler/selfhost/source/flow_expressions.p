import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize flow_emit_cleanups(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize function_node,
    usize function_index
) {
    usize count = 0;
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 23 &&
            semantic_node_contains(syntax_data, function_node, record) {
            usize action = flow_root_expression(syntax_data, syntax, record);
            if action < syntax.length {
                io.print("CLEANUP ");
                io.print(function_index);
                io.print(" ");
                io.print(count);
                io.print(" ");
                io.print(read_record_field(syntax_data, action, 1));
                io.print(" ");
                io.println(read_record_field(syntax_data, action, 2));
                count = count + 1;
            }
        }
        record = record + 1;
    }
    return count;
}

unsafe usize flow_source_frontend_errors(text source) {
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);
    lex_source(
        source, token_data, tokens, diagnostic_data, diagnostics
    );
    PackedBuffer syntax = PackedBuffer{
        length = 0, capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    return diagnostics.length;
}

unsafe usize flow_name_symbol(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize name,
    text source
) {
    return resolution_find_name(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        name, source
    );
}

unsafe usize flow_qualified_function_symbol(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    text source,
    usize start,
    usize length
) {
    usize separator = length;
    usize cursor = 0;
    while cursor < length {
        if byte_at_or_zero(source, start + cursor) == 46 {
            separator = cursor;
        }
        cursor = cursor + 1;
    }
    if separator == length { return symbols.length; }
    usize target_module = modules.length;
    usize module_index = 0;
    while module_index < modules.length {
        usize module_start = read_record_field(
            module_data, module_index, 0
        );
        usize module_length = read_record_field(
            module_data, module_index, 1
        );
        usize short_start = module_start;
        usize module_cursor = 0;
        while module_cursor < module_length {
            if byte_at_or_zero(
                project_source, module_start + module_cursor
            ) == 46 {
                short_start = module_start + module_cursor + 1;
            }
            module_cursor = module_cursor + 1;
        }
        usize short_length = module_start + module_length - short_start;
        bool full_match = semantic_spans_equal(
            source, start, separator,
            project_source,
            module_start, module_length
        );
        bool short_match = semantic_spans_equal(
            source, start, separator,
            project_source, short_start, short_length
        );
        if full_match || short_match {
            target_module = module_index;
            break;
        }
        module_index = module_index + 1;
    }
    if target_module >= modules.length { return symbols.length; }
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            read_record_field(detail_data, symbol, 0) == target_module &&
            resolution_symbol_name_equals(
                project_source, project_root, source_data,
                symbol_data, symbol, source,
                start + separator + 1, length - separator - 1
            ) {
            return symbol;
        }
        symbol = symbol + 1;
    }
    return symbols.length;
}

unsafe usize flow_call_selection(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize call,
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length ||
        read_record_field(syntax_data, callee, 0) != 27 {
        return symbols.length;
    }
    usize first = flow_name_symbol(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        callee, source
    );
    if first >= symbols.length {
        first = flow_qualified_function_symbol(
            project_source, project_root,
            module_data, modules, source_data,
            symbol_data, detail_data, symbols,
            source,
            read_record_field(syntax_data, callee, 1),
            read_record_field(syntax_data, callee, 2)
        );
    }
    if first >= symbols.length { return symbols.length; }
    ResolutionCallSelection selection = resolution_select_call(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, symbol_data, detail_data, symbols,
        token_data, tokens, syntax_data, syntax,
        module_index, source_record, call, source, first
    );
    if selection.ambiguous || selection.symbol >= symbols.length {
        usize qualified = flow_qualified_function_symbol(
            project_source, project_root,
            module_data, modules, source_data,
            symbol_data, detail_data, symbols,
            source,
            read_record_field(syntax_data, callee, 1),
            read_record_field(syntax_data, callee, 2)
        );
        if qualified < symbols.length && qualified != first {
            selection = resolution_select_call(
                project_source, project_root,
                module_data, modules, source_data,
                type_data, symbol_data, detail_data, symbols,
                token_data, tokens, syntax_data, syntax,
                module_index, source_record, call, source, qualified
            );
        }
    }
    if selection.ambiguous { return symbols.length; }
    return selection.symbol;
}

unsafe usize flow_call_declared_target(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize module_index,
    usize source_record,
    usize call,
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length { return symbols.length; }
    return flow_name_symbol(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        callee, source
    );
}

unsafe bool flow_call_is_memory_free(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize call,
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length { return false; }
    usize start = read_record_field(syntax_data, callee, 1);
    usize length = read_record_field(syntax_data, callee, 2);
    return span_equals_ascii(source, start, length, "memory.free") ||
        span_equals_ascii(source, start, length, "system.memory.free");
}

unsafe bool flow_call_is_status_builtin(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize call,
    text source
) {
    usize callee = read_record_field(syntax_data, call, 3);
    if callee >= syntax.length { return false; }
    usize start = read_record_field(syntax_data, callee, 1);
    usize length = read_record_field(syntax_data, callee, 2);
    return span_equals_ascii(source, start, length, "text.scalar_at") ||
        span_equals_ascii(source, start, length, "system.text.scalar_at") ||
        span_equals_ascii(source, start, length, "text.byte_at") ||
        span_equals_ascii(source, start, length, "system.text.byte_at") ||
        span_equals_ascii(source, start, length, "text.slice") ||
        span_equals_ascii(source, start, length, "system.text.slice") ||
        span_equals_ascii(source, start, length, "process.run") ||
        span_equals_ascii(source, start, length, "system.process.run") ||
        span_equals_ascii(source, start, length, "file.read_text") ||
        span_equals_ascii(source, start, length, "system.file.read_text") ||
        span_equals_ascii(source, start, length, "file.read_text_cached") ||
        span_equals_ascii(
            source, start, length, "system.file.read_text_cached"
        ) || span_equals_ascii(
            source, start, length, "file.write_text"
        ) || span_equals_ascii(
            source, start, length, "system.file.write_text"
        ) || span_equals_ascii(
            source, start, length, "file.write_bytes"
        ) || span_equals_ascii(
            source, start, length, "system.file.write_bytes"
        ) || span_equals_ascii(
            source, start, length, "file.read_bytes"
        ) || span_equals_ascii(
            source, start, length, "system.file.read_bytes"
        ) || span_equals_ascii(
            source, start, length, "file.read_bytes_raw"
        ) || span_equals_ascii(
            source, start, length, "system.file.read_bytes_raw"
        );
}

unsafe bool flow_symbol_unsafe(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    usize symbol
) {
    if read_record_field(symbol_data, symbol, 0) !=
        resolution_symbol_function() { return false; }
    text declaration_source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1), out declaration_source
    );
    if !loaded.ok { return false; }
    usize packed = read_record_field(detail_data, symbol, 4);
    usize start = resolution_span_start(packed);
    usize name_start = read_record_field(symbol_data, symbol, 2);
    usize cursor = start;
    while cursor + 6 <= name_start {
        if starts_with_ascii(declaration_source, cursor, "unsafe") {
            return true;
        }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_parameter_own(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    usize parameter
) {
    text declaration_source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, parameter, 1), out declaration_source
    );
    if !loaded.ok { return false; }
    usize packed = read_record_field(detail_data, parameter, 4);
    usize start = resolution_span_start(packed);
    usize name_start = read_record_field(symbol_data, parameter, 2);
    usize cursor = start;
    while cursor + 3 <= name_start {
        if starts_with_ascii(declaration_source, cursor, "own") {
            return true;
        }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool flow_symbol_resource_type(
    ptr byte type_data,
    ptr byte symbol_data,
    usize symbol
) {
    usize type_id = read_record_field(symbol_data, symbol, 4);
    return semantic_type_resource(type_data, type_id);
}

unsafe usize flow_call_argument_name(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize call,
    usize requested
) {
    usize callee = read_record_field(syntax_data, call, 3);
    usize selected = syntax.length;
    usize selected_start = cast(usize, 4294967295);
    usize index = 0;
    while true {
        selected = syntax.length;
        selected_start = cast(usize, 4294967295);
        usize record = 0;
        while record < syntax.length {
            if record != callee &&
                read_record_field(syntax_data, record, 0) == 27 &&
                semantic_node_contains(syntax_data, call, record) {
                usize start = read_record_field(syntax_data, record, 1);
                usize callee_start = read_record_field(
                    syntax_data, callee, 1
                );
                if start > callee_start && start < selected_start {
                    bool already = false;
                    usize earlier = 0;
                    while earlier < syntax.length {
                        if earlier != record && earlier != callee &&
                            read_record_field(syntax_data, earlier, 0) == 27 &&
                            semantic_node_contains(syntax_data, call, earlier) &&
                            read_record_field(syntax_data, earlier, 1) > callee_start &&
                            read_record_field(syntax_data, earlier, 1) < start {
                            already = true;
                        }
                        earlier = earlier + 1;
                    }
                    if (index == 0 && !already) || index != 0 {
                        selected = record;
                        selected_start = start;
                    }
                }
            }
            record = record + 1;
        }
        if index == requested { return selected; }
        if selected >= syntax.length { return syntax.length; }
        index = index + 1;
    }
    return syntax.length;
}
