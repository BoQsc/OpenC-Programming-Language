import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize resolution_pointer_encode(ptr byte value) {
    ptr byte representation = reinterpret(ptr byte, &value);
    return read_usize(representation, 0);
}

unsafe ptr byte resolution_pointer_decode(usize value) {
    ptr byte result = null;
    ptr byte representation = reinterpret(ptr byte, &result);
    write_usize(representation, 0, value);
    return result;
}

unsafe void resolution_copy_records(
    ptr byte destination,
    ptr byte source,
    usize count
) {
    usize record = 0;
    while record < count {
        usize field = 0;
        while field < 5 {
            write_record_field(
                destination, record, field,
                read_record_field(source, record, field)
            );
            field = field + 1;
        }
        record = record + 1;
    }
}

unsafe ResolutionParsedSource resolution_parse_source_retained(
    text project_source,
    text project_root,
    ptr byte source_data,
    usize source_record
) {
    text source;
    status source_status = project_read_source_record(
        project_source, project_root, source_data, source_record, out source
    );
    if !source_status.ok {
        return ResolutionParsedSource{
            reusable = false,
            token_data = null,
            tokens = PackedBuffer{ length = 0, capacity = 0 },
            syntax_data = null,
            syntax = PackedBuffer{ length = 0, capacity = 0 }
        };
    }
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    lex_source(source, token_data, tokens, diagnostic_data, diagnostics);
    PackedBuffer syntax = PackedBuffer{
        length = 0, capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(syntax.capacity * record_stride());
    parse_source_syntax(
        source, token_data, tokens, syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    ResolutionParsedSource retained = ResolutionParsedSource{
        reusable = false,
        token_data = null,
        tokens = PackedBuffer{ length = 0, capacity = 0 },
        syntax_data = null,
        syntax = PackedBuffer{ length = 0, capacity = 0 }
    };
    retained.reusable = diagnostics.length == 0;
    retained.token_data = memory.alloc(
        tokens.length * record_stride()
    );
    retained.syntax_data = memory.alloc(
        syntax.length * record_stride()
    );
    retained.tokens = PackedBuffer{
        length = tokens.length, capacity = tokens.length
    };
    retained.syntax = PackedBuffer{
        length = syntax.length, capacity = syntax.length
    };
    resolution_copy_records(
        retained.token_data, token_data, tokens.length
    );
    resolution_copy_records(
        retained.syntax_data, syntax_data, syntax.length
    );
    memory.free(syntax_data);
    memory.free(token_data);
    memory.free(diagnostic_data);
    return retained;
}

unsafe ResolutionParsedSource resolution_collect_source_symbols_retained(
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
    ResolutionParsedSource parsed = resolution_parse_source_retained(
        project_source, project_root, source_data, source_record
    );
    if parsed.token_data != null {
        text source;
        status source_status = project_read_source_record(
            project_source, project_root, source_data,
            source_record, out source
        );
        if source_status.ok {
            resolution_collect_parsed_source_symbols(
                project_source, project_root, module_data, modules,
                source_data, module_index, source_record, type_data, types,
                symbol_data, detail_data, symbols,
                source, parsed.token_data, parsed.tokens,
                parsed.syntax_data, parsed.syntax
            );
        }
    }
    return parsed;
}

unsafe void resolution_release_parsed_source(
    ref ResolutionParsedSource parsed
) {
    if parsed.token_data != null { memory.free(parsed.token_data); }
    if parsed.syntax_data != null { memory.free(parsed.syntax_data); }
    parsed.reusable = false;
    parsed.token_data = null;
    parsed.syntax_data = null;
}

unsafe void resolution_cache_parsed_source(
    ptr byte cache_data,
    usize source_record,
    ref ResolutionParsedSource parsed
) {
    if cache_data == null || !parsed.reusable { return; }
    write_record_field(
        cache_data, source_record, 0,
        resolution_pointer_encode(parsed.token_data)
    );
    write_record_field(
        cache_data, source_record, 1, parsed.tokens.length
    );
    write_record_field(
        cache_data, source_record, 2,
        resolution_pointer_encode(parsed.syntax_data)
    );
    write_record_field(
        cache_data, source_record, 3, parsed.syntax.length
    );
    write_record_field(cache_data, source_record, 4, 1);
}

unsafe ResolutionParsedSource resolution_cached_parsed_source(
    ptr byte cache_data,
    usize source_record
) {
    if cache_data == null || read_record_field(
        cache_data, source_record, 4
    ) == 0 {
        return ResolutionParsedSource{
            reusable = false,
            token_data = null,
            tokens = PackedBuffer{ length = 0, capacity = 0 },
            syntax_data = null,
            syntax = PackedBuffer{ length = 0, capacity = 0 }
        };
    }
    usize token_length = read_record_field(cache_data, source_record, 1);
    usize syntax_length = read_record_field(cache_data, source_record, 3);
    return ResolutionParsedSource{
        reusable = true,
        token_data = resolution_pointer_decode(
            read_record_field(cache_data, source_record, 0)
        ),
        tokens = PackedBuffer{
            length = token_length, capacity = token_length
        },
        syntax_data = resolution_pointer_decode(
            read_record_field(cache_data, source_record, 2)
        ),
        syntax = PackedBuffer{
            length = syntax_length, capacity = syntax_length
        }
    };
}

unsafe void resolution_release_parse_cache(
    ptr byte cache_data,
    usize source_count
) {
    if cache_data == null { return; }
    usize source_record = 0;
    while source_record < source_count {
        ResolutionParsedSource parsed = resolution_cached_parsed_source(
            cache_data, source_record
        );
        resolution_release_parsed_source(parsed);
        source_record = source_record + 1;
    }
    memory.free(cache_data);
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
    ResolutionParsedSource parsed =
        resolution_collect_source_symbols_retained(
            project_source, project_root, module_data, modules,
            source_data, module_index, source_record,
            type_data, types, symbol_data, detail_data, symbols
        );
    resolution_release_parsed_source(parsed);
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
