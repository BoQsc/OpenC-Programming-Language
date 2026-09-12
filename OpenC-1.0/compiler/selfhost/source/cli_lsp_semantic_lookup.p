import system.memory;
import system.text;

unsafe usize lsp_offset_at_position(
    text source,
    usize line,
    usize character
) {
    usize source_length = text.byte_length(source);
    usize cursor = 0;
    usize current_line = 0;
    while cursor < source_length && current_line < line {
        if byte_at_or_zero(source, cursor) == 10 {
            current_line = current_line + 1;
        }
        cursor = cursor + 1;
    }
    if current_line != line { return source_length + 1; }
    usize column = 0;
    while cursor < source_length && column < character &&
        byte_at_or_zero(source, cursor) != 10 {
        cursor = cursor + 1;
        column = column + 1;
    }
    if column != character { return source_length + 1; }
    return cursor;
}

unsafe LspIdentifierResult lsp_identifier_at(
    text source,
    usize offset
) {
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 2
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(
        tokens.capacity * record_stride()
    );
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);
    lex_source(
        source, token_data, tokens,
        diagnostic_data, diagnostics
    );
    usize token = 0;
    while token < tokens.length {
        usize start = read_record_field(token_data, token, 1);
        usize length = read_record_field(token_data, token, 2);
        if read_record_field(token_data, token, 0) == 1 &&
            offset >= start && offset < start + length {
            return LspIdentifierResult{
                found = true,
                identifier = TextSpan{ start = start, length = length }
            };
        }
        token = token + 1;
    }
    return LspIdentifierResult{
        found = false,
        identifier = TextSpan{ start = 0, length = 0 }
    };
}

unsafe LspRequestIdentifierResult lsp_request_identifier(
    ref LspState state,
    text request
) {
    usize document = lsp_request_document(state, request);
    if document >= lsp_max_documents() ||
        !lsp_document_in_project(state, document) {
        return LspRequestIdentifierResult{
            found = false, document = document,
            identifier = TextSpan{ start = 0, length = 0 }
        };
    }
    text source = lsp_document_source(state, document);
    usize offset = lsp_offset_at_position(
        source,
        lsp_json_usize(request, "line", 0),
        lsp_json_usize(request, "character", 0)
    );
    LspIdentifierResult result = lsp_identifier_at(source, offset);
    return LspRequestIdentifierResult{
        found = result.found, document = document,
        identifier = result.identifier
    };
}

unsafe bool lsp_symbol_name_equal(
    ref LspSemanticIndex index,
    ref LspState state,
    usize symbol,
    text source,
    TextSpan name
) {
    usize document = read_record_field(
        index.symbol_data, symbol, 0
    );
    text declaration_source = lsp_document_source(state, document);
    usize start = read_record_field(index.symbol_data, symbol, 1);
    usize length = read_record_field(index.symbol_data, symbol, 2);
    if length != name.length { return false; }
    usize cursor = 0;
    while cursor < length {
        if byte_at_or_zero(declaration_source, start + cursor) !=
            byte_at_or_zero(source, name.start + cursor) {
            return false;
        }
        cursor = cursor + 1;
    }
    return true;
}

unsafe usize lsp_find_symbol(
    ref LspSemanticIndex index,
    ref LspState state,
    text source,
    TextSpan name
) {
    usize symbol = 0;
    while symbol < index.symbols.length {
        if lsp_symbol_name_equal(
            index, state, symbol, source, name
        ) {
            return symbol;
        }
        symbol = symbol + 1;
    }
    return index.symbols.length;
}

unsafe usize lsp_symbol_lsp_kind(
    ref LspSemanticIndex index,
    usize symbol
) {
    usize kind = read_record_field(index.detail_data, symbol, 0);
    if kind == 1 { return 12; }
    if kind == 2 || kind == 3 { return 23; }
    if kind == 4 { return 10; }
    if kind == 6 { return 14; }
    return 13;
}

unsafe usize lsp_completion_lsp_kind(
    ref LspSemanticIndex index,
    usize symbol
) {
    usize kind = read_record_field(index.detail_data, symbol, 0);
    if kind == 1 { return 3; }
    if kind == 2 || kind == 3 { return 22; }
    if kind == 4 { return 13; }
    if kind == 6 { return 21; }
    return 6;
}

unsafe text lsp_symbol_role(
    ref LspSemanticIndex index,
    usize symbol
) {
    usize kind = read_record_field(index.detail_data, symbol, 0);
    if kind == 1 { return "function"; }
    if kind == 2 { return "struct"; }
    if kind == 3 { return "resource"; }
    if kind == 4 { return "enum"; }
    if kind == 6 { return "const"; }
    return "symbol";
}

unsafe void lsp_put_symbol_name(
    ref DBuffer output,
    ref LspSemanticIndex index,
    ref LspState state,
    usize symbol
) {
    usize document = read_record_field(
        index.symbol_data, symbol, 0
    );
    d_put_slice(
        output, lsp_document_source(state, document),
        read_record_field(index.symbol_data, symbol, 1),
        read_record_field(index.symbol_data, symbol, 2)
    );
}

unsafe void lsp_put_symbol_type(
    ref DBuffer output,
    ref LspSemanticIndex index,
    ref LspState state,
    usize symbol
) {
    usize document = read_record_field(
        index.symbol_data, symbol, 0
    );
    d_put_slice(
        output, lsp_document_source(state, document),
        read_record_field(index.symbol_data, symbol, 3),
        read_record_field(index.symbol_data, symbol, 4)
    );
}

unsafe void lsp_put_symbol_detail(
    ref DBuffer output,
    ref LspSemanticIndex index,
    ref LspState state,
    usize symbol
) {
    d_put(output, lsp_symbol_role(index, symbol));
    d_put(output, " ");
    lsp_put_symbol_name(output, index, state, symbol);
    usize kind = read_record_field(index.detail_data, symbol, 0);
    if kind == 1 || kind == 6 {
        d_put(output, ": ");
        lsp_put_symbol_type(output, index, state, symbol);
    }
}

unsafe void lsp_put_range(
    ref DBuffer output,
    text source,
    usize start,
    usize length
) {
    d_put(output, "{\"start\":");
    lsp_put_position(output, source, start);
    d_put(output, ",\"end\":");
    lsp_put_position(output, source, start + length);
    d_put(output, "}");
}

unsafe void lsp_put_symbol_location(
    ref DBuffer output,
    ref LspSemanticIndex index,
    ref LspState state,
    usize symbol
) {
    usize document = read_record_field(
        index.symbol_data, symbol, 0
    );
    text source = lsp_document_source(state, document);
    usize start = read_record_field(index.symbol_data, symbol, 1);
    usize length = read_record_field(index.symbol_data, symbol, 2);
    d_put(output, "{\"uri\":");
    cli_json_text(output, lsp_document_uri(state, document));
    d_put(output, ",\"range\":");
    lsp_put_range(output, source, start, length);
    d_put(output, "}");
}
