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

unsafe void resolution_collect_parsed_source_symbols(
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
    ref PackedBuffer symbols,
    text source,
    ptr byte token_data,
    ref PackedBuffer tokens,
    ptr byte syntax_data,
    ref PackedBuffer syntax
) {
    ptr byte owner_symbols = memory.alloc(
        (syntax.length + 1) * size_of(usize)
    );
    scope memory.free(owner_symbols);
    usize owner_record = 0;
    while owner_record <= syntax.length {
        write_usize(
            owner_symbols, owner_record * size_of(usize), 0
        );
        owner_record = owner_record + 1;
    }
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
            write_usize(
                owner_symbols, record * size_of(usize), added + 1
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
            if parent < syntax.length {
                owner = read_usize(
                    owner_symbols, parent * size_of(usize)
                );
            }
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
            if parent < syntax.length {
                owner = read_usize(
                    owner_symbols, parent * size_of(usize)
                );
            }
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
            if parent < syntax.length {
                owner = read_usize(
                    owner_symbols, parent * size_of(usize)
                );
            }
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
