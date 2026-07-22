import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize resolution_find_name(
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
    usize node,
    text source
) {
    usize start = read_record_field(syntax_data, node, 1);
    usize length = read_record_field(syntax_data, node, 2);
    usize first_length = length;
    usize dot = 0;
    while dot < length {
        if byte_at_or_zero(source, start + dot) == 46 {
            first_length = dot;
            break;
        }
        dot = dot + 1;
    }
    usize function_owner = resolution_function_for_node(
        syntax_data, syntax, node,
        symbol_data, detail_data, symbols, source_record
    );
    if function_owner != 0 {
        usize local = resolution_find_local(
            project_source, project_root, source_data,
            symbol_data, detail_data, symbols,
            0, symbols.length,
            syntax_data, syntax, source_record, function_owner,
            source, start, first_length, start
        );
        if local < symbols.length {
            if first_length == length { return local; }
            usize aggregate = resolution_find_aggregate_for_type(
                symbol_data, symbols,
                read_record_field(symbol_data, local, 4)
            );
            if aggregate < symbols.length {
                return resolution_find_member(
                    project_source, project_root, source_data,
                    symbol_data, detail_data, symbols,
                    aggregate + 1, resolution_symbol_field(),
                    source, start + first_length + 1,
                    length - first_length - 1
                );
            }
        }
    }
    return resolution_find_nonlocal_name(
        project_source, project_root, module_data, modules,
        source_data, symbol_data, detail_data, symbols,
        module_index, source_record, source,
        start, length, first_length
    );
}

unsafe bool resolution_name_excluded(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize node
) {
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if record != node && (kind == 1 || kind == 26) &&
            semantic_node_contains(syntax_data, record, node) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe bool resolution_name_is_unchecked_operand(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize node
) {
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if kind == 38 && read_record_field(syntax_data, record, 3) == node {
            return true;
        }
        if kind == 48 &&
            read_record_field(syntax_data, record, 1) ==
                read_record_field(syntax_data, node, 1) &&
            semantic_node_contains(syntax_data, record, node) {
            return true;
        }
        record = record + 1;
    }
    return false;
}

unsafe void resolution_emit_symbol_identity(
    text project_source,
    text project_root,
    ptr byte module_data,
    ptr byte source_data,
    ptr byte symbol_data,
    ptr byte detail_data,
    usize symbol
) {
    usize kind = read_record_field(symbol_data, symbol, 0);
    if read_record_field(detail_data, symbol, 2) == 0 &&
        kind != resolution_symbol_field() &&
        kind != resolution_symbol_enum_item() {
        usize module_index = read_record_field(detail_data, symbol, 0);
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print("2e");
    }
    text symbol_source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1), out symbol_source
    );
    if loaded.ok {
        project_emit_hex(project_slice(
            symbol_source,
            read_record_field(symbol_data, symbol, 2),
            read_record_field(symbol_data, symbol, 3)
        ));
    }
}

unsafe usize resolution_parameter_count(
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize function_symbol
) {
    usize count = 0;
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) == resolution_symbol_parameter() &&
            read_record_field(detail_data, symbol, 2) == function_symbol + 1 {
            count = count + 1;
        }
        symbol = symbol + 1;
    }
    return count;
}

unsafe usize resolution_nth_parameter(
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize function_symbol,
    usize requested
) {
    usize index = 0;
    usize symbol = 0;
    while symbol < symbols.length {
        if read_record_field(symbol_data, symbol, 0) == resolution_symbol_parameter() &&
            read_record_field(detail_data, symbol, 2) == function_symbol + 1 {
            if index == requested { return symbol; }
            index = index + 1;
        }
        symbol = symbol + 1;
    }
    return symbols.length;
}

unsafe usize resolution_token_after_span(
    ptr byte token_data,
    ref PackedBuffer tokens,
    usize start,
    usize length
) {
    return semantic_token_at_or_after(token_data, tokens, start + length);
}

unsafe usize resolution_argument_type(
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
    text source,
    usize start,
    usize end
) {
    usize best = syntax.length;
    usize best_length = 0;
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        usize node_start = read_record_field(syntax_data, record, 1);
        usize node_end = node_start + read_record_field(syntax_data, record, 2);
        if node_start >= start && node_end <= end &&
            (kind == 27 || kind == 29 || kind == 30 || kind == 31 ||
             kind == 32 || kind == 48) {
            usize length = node_end - node_start;
            if best == syntax.length || length > best_length {
                best = record;
                best_length = length;
            }
        }
        record = record + 1;
    }
    if best >= syntax.length { return semantic_type_error(); }
    usize best_kind = read_record_field(syntax_data, best, 0);
    if best_kind == 29 { return semantic_builtin_type("i32", 0, 3); }
    if best_kind == 30 { return semantic_builtin_type("f64", 0, 3); }
    if best_kind == 31 { return semantic_type_text(); }
    if best_kind == 32 { return semantic_type_bool(); }
    if best_kind == 48 {
        usize name = 0;
        while name < syntax.length {
            if read_record_field(syntax_data, name, 0) == 27 &&
                read_record_field(syntax_data, name, 1) ==
                    read_record_field(syntax_data, best, 1) {
                usize aggregate_symbol = resolution_find_name(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    name, source
                );
                if aggregate_symbol < symbols.length {
                    return read_record_field(symbol_data, aggregate_symbol, 4);
                }
            }
            name = name + 1;
        }
        return semantic_type_error();
    }
    usize resolved = resolution_find_name(
        project_source, project_root,
        module_data, modules, source_data,
        symbol_data, detail_data, symbols,
        syntax_data, syntax, module_index, source_record,
        best, source
    );
    if resolved < symbols.length {
        return read_record_field(symbol_data, resolved, 4);
    }
    return semantic_type_error();
}
