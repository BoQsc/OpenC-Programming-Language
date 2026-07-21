import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

struct ResolutionConstant {
    bool valid;
    usize kind;
    usize type_id;
    i64 signed_value;
    bool bool_value;
    usize value_start;
    usize value_length;
    usize start;
    usize length;
}

struct ResolutionCallSelection {
    usize symbol;
    bool ambiguous;
}

struct ResolutionInteger {
    i64 value;
    bool valid;
}

struct ResolutionCounts {
    usize bindings;
    usize constants;
    usize calls;
}

usize resolution_symbol_function() { return 1; }
usize resolution_symbol_struct() { return 2; }
usize resolution_symbol_resource() { return 3; }
usize resolution_symbol_enum() { return 4; }
usize resolution_symbol_enum_item() { return 5; }
usize resolution_symbol_constant() { return 6; }
usize resolution_symbol_parameter() { return 7; }
usize resolution_symbol_variable() { return 8; }
usize resolution_symbol_field() { return 9; }

usize resolution_pack_span(usize start, usize length) {
    return start * cast(usize, 4294967296) + length;
}

usize resolution_span_start(usize packed) {
    return packed / cast(usize, 4294967296);
}

usize resolution_span_length(usize packed) {
    return packed % cast(usize, 4294967296);
}

text resolution_symbol_kind_name(usize kind) {
    if kind == 1 { return "function"; }
    if kind == 2 { return "struct"; }
    if kind == 3 { return "resource"; }
    if kind == 4 { return "enum"; }
    if kind == 5 { return "enum_item"; }
    if kind == 6 { return "constant"; }
    if kind == 7 { return "parameter"; }
    if kind == 8 { return "variable"; }
    return "field";
}

unsafe usize resolution_add_symbol(
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize kind,
    usize module_index,
    usize source_record,
    usize name_start,
    usize name_length,
    usize type_id,
    usize declaration_record,
    usize owner
) {
    usize record = symbols.length;
    write_record_field(symbol_data, record, 0, kind);
    write_record_field(symbol_data, record, 1, source_record);
    write_record_field(symbol_data, record, 2, name_start);
    write_record_field(symbol_data, record, 3, name_length);
    write_record_field(symbol_data, record, 4, type_id);
    write_record_field(detail_data, record, 0, module_index);
    write_record_field(detail_data, record, 1, declaration_record);
    write_record_field(detail_data, record, 2, owner);
    write_record_field(detail_data, record, 3, 0);
    write_record_field(detail_data, record, 4, 0);
    symbols.length = symbols.length + 1;
    return record;
}

unsafe usize resolution_find_owner_symbol(
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize source_record,
    usize declaration_record,
    usize kind_one,
    usize kind_two
) {
    usize symbol = 0;
    while symbol < symbols.length {
        usize kind = read_record_field(symbol_data, symbol, 0);
        if read_record_field(symbol_data, symbol, 1) == source_record &&
            read_record_field(detail_data, symbol, 1) == declaration_record &&
            (kind == kind_one || kind == kind_two) {
            return symbol + 1;
        }
        symbol = symbol + 1;
    }
    return 0;
}

unsafe usize resolution_smallest_parent(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize child,
    usize kind_one,
    usize kind_two,
    usize kind_three
) {
    usize selected = syntax.length;
    usize selected_length = cast(usize, 4294967295);
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if record != child &&
            (kind == kind_one || kind == kind_two || kind == kind_three) &&
            semantic_node_contains(syntax_data, record, child) {
            usize length = read_record_field(syntax_data, record, 2);
            if length < selected_length {
                selected = record;
                selected_length = length;
            }
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize resolution_declaration_type(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize source_record,
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration,
    ptr byte type_data,
    ref PackedBuffer types
) {
    usize type_node = semantic_find_prefix_type(
        syntax_data, syntax, declaration
    );
    if type_node >= syntax.length { return semantic_type_error(); }
    return semantic_resolve_type(
        project_source, project_root,
        module_data, modules, source_data, source_record,
        source, token_data, tokens,
        type_data, types,
        read_record_field(syntax_data, type_node, 1),
        read_record_field(syntax_data, type_node, 2)
    );
}

unsafe void resolution_collect_source_symbols(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !source_status.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = source_length + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = source_length * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{ length = 0, capacity = tokens.length * 6 + 8 };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );

    usize record = 0;
    while record < syntax.length {
        usize syntax_kind = read_record_field(syntax_data, record, 0);
        if (syntax_kind == 2 || syntax_kind == 3 || syntax_kind == 4 ||
            syntax_kind == 5 || syntax_kind == 7) {
            usize symbol_kind = resolution_symbol_function();
            if syntax_kind == 3 { symbol_kind = resolution_symbol_struct(); }
            if syntax_kind == 4 { symbol_kind = resolution_symbol_resource(); }
            if syntax_kind == 5 { symbol_kind = resolution_symbol_enum(); }
            if syntax_kind == 7 { symbol_kind = resolution_symbol_constant(); }
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            usize type_id = semantic_type_error();
            if syntax_kind == 2 || syntax_kind == 7 {
                type_id = resolution_declaration_type(
                    project_source, project_root,
                    module_data, modules, source_data, source_record,
                    source, token_data, tokens, syntax_data, syntax, record,
                    type_data, types
                );
            } else {
                type_id = semantic_find_named(
                    project_source, project_root,
                    module_data, modules, source_data,
                    type_data, types, source, name_start, name_length
                );
            }
            usize added = resolution_add_symbol(
                symbol_data, detail_data, symbols,
                symbol_kind, module_index, source_record,
                name_start, name_length, type_id, record, 0
            );
            write_record_field(
                detail_data, added, 4,
                resolution_pack_span(
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2)
                )
            );
        }
        record = record + 1;
    }

    record = 0;
    while record < syntax.length {
        usize syntax_kind = read_record_field(syntax_data, record, 0);
        usize parent = syntax.length;
        usize owner = 0;
        usize symbol_kind = 0;
        usize type_id = semantic_type_error();
        if (syntax_kind == 10 || syntax_kind == 12) {
            parent = resolution_smallest_parent(
                syntax_data, syntax, record, 2, 0, 0
            );
            owner = resolution_find_owner_symbol(
                symbol_data, detail_data, symbols,
                source_record, parent,
                resolution_symbol_function(), 0
            );
            if syntax_kind == 10 {
                symbol_kind = resolution_symbol_parameter();
            } else { symbol_kind = resolution_symbol_variable(); }
            type_id = resolution_declaration_type(
                project_source, project_root,
                module_data, modules, source_data, source_record,
                source, token_data, tokens, syntax_data, syntax, record,
                type_data, types
            );
        } else if (syntax_kind == 9) {
            parent = resolution_smallest_parent(
                syntax_data, syntax, record, 3, 4, 0
            );
            owner = resolution_find_owner_symbol(
                symbol_data, detail_data, symbols,
                source_record, parent,
                resolution_symbol_struct(), resolution_symbol_resource()
            );
            symbol_kind = resolution_symbol_field();
            type_id = resolution_declaration_type(
                project_source, project_root,
                module_data, modules, source_data, source_record,
                source, token_data, tokens, syntax_data, syntax, record,
                type_data, types
            );
        } else if (syntax_kind == 6) {
            parent = resolution_smallest_parent(
                syntax_data, syntax, record, 5, 0, 0
            );
            owner = resolution_find_owner_symbol(
                symbol_data, detail_data, symbols,
                source_record, parent,
                resolution_symbol_enum(), 0
            );
            symbol_kind = resolution_symbol_enum_item();
            if owner != 0 {
                type_id = read_record_field(symbol_data, owner - 1, 4);
            }
        }
        if symbol_kind != 0 && owner != 0 {
            usize symbol = resolution_add_symbol(
                symbol_data, detail_data, symbols,
                symbol_kind, module_index, source_record,
                read_record_field(syntax_data, record, 3),
                read_record_field(syntax_data, record, 4),
                type_id, record, owner
            );
            write_record_field(
                detail_data, symbol, 4,
                resolution_pack_span(
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2)
                )
            );
            if syntax_kind == 10 {
                usize start = read_record_field(syntax_data, record, 1);
                usize name_start = read_record_field(syntax_data, record, 3);
                usize token = semantic_token_at_or_after(token_data, tokens, start);
                usize mode = 0;
                while token < tokens.length &&
                    read_record_field(token_data, token, 1) < name_start {
                    usize token_start_value = read_record_field(token_data, token, 1);
                    usize token_length_value = read_record_field(token_data, token, 2);
                    if span_equals_ascii(source, token_start_value, token_length_value, "out") {
                        mode = 1;
                    }
                    token = token + 1;
                }
                write_record_field(detail_data, symbol, 3, mode);
            }
        }
        record = record + 1;
    }
}

unsafe bool resolution_symbol_name_equals(
    text project_source,
    text project_root,
    ptr byte source_data,
    ptr byte symbol_data,
    usize symbol,
    text source,
    usize start,
    usize length
) {
    text symbol_source;
    status loaded = project_read_source_record(
        project_source, project_root, source_data,
        read_record_field(symbol_data, symbol, 1), out symbol_source
    );
    if !loaded.ok { return false; }
    return semantic_spans_equal(
        source, start, length,
        symbol_source,
        read_record_field(symbol_data, symbol, 2),
        read_record_field(symbol_data, symbol, 3)
    );
}

unsafe bool resolution_module_name_equals(
    text project_source,
    ptr byte module_data,
    usize module_index,
    text source,
    usize start,
    usize length
) {
    return semantic_spans_equal(
        source, start, length,
        project_source,
        read_record_field(module_data, module_index, 0),
        read_record_field(module_data, module_index, 1)
    );
}

unsafe usize resolution_function_for_node(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize node,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    usize source_record
) {
    usize function = resolution_smallest_parent(
        syntax_data, syntax, node, 2, 0, 0
    );
    return resolution_find_owner_symbol(
        symbol_data, detail_data, symbols,
        source_record, function,
        resolution_symbol_function(), 0
    );
}

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
    usize symbol = 0;
    while symbol < symbols.length {
        usize kind = read_record_field(symbol_data, symbol, 0);
        if read_record_field(symbol_data, symbol, 1) == source_record &&
            read_record_field(detail_data, symbol, 2) == function_owner &&
            (kind == resolution_symbol_parameter() ||
             kind == resolution_symbol_variable()) &&
            resolution_symbol_name_equals(
                project_source, project_root, source_data,
                symbol_data, symbol, source, name_start, name_length
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
            kind != resolution_symbol_enum_item() &&
            resolution_symbol_name_equals(
                project_source, project_root, source_data,
                symbol_data, symbol, source, start, length
            ) { return symbol; }
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
    if first_length != length {
        usize enum_symbol = resolution_find_top_unqualified(
            project_source, project_root, source_data,
            symbol_data, detail_data, symbols,
            module_index, source, start, first_length
        );
        if enum_symbol < symbols.length &&
            read_record_field(symbol_data, enum_symbol, 0) == resolution_symbol_enum() {
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
                    candidate_module, source,
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
            module_index, source, start, length
        );
        if top < symbols.length { return top; }
    }
    return symbols.length;
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

unsafe bool resolution_lossless(
    ptr byte type_data,
    usize source_type,
    usize target_type
) {
    if source_type == target_type { return true; }
    usize source_kind = read_record_field(type_data, source_type, 0);
    usize target_kind = read_record_field(type_data, target_type, 0);
    if source_kind == 2 && target_kind == 2 {
        return read_record_field(type_data, source_type, 3) <=
            read_record_field(type_data, target_type, 3);
    }
    if ((source_kind == 3 || source_kind == 6) && target_kind == 3) {
        return read_record_field(type_data, source_type, 3) <=
            read_record_field(type_data, target_type, 3);
    }
    if source_kind == 4 && target_kind == 4 {
        return read_record_field(type_data, source_type, 3) <=
            read_record_field(type_data, target_type, 3);
    }
    return false;
}

unsafe ResolutionCallSelection resolution_select_call(
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
    text source,
    usize callee_symbol
) {
    bool ambiguous = false;
    usize requested_arguments = read_record_field(syntax_data, call, 4);
    usize callee_start = read_record_field(syntax_data, call, 1);
    usize callee_record = read_record_field(syntax_data, call, 3);
    usize callee_end = read_record_field(syntax_data, callee_record, 1) +
        read_record_field(syntax_data, callee_record, 2);
    usize callee_name_start = read_record_field(syntax_data, callee_record, 1);
    usize callee_name_length = read_record_field(syntax_data, callee_record, 2);
    usize callee_scan = 0;
    while callee_scan < callee_name_length {
        if byte_at_or_zero(source, callee_name_start + callee_scan) == 46 {
            callee_name_start = callee_name_start + callee_scan + 1;
            callee_name_length = callee_name_length - callee_scan - 1;
            callee_scan = 0;
        } else { callee_scan = callee_scan + 1; }
    }
    usize token = resolution_token_after_span(
        token_data, tokens, callee_start, callee_end - callee_start
    );
    if token < tokens.length { token = token + 1; }
    usize argument_starts_capacity = requested_arguments + 1;
    ptr byte argument_data = memory.alloc(argument_starts_capacity * record_stride());
    scope memory.free(argument_data);
    usize argument_count = 0;
    usize depth = 0;
    usize argument_start = callee_end;
    if token < tokens.length {
        argument_start = read_record_field(token_data, token, 1);
    }
    usize call_end = read_record_field(syntax_data, call, 1) +
        read_record_field(syntax_data, call, 2);
    while token < tokens.length &&
        read_record_field(token_data, token, 1) < call_end {
        usize token_start_value = read_record_field(token_data, token, 1);
        usize token_length_value = read_record_field(token_data, token, 2);
        bool open = span_equals_ascii(source, token_start_value, token_length_value, "(") ||
            span_equals_ascii(source, token_start_value, token_length_value, "[") ||
            span_equals_ascii(source, token_start_value, token_length_value, "{");
        bool close = span_equals_ascii(source, token_start_value, token_length_value, ")") ||
            span_equals_ascii(source, token_start_value, token_length_value, "]") ||
            span_equals_ascii(source, token_start_value, token_length_value, "}");
        if close && depth == 0 {
            if requested_arguments != 0 && argument_count < requested_arguments {
                write_record_field(argument_data, argument_count, 0, argument_start);
                write_record_field(argument_data, argument_count, 1, token_start_value);
                argument_count = argument_count + 1;
            }
            break;
        }
        if open { depth = depth + 1; }
        if close && depth != 0 { depth = depth - 1; }
        if depth == 0 && span_equals_ascii(
            source, token_start_value, token_length_value, ","
        ) {
            write_record_field(argument_data, argument_count, 0, argument_start);
            write_record_field(argument_data, argument_count, 1, token_start_value);
            argument_count = argument_count + 1;
            if token + 1 < tokens.length {
                argument_start = read_record_field(token_data, token + 1, 1);
            }
        }
        token = token + 1;
    }

    usize selected = symbols.length;
    usize best_conversions = cast(usize, 4294967295);
    usize candidate = 0;
    while candidate < symbols.length {
        if read_record_field(symbol_data, candidate, 0) == resolution_symbol_function() &&
            read_record_field(detail_data, candidate, 0) ==
                read_record_field(detail_data, callee_symbol, 0) &&
            resolution_symbol_name_equals(
                project_source, project_root, source_data,
                symbol_data, candidate, source,
                callee_name_start, callee_name_length
            ) &&
            resolution_parameter_count(
                symbol_data, detail_data, symbols, candidate
            ) == argument_count {
            bool valid = true;
            usize conversions = 0;
            usize argument = 0;
            while argument < argument_count {
                usize parameter = resolution_nth_parameter(
                    symbol_data, detail_data, symbols, candidate, argument
                );
                usize argument_type = resolution_argument_type(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    source,
                    read_record_field(argument_data, argument, 0),
                    read_record_field(argument_data, argument, 1)
                );
                usize parameter_type = read_record_field(
                    symbol_data, parameter, 4
                );
                if argument_type != parameter_type {
                    if resolution_lossless(
                        type_data, argument_type, parameter_type
                    ) { conversions = conversions + 1; }
                    else { valid = false; }
                }
                argument = argument + 1;
            }
            if valid {
                if selected == symbols.length || conversions < best_conversions {
                    selected = candidate;
                    best_conversions = conversions;
                    ambiguous = false;
                } else if conversions == best_conversions {
                    ambiguous = true;
                }
            }
        }
        candidate = candidate + 1;
    }
    return ResolutionCallSelection{
        symbol = selected,
        ambiguous = ambiguous
    };
}

unsafe ResolutionInteger resolution_parse_integer(
    text source,
    usize start,
    usize length
) {
    bool valid = true;
    usize index = 0;
    usize radix = 10;
    if length > 2 && byte_at_or_zero(source, start) == 48 {
        u8 marker = byte_at_or_zero(source, start + 1);
        if marker == 120 || marker == 88 { radix = 16; index = 2; }
        if marker == 98 || marker == 66 { radix = 2; index = 2; }
    }
    i64 value = 0;
    while index < length {
        u8 octet = byte_at_or_zero(source, start + index);
        if octet == 95 { index = index + 1; continue; }
        usize digit = 0;
        if octet >= 48 && octet <= 57 { digit = cast(usize, octet - 48); }
        else if octet >= 65 && octet <= 70 { digit = cast(usize, octet - 65 + 10); }
        else if octet >= 97 && octet <= 102 { digit = cast(usize, octet - 97 + 10); }
        else {
            return ResolutionInteger{ value = 0, valid = false };
        }
        if digit >= radix {
            return ResolutionInteger{ value = 0, valid = false };
        }
        value = value * cast(i64, radix) + cast(i64, digit);
        index = index + 1;
    }
    return ResolutionInteger{ value = value, valid = valid };
}

bool resolution_expression_kind(usize kind) {
    return kind >= 27 && kind <= 52 && kind != 28;
}

unsafe usize resolution_left_expression(
    ptr byte syntax_data,
    usize parent,
    usize operator_start
) {
    usize parent_start = read_record_field(syntax_data, parent, 1);
    usize selected = parent;
    usize selected_end = parent_start;
    usize record = 0;
    while record < parent {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if resolution_expression_kind(kind) && start == parent_start &&
            end <= operator_start && end >= selected_end {
            selected = record;
            selected_end = end;
        }
        record = record + 1;
    }
    return selected;
}

unsafe usize resolution_right_expression(
    ptr byte syntax_data,
    usize parent,
    usize operator_end
) {
    usize parent_end = read_record_field(syntax_data, parent, 1) +
        read_record_field(syntax_data, parent, 2);
    usize selected = parent;
    usize selected_start = parent_end;
    usize record = 0;
    while record < parent {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if resolution_expression_kind(kind) && start >= operator_end &&
            end == parent_end && start <= selected_start {
            selected = record;
            selected_start = start;
        }
        record = record + 1;
    }
    return selected;
}

unsafe ResolutionConstant resolution_evaluate_expression(
    text source,
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize record,
    ptr byte error_data,
    ref PackedBuffer errors,
    usize source_record
) {
    ResolutionConstant result = ResolutionConstant{
        valid = false, kind = 0, type_id = semantic_type_error(),
        signed_value = 0, bool_value = false,
        value_start = 0, value_length = 0,
        start = read_record_field(syntax_data, record, 1),
        length = read_record_field(syntax_data, record, 2)
    };
    usize kind = read_record_field(syntax_data, record, 0);
    if kind == 29 {
        ResolutionInteger parsed_integer = resolution_parse_integer(
            source, result.start, result.length
        );
        if !parsed_integer.valid { return result; }
        i64 value = parsed_integer.value;
        result.valid = true;
        result.kind = 1;
        result.type_id = semantic_builtin_type("i64", 0, 3);
        if value <= cast(i64, 2147483647) {
            result.type_id = semantic_builtin_type("i32", 0, 3);
        }
        result.signed_value = value;
        return result;
    }
    if kind == 30 {
        result.valid = true;
        result.kind = 4;
        result.type_id = semantic_builtin_type("f64", 0, 3);
        result.value_start = result.start;
        result.value_length = result.length;
        return result;
    }
    if kind == 31 {
        result.valid = true;
        result.kind = 3;
        result.type_id = semantic_type_text();
        if result.length >= 2 {
            result.value_start = result.start + 1;
            result.value_length = result.length - 2;
        }
        return result;
    }
    if kind == 32 {
        result.valid = true;
        result.kind = 2;
        result.type_id = semantic_type_bool();
        result.bool_value = span_equals_ascii(
            source, result.start, result.length, "true"
        );
        return result;
    }
    if kind == 35 {
        usize operator_start = read_record_field(syntax_data, record, 3);
        usize operator_length = read_record_field(syntax_data, record, 4);
        usize operand = resolution_right_expression(
            syntax_data, record, operator_start + operator_length
        );
        if operand == record { return result; }
        result = resolution_evaluate_expression(
            source, syntax_data, syntax, operand,
            error_data, errors, source_record
        );
        result.start = read_record_field(syntax_data, record, 1);
        result.length = read_record_field(syntax_data, record, 2);
        if !result.valid { return result; }
        if span_equals_ascii(source, operator_start, operator_length, "!") {
            if result.kind != 2 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.bool_value = !result.bool_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "-") {
            if result.kind != 1 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.signed_value = -result.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "~") {
            if result.kind != 1 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.signed_value = ~result.signed_value;
        }
        return result;
    }
    if kind == 36 {
        usize operator_start = read_record_field(syntax_data, record, 3);
        usize operator_length = read_record_field(syntax_data, record, 4);
        usize left_record = resolution_left_expression(
            syntax_data, record, operator_start
        );
        usize right_record = resolution_right_expression(
            syntax_data, record, operator_start + operator_length
        );
        if left_record == record || right_record == record { return result; }
        ResolutionConstant left = resolution_evaluate_expression(
            source, syntax_data, syntax, left_record,
            error_data, errors, source_record
        );
        ResolutionConstant right = resolution_evaluate_expression(
            source, syntax_data, syntax, right_record,
            error_data, errors, source_record
        );
        result.valid = left.valid && right.valid;
        if !result.valid { return result; }
        bool logical = span_equals_ascii(source, operator_start, operator_length, "&&") ||
            span_equals_ascii(source, operator_start, operator_length, "||");
        bool comparison = span_equals_ascii(source, operator_start, operator_length, "==") ||
            span_equals_ascii(source, operator_start, operator_length, "!=") ||
            span_equals_ascii(source, operator_start, operator_length, "<") ||
            span_equals_ascii(source, operator_start, operator_length, "<=") ||
            span_equals_ascii(source, operator_start, operator_length, ">") ||
            span_equals_ascii(source, operator_start, operator_length, ">=");
        if logical {
            if left.kind != 2 || right.kind != 2 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 8
                );
                result.valid = false;
                return result;
            }
            result.kind = 2;
            result.type_id = semantic_type_bool();
            if span_equals_ascii(source, operator_start, operator_length, "&&") {
                result.bool_value = left.bool_value && right.bool_value;
            } else { result.bool_value = left.bool_value || right.bool_value; }
            return result;
        }
        if left.kind != 1 || right.kind != 1 {
            semantic_record_error(
                error_data, errors, source_record,
                result.start, result.length, 8
            );
            result.valid = false;
            return result;
        }
        if comparison {
            result.kind = 2;
            result.type_id = semantic_type_bool();
            if span_equals_ascii(source, operator_start, operator_length, "==") {
                result.bool_value = left.signed_value == right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, "!=") {
                result.bool_value = left.signed_value != right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, "<") {
                result.bool_value = left.signed_value < right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, "<=") {
                result.bool_value = left.signed_value <= right.signed_value;
            } else if span_equals_ascii(source, operator_start, operator_length, ">") {
                result.bool_value = left.signed_value > right.signed_value;
            } else { result.bool_value = left.signed_value >= right.signed_value; }
            return result;
        }
        result.kind = 1;
        result.type_id = left.type_id;
        if span_equals_ascii(source, operator_start, operator_length, "+") {
            result.signed_value = left.signed_value + right.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "-") {
            result.signed_value = left.signed_value - right.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "*") {
            result.signed_value = left.signed_value * right.signed_value;
        } else if span_equals_ascii(source, operator_start, operator_length, "/") ||
            span_equals_ascii(source, operator_start, operator_length, "%") {
            if right.signed_value == 0 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 5
                );
                result.valid = false;
                return result;
            }
            if span_equals_ascii(source, operator_start, operator_length, "/") {
                result.signed_value = left.signed_value / right.signed_value;
            } else { result.signed_value = left.signed_value % right.signed_value; }
        } else if span_equals_ascii(source, operator_start, operator_length, "<<") ||
            span_equals_ascii(source, operator_start, operator_length, ">>") {
            if right.signed_value < 0 || right.signed_value >= 64 {
                semantic_record_error(
                    error_data, errors, source_record,
                    result.start, result.length, 6
                );
                result.valid = false;
                return result;
            }
            if span_equals_ascii(source, operator_start, operator_length, "<<") {
                result.signed_value = left.signed_value << right.signed_value;
            } else {
                result.signed_value = left.signed_value >> right.signed_value;
            }
        } else if span_equals_ascii(source, operator_start, operator_length, "&") {
            result.signed_value = cast(i64,
                cast(u64, left.signed_value) & cast(u64, right.signed_value)
            );
        } else if span_equals_ascii(source, operator_start, operator_length, "|") {
            result.signed_value = cast(i64,
                cast(u64, left.signed_value) | cast(u64, right.signed_value)
            );
        } else if span_equals_ascii(source, operator_start, operator_length, "^") {
            result.signed_value = cast(i64,
                cast(u64, left.signed_value) ^ cast(u64, right.signed_value)
            );
        } else { result.valid = false; }
        return result;
    }
    if kind == 46 {
        usize type_node = resolution_smallest_parent(
            syntax_data, syntax, record, 0, 0, 0
        );
        type_node = type_node;
    }
    return result;
}

unsafe usize resolution_constant_root(
    ptr byte syntax_data,
    ref PackedBuffer syntax,
    usize declaration,
    usize after
) {
    usize declaration_end = read_record_field(syntax_data, declaration, 1) +
        read_record_field(syntax_data, declaration, 2);
    usize selected = syntax.length;
    usize selected_length = 0;
    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        usize start = read_record_field(syntax_data, record, 1);
        usize end = start + read_record_field(syntax_data, record, 2);
        if resolution_expression_kind(kind) && start >= after &&
            end < declaration_end &&
            semantic_node_contains(syntax_data, declaration, record) &&
            read_record_field(syntax_data, record, 2) >= selected_length {
            selected = record;
            selected_length = read_record_field(syntax_data, record, 2);
        }
        record = record + 1;
    }
    return selected;
}

unsafe void resolution_emit_constant(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    ptr byte type_data,
    usize ordinal,
    usize module_index,
    usize source_index,
    text owner_kind,
    text source,
    usize owner_start,
    usize owner_length,
    usize name_start,
    usize name_length,
    usize type_id,
    ResolutionConstant value
) {
    io.print("CONST ");
    io.print(ordinal);
    io.print(" ");
    io.print(module_index);
    io.print(" ");
    io.print(source_index);
    io.print(" ");
    io.print(owner_kind);
    io.print(" ");
    io.print(owner_start);
    io.print(" ");
    io.print(owner_length);
    io.print(" ");
    project_emit_hex(project_slice(source, name_start, name_length));
    io.print(" ");
    semantic_emit_type_display(
        project_source, project_root,
        module_data, modules, source_data,
        type_data, type_id
    );
    if value.kind == 1 {
        io.print(" integer ");
        io.println(value.signed_value);
    } else if value.kind == 2 {
        io.print(" bool ");
        if value.bool_value { io.println("1"); }
        else { io.println("0"); }
    } else if value.kind == 3 {
        io.print(" text ");
        project_emit_hex(project_slice(
            source, value.value_start, value.value_length
        ));
        io.println("");
    } else {
        io.print(" float_source ");
        project_emit_hex(project_slice(
            source, value.value_start, value.value_length
        ));
        io.println("");
    }
}

unsafe void resolution_observe_source(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors,
    ref ResolutionCounts counts
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !source_status.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = source_length + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = source_length * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{ length = 0, capacity = tokens.length * 6 + 8 };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );

    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if kind == 27 && !resolution_name_excluded(
            syntax_data, syntax, record
        ) {
            usize symbol = resolution_find_name(
                project_source, project_root,
                module_data, modules, source_data,
                symbol_data, detail_data, symbols,
                syntax_data, syntax, module_index, source_record,
                record, source
            );
            if symbol < symbols.length {
                io.print("BIND ");
                io.print(counts.bindings);
                io.print(" ");
                io.print(module_index);
                io.print(" ");
                io.print(source_index);
                io.print(" ");
                io.print(read_record_field(syntax_data, record, 1));
                io.print(" ");
                io.print(read_record_field(syntax_data, record, 2));
                io.print(" ");
                project_emit_hex(project_slice(
                    source,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2)
                ));
                io.print(" ");
                io.print(resolution_symbol_kind_name(
                    read_record_field(symbol_data, symbol, 0)
                ));
                io.print(" ");
                resolution_emit_symbol_identity(
                    project_source, project_root,
                    module_data, source_data,
                    symbol_data, detail_data, symbol
                );
                usize packed_span = read_record_field(
                    detail_data, symbol, 4
                );
                io.print(" ");
                io.print(resolution_span_start(packed_span));
                io.print(" ");
                io.print(resolution_span_length(packed_span));
                io.print(" ");
                if resolution_name_is_unchecked_operand(
                    syntax_data, syntax, record
                ) {
                    semantic_emit_type_display(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, semantic_type_error()
                    );
                } else {
                    semantic_emit_type_display(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data,
                        read_record_field(symbol_data, symbol, 4)
                    );
                }
                io.println("");
                counts.bindings = counts.bindings + 1;
            } else {
                semantic_record_error(
                    error_data, errors, source_record,
                    read_record_field(syntax_data, record, 1),
                    read_record_field(syntax_data, record, 2), 1
                );
            }
        } else if kind == 38 {
            usize callee_record = read_record_field(syntax_data, record, 3);
            if callee_record < syntax.length &&
                read_record_field(syntax_data, callee_record, 0) == 27 {
                usize callee_symbol = resolution_find_name(
                    project_source, project_root,
                    module_data, modules, source_data,
                    symbol_data, detail_data, symbols,
                    syntax_data, syntax, module_index, source_record,
                    callee_record, source
                );
                if callee_symbol < symbols.length {
                    ResolutionCallSelection selection = resolution_select_call(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, symbol_data, detail_data, symbols,
                        token_data, tokens, syntax_data, syntax,
                        module_index, source_record, record, source,
                        callee_symbol
                    );
                    usize selected = selection.symbol;
                    bool ambiguous = selection.ambiguous;
                    if selected < symbols.length && !ambiguous {
                        io.print("CALL ");
                        io.print(counts.calls);
                        io.print(" ");
                        io.print(module_index);
                        io.print(" ");
                        io.print(source_index);
                        io.print(" ");
                        io.print(read_record_field(syntax_data, record, 1));
                        io.print(" ");
                        io.print(read_record_field(syntax_data, record, 2));
                        io.print(" ");
                        project_emit_hex(project_slice(
                            source,
                            read_record_field(syntax_data, callee_record, 1),
                            read_record_field(syntax_data, callee_record, 2)
                        ));
                        io.print(" ");
                        resolution_emit_symbol_identity(
                            project_source, project_root,
                            module_data, source_data,
                            symbol_data, detail_data, selected
                        );
                        usize packed_span = read_record_field(
                            detail_data, selected, 4
                        );
                        io.print(" ");
                        io.print(resolution_span_start(packed_span));
                        io.print(" ");
                        io.print(resolution_span_length(packed_span));
                        io.print(" ");
                        semantic_emit_type_display(
                            project_source, project_root,
                            module_data, modules, source_data,
                            type_data,
                            read_record_field(symbol_data, selected, 4)
                        );
                        io.println("");
                        counts.calls = counts.calls + 1;
                    } else {
                        usize call_rule = 3;
                        if ambiguous { call_rule = 4; }
                        semantic_record_error(
                            error_data, errors, source_record,
                            read_record_field(syntax_data, record, 1),
                            read_record_field(syntax_data, record, 2),
                            call_rule
                        );
                    }
                }
            }
        }
        record = record + 1;
    }
}

unsafe void resolution_observe_source_constants(
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data,
    usize module_index,
    usize source_index,
    usize source_record,
    ptr byte type_data,
    ref PackedBuffer types,
    ptr byte symbol_data,
    ptr byte detail_data,
    ref PackedBuffer symbols,
    ptr byte error_data,
    ref PackedBuffer errors,
    ref ResolutionCounts counts
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !source_status.ok { return; }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{ length = 0, capacity = source_length + 2 };
    PackedBuffer diagnostics = PackedBuffer{ length = 0, capacity = source_length * 4 + 8 };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(diagnostics.capacity * record_stride());
    scope memory.free(diagnostic_data);
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{ length = 0, capacity = tokens.length * 6 + 8 };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );

    usize record = 0;
    while record < syntax.length {
        usize kind = read_record_field(syntax_data, record, 0);
        if kind == 7 {
            usize name_start = read_record_field(syntax_data, record, 3);
            usize name_length = read_record_field(syntax_data, record, 4);
            usize token = semantic_token_at_or_after(
                token_data, tokens, name_start + name_length
            );
            while token < tokens.length {
                usize token_start_value = read_record_field(token_data, token, 1);
                usize token_length_value = read_record_field(token_data, token, 2);
                if span_equals_ascii(
                    source, token_start_value, token_length_value, "="
                ) { break; }
                token = token + 1;
            }
            usize after = name_start + name_length;
            if token + 1 < tokens.length {
                after = read_record_field(token_data, token + 1, 1);
            }
            usize root = resolution_constant_root(
                syntax_data, syntax, record, after
            );
            if root < syntax.length {
                ResolutionConstant value = resolution_evaluate_expression(
                    source, syntax_data, syntax, root,
                    error_data, errors, source_record
                );
                if value.valid {
                    resolution_emit_constant(
                        project_source, project_root,
                        module_data, modules, source_data, type_data,
                        counts.constants, module_index, source_index,
                        "module_constant", source,
                        read_record_field(syntax_data, record, 1),
                        read_record_field(syntax_data, record, 2),
                        name_start, name_length,
                        value.type_id, value
                    );
                    counts.constants = counts.constants + 1;
                }
            }
        } else if kind == 5 {
            usize enum_symbol = resolution_find_top_unqualified(
                project_source, project_root, source_data,
                symbol_data, detail_data, symbols,
                module_index, source,
                read_record_field(syntax_data, record, 3),
                read_record_field(syntax_data, record, 4)
            );
            i64 next_value = 0;
            usize item = 0;
            while item < syntax.length {
                if read_record_field(syntax_data, item, 0) == 6 &&
                    semantic_node_contains(syntax_data, record, item) {
                    usize enum_type = semantic_type_error();
                    if enum_symbol < symbols.length {
                        enum_type = read_record_field(
                            symbol_data, enum_symbol, 4
                        );
                    }
                    ResolutionConstant enum_value = ResolutionConstant{
                        valid = true, kind = 1,
                        type_id = enum_type,
                        signed_value = next_value, bool_value = false,
                        value_start = 0, value_length = 0,
                        start = read_record_field(syntax_data, item, 1),
                        length = read_record_field(syntax_data, item, 2)
                    };
                    io.print("CONST ");
                    io.print(counts.constants);
                    io.print(" ");
                    io.print(module_index);
                    io.print(" ");
                    io.print(source_index);
                    io.print(" enum_item ");
                    io.print(read_record_field(syntax_data, item, 1));
                    io.print(" ");
                    io.print(read_record_field(syntax_data, item, 2));
                    io.print(" ");
                    project_emit_hex(project_slice(
                        source,
                        read_record_field(syntax_data, record, 3),
                        read_record_field(syntax_data, record, 4)
                    ));
                    io.print("2e");
                    project_emit_hex(project_slice(
                        source,
                        read_record_field(syntax_data, item, 3),
                        read_record_field(syntax_data, item, 4)
                    ));
                    io.print(" ");
                    semantic_emit_type_display(
                        project_source, project_root,
                        module_data, modules, source_data,
                        type_data, enum_value.type_id
                    );
                    io.print(" integer ");
                    io.println(enum_value.signed_value);
                    counts.constants = counts.constants + 1;
                    next_value = next_value + 1;
                }
                item = item + 1;
            }
        }
        record = record + 1;
    }
}

text resolution_error_rule(usize rule) {
    if rule == 1 { return "OPENC-NAME-UNKNOWN-001"; }
    if rule == 2 { return "OPENC-NAME-AMBIGUOUS-001"; }
    if rule == 3 { return "OPENC-CALL-NOMATCH-001"; }
    if rule == 4 { return "OPENC-CALL-AMBIGUOUS-001"; }
    if rule == 5 { return "OPENC-ARITH-DIVZERO-001"; }
    if rule == 6 { return "OPENC-ARITH-SHIFT-RANGE-001"; }
    if rule == 7 { return "OPENC-ARITH-STATIC-OVERFLOW-001"; }
    if rule == 8 { return "OPENC-CONSTANT-TYPE-001"; }
    return "OPENC-NAME-DUPLICATE-001";
}

unsafe i32 observe_semantic_resolution(text project_path) {
    io.println("OPENC-SEMANTIC-RESOLUTION-OBSERVATION 1");
    text project_source;
    status loaded_project = file.read_text(project_path, out project_source);
    if !loaded_project.ok {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }
    usize project_length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{ length = 0, capacity = project_length + 1 };
    PackedBuffer sources = PackedBuffer{ length = 0, capacity = project_length + 1 };
    ptr byte module_data = memory.alloc(modules.capacity * record_stride());
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(sources.capacity * record_stride());
    scope memory.free(source_data);
    if !project_parse_json(
        project_source, module_data, modules, source_data, sources
    ) {
        io.println("PROJECT_ERROR OPENC-PROJECT-INVALID-001");
        io.println("SUMMARY 0 0 0 0 0 1");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    usize total_source_length = 0;
    usize module_index = 0;
    while module_index < modules.length {
        io.print("MODULE ");
        io.print(module_index);
        io.print(" ");
        project_emit_hex(project_slice(
            project_source,
            read_record_field(module_data, module_index, 0),
            read_record_field(module_data, module_index, 1)
        ));
        io.print(" ");
        io.println(read_record_field(module_data, module_index, 3));
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            text source;
            status source_status = project_read_source_record(
                project_source, project_root, source_data,
                source_first + source_index, out source
            );
            if !source_status.ok {
                io.print("PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ");
                io.print(module_index);
                io.print(" ");
                io.println(source_index);
                io.print("SUMMARY ");
                io.print(modules.length);
                io.println(" 0 0 0 0 1");
                return 1;
            }
            total_source_length = total_source_length + text.byte_length(source);
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    usize capacity = total_source_length * 3 + project_length + 128;
    PackedBuffer types = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer symbols = PackedBuffer{ length = 0, capacity = capacity };
    PackedBuffer errors = PackedBuffer{ length = 0, capacity = capacity };
    ptr byte type_data = memory.alloc(types.capacity * record_stride());
    scope memory.free(type_data);
    ptr byte symbol_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(symbol_data);
    ptr byte detail_data = memory.alloc(symbols.capacity * record_stride());
    scope memory.free(detail_data);
    ptr byte error_data = memory.alloc(errors.capacity * record_stride());
    scope memory.free(error_data);
    semantic_initialize_types(type_data, types);

    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            semantic_predeclare_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_collect_source_symbols(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_first + source_index,
                type_data, types,
                symbol_data, detail_data, symbols
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    ResolutionCounts counts = ResolutionCounts{
        bindings = 0, constants = 0, calls = 0
    };
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_observe_source(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, types,
                symbol_data, detail_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }
    module_index = 0;
    while module_index < modules.length {
        usize source_first = read_record_field(module_data, module_index, 2);
        usize source_count = read_record_field(module_data, module_index, 3);
        usize source_index = 0;
        while source_index < source_count {
            resolution_observe_source_constants(
                project_source, project_root,
                module_data, modules, source_data,
                module_index, source_index, source_first + source_index,
                type_data, types,
                symbol_data, detail_data, symbols,
                error_data, errors, counts
            );
            source_index = source_index + 1;
        }
        module_index = module_index + 1;
    }

    usize error = 0;
    while error < errors.length {
        usize source_record = read_record_field(error_data, error, 0);
        usize error_module = semantic_source_module(
            module_data, modules, source_record
        );
        usize source_first = read_record_field(
            module_data, error_module, 2
        );
        io.print("ERROR ");
        io.print(resolution_error_rule(
            read_record_field(error_data, error, 3)
        ));
        io.print(" ");
        io.print(error_module);
        io.print(" ");
        io.print(source_record - source_first);
        io.print(" ");
        io.print(read_record_field(error_data, error, 1));
        io.print(" ");
        io.println(read_record_field(error_data, error, 2));
        error = error + 1;
    }
    io.print("SUMMARY ");
    io.print(modules.length);
    io.print(" ");
    io.print(sources.length);
    io.print(" ");
    io.print(counts.bindings);
    io.print(" ");
    io.print(counts.constants);
    io.print(" ");
    io.print(counts.calls);
    io.print(" ");
    io.println(errors.length);
    if errors.length != 0 { return 1; }
    return 0;
}
