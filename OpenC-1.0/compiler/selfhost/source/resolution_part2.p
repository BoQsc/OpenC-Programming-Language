import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

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
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{
        length = 0, capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens, syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    resolution_collect_parsed_source_symbols(
        project_source, project_root, module_data, modules,
        source_data, module_index, source_record, type_data, types,
        symbol_data, detail_data, symbols,
        source, token_data, tokens, syntax_data, syntax
    );
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
