import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe bool resolution_block_contains_use(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration,
    usize use_start
) {
    usize selected = syntax.length;
    usize selected_length = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        if read_record_field(syntax_data, record, 0) == 11 &&
            semantic_node_contains(syntax_data, record, declaration) {
            usize length = read_record_field(syntax_data, record, 2);
            if length < selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    if selected >= syntax.length { return true; }
    usize start = read_record_field(syntax_data, selected, 1);
    usize end = start + read_record_field(syntax_data, selected, 2);
    return use_start >= start && use_start < end;
}

unsafe usize resolution_find_local(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize symbol_first,
    usize symbol_end,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize source_record,
    usize function_owner,
    text source,
    usize name_start,
    usize name_length,
    usize use_start
) {
    usize selected = symbols.length;
    usize selected_start = 0;
    usize symbol = symbol_first;
    while symbol < symbol_end && symbol < symbols.length {
        usize kind = read_record_field(symbol_data, symbol, 0);
        if read_record_field(symbol_data, symbol, 1) == source_record &&
            read_record_field(detail_data, symbol, 2) == function_owner &&
            (kind == resolution_symbol_parameter() ||
             kind == resolution_symbol_variable()) &&
            semantic_spans_equal(
                source, name_start, name_length,
                source,
                read_record_field(symbol_data, symbol, 2),
                read_record_field(symbol_data, symbol, 3)
            ) {
            usize declaration_start = read_record_field(
                syntax_data,
                read_record_field(detail_data, symbol, 1), 1
            );
            if kind == resolution_symbol_parameter() ||
                (declaration_start < use_start &&
                 resolution_block_contains_use(
                    syntax_data, syntax,
                    read_record_field(detail_data, symbol, 1), use_start
                 )) {
                if selected == symbols.length || declaration_start >= selected_start {
                    selected = symbol;
                    selected_start = declaration_start;
                }
            }
        }
        symbol = symbol + 1;
    }
    return selected;
}

unsafe bool resolution_is_exported(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    usize symbol
) {
    text source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1), out source
    );
    if !loaded.ok { return false; }
    usize name_start = read_record_field(symbol_data, symbol, 2);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = name_start + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = name_start * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(project_slice(source, 0, name_start), token_data, tokens,
        diagnostic_data, diagnostics);
    bool exported = false;
    usize token = 0;
    while token < tokens.length {
        usize start = read_record_field(token_data, token, 1);
        usize length = read_record_field(token_data, token, 2);
        if span_equals_ascii(source, start, length, ";") ||
            span_equals_ascii(source, start, length, "{") ||
            span_equals_ascii(source, start, length, "}") {
            exported = false;
        }
        if span_equals_ascii(source, start, length, "export") {
            exported = true;
        }
        token = token + 1;
    }
    return exported;
}

unsafe usize resolution_find_top_unqualified(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize module_index,
    usize source_record,
    text source,
    usize start,
    usize length
) {
    usize symbol = 0;
    while symbol < symbols.length {
        usize kind = read_record_field(symbol_data, symbol, 0);
        if read_record_field(detail_data, symbol, 0) == module_index &&
            read_record_field(detail_data, symbol, 2) == 0 &&
            kind != resolution_symbol_field() &&
            kind != resolution_symbol_enum_item() {
            bool same_name = false;
            if read_record_field(
                symbol_data, symbol, 1
            ) == source_record {
                same_name = semantic_spans_equal(
                    source, start, length,
                    source,
                    read_record_field(symbol_data, symbol, 2),
                    read_record_field(symbol_data, symbol, 3)
                );
            } else {
                same_name = resolution_symbol_name_equals(
                    project_source, project_root, source_data,
                    symbol_data, symbol, source, start, length
                );
            }
            if same_name { return symbol; }
        }
        symbol = symbol + 1;
    }
    return symbols.length;
}

unsafe usize resolution_find_member(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize owner,
    usize required_kind,
    text source,
    usize start,
    usize length
) {
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(detail_data, symbol, 2) == owner &&
            read_record_field(symbol_data, symbol, 0) == required_kind &&
            resolution_symbol_name_equals(
                project_source, project_root, source_data,
                symbol_data, symbol, source, start, length
            ) { return symbol; }
        symbol = symbol + 1;
    }
    return symbols.length;
}

unsafe usize resolution_find_aggregate_for_type(
    ptr byte symbol_data,
    ref PackedBuffer symbols,
    usize type_id
) {
    usize symbol = 0;
    while symbol < symbols.length {
        usize kind = read_record_field(symbol_data, symbol, 0);
        if (read_record_field(symbol_data, symbol, 4) == type_id) &&
            (kind == resolution_symbol_struct() ||
             kind == resolution_symbol_resource()) {
            return symbol;
        }
        symbol = symbol + 1;
    }
    return symbols.length;
}

unsafe usize resolution_find_nonlocal_name(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize module_index,
    usize source_record,
    text source,
    usize start,
    usize length,
    usize first_length
) {
    if first_length != length {
        usize enum_symbol = resolution_find_top_unqualified(
            project_source, project_root, source_data,
            symbol_data, detail_data, symbols,
            module_index, source_record, source, start, first_length
        );
        if enum_symbol < symbols.length &&
            read_record_field(symbol_data, enum_symbol, 0) ==
                resolution_symbol_enum() {
            usize item = resolution_find_member(
                project_source, project_root, source_data,
                symbol_data, detail_data, symbols,
                enum_symbol + 1, resolution_symbol_enum_item(),
                source, start + first_length + 1,
                length - first_length - 1
            );
            if item < symbols.length { return item; }
        }
        usize candidate_module = 0;
        while candidate_module < modules.length {
            usize module_length = read_record_field(
                module_data, candidate_module, 1
            );
            usize qualifier_length = module_length;
            usize module_start = read_record_field(
                module_data, candidate_module, 0
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
            bool full_qualifier = module_length < length &&
                byte_at_or_zero(source, start + module_length) == 46 &&
                resolution_module_name_equals(
                    project_source, module_data, candidate_module,
                    source, start, module_length
                );
            bool short_qualifier = short_length == first_length &&
                first_length < length && semantic_spans_equal(
                    source, start, first_length,
                    project_source, short_start, short_length
                );
            if short_qualifier { qualifier_length = first_length; }
            if full_qualifier || short_qualifier {
                usize direct = resolution_find_top_unqualified(
                    project_source, project_root, source_data,
                    symbol_data, detail_data, symbols,
                    candidate_module, source_record, source,
                    start + qualifier_length + 1,
                    length - qualifier_length - 1
                );
                if direct < symbols.length && (candidate_module == module_index ||
                    resolution_is_exported(project_source, project_root,
                        source_data, symbol_data, direct)) { return direct; }
            }
            candidate_module = candidate_module + 1;
        }
    } else {
        usize top = resolution_find_top_unqualified(
            project_source, project_root, source_data,
            symbol_data, detail_data, symbols,
            module_index, source_record, source, start, length
        );
        if top < symbols.length { return top; }
    }
    return symbols.length;
}
