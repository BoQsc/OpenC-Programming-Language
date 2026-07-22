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
            if module_length < length &&
                byte_at_or_zero(source, start + module_length) == 46 &&
                resolution_module_name_equals(
                    project_source, module_data, candidate_module,
                    source, start, module_length
                ) {
                usize direct = resolution_find_top_unqualified(
                    project_source, project_root, source_data,
                    symbol_data, detail_data, symbols,
                    candidate_module, source_record, source,
                    start + module_length + 1,
                    length - module_length - 1
                );
                if direct < symbols.length { return direct; }
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
