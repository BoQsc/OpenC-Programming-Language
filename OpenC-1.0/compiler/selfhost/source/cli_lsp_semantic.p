struct LspSemanticIndex {
    PackedBuffer symbols;
    ptr byte symbol_data;
    ptr byte detail_data;
}

usize lsp_semantic_symbol_capacity() {
    return 8192;
}

unsafe LspSemanticIndex lsp_semantic_index_create() {
    usize capacity = lsp_semantic_symbol_capacity();
    return LspSemanticIndex{
        symbols = PackedBuffer{ length = 0, capacity = capacity },
        symbol_data = memory.alloc(capacity * record_stride()),
        detail_data = memory.alloc(capacity * record_stride())
    };
}

unsafe void lsp_semantic_index_destroy(
    ref LspSemanticIndex index
) {
    memory.free(index.detail_data);
    memory.free(index.symbol_data);
}

bool lsp_text_less(text left, text right) {
    usize left_length = text.byte_length(left);
    usize right_length = text.byte_length(right);
    usize count = left_length;
    if right_length < count { count = right_length; }
    usize cursor = 0;
    while cursor < count {
        u8 left_byte = byte_at_or_zero(left, cursor);
        u8 right_byte = byte_at_or_zero(right, cursor);
        if left_byte < right_byte { return true; }
        if left_byte > right_byte { return false; }
        cursor = cursor + 1;
    }
    return left_length < right_length;
}

unsafe usize lsp_sorted_document(
    ref LspState state,
    usize rank
) {
    usize candidate = 0;
    while candidate < lsp_max_documents() {
        if lsp_document_in_project(state, candidate) {
            usize before = 0;
            usize other = 0;
            while other < lsp_max_documents() {
                if lsp_document_in_project(state, other) &&
                    lsp_text_less(
                        lsp_document_uri(state, other),
                        lsp_document_uri(state, candidate)
                    ) {
                    before = before + 1;
                }
                other = other + 1;
            }
            if before == rank { return candidate; }
        }
        candidate = candidate + 1;
    }
    return lsp_max_documents();
}

unsafe usize lsp_project_document_count(ref LspState state) {
    usize count = 0;
    usize index = 0;
    while index < lsp_max_documents() {
        if lsp_document_in_project(state, index) {
            count = count + 1;
        }
        index = index + 1;
    }
    return count;
}

unsafe usize lsp_semantic_output_capacity(ref LspState state) {
    usize capacity = 65536;
    usize index = 0;
    while index < lsp_max_documents() {
        if lsp_document_in_project(state, index) {
            capacity = capacity +
                text.byte_length(lsp_document_source(state, index)) * 16;
        }
        index = index + 1;
    }
    return capacity;
}

unsafe bool lsp_token_is(
    text source,
    ptr byte token_data,
    usize token,
    text expected
) {
    return span_equals_ascii(
        source,
        read_record_field(token_data, token, 1),
        read_record_field(token_data, token, 2),
        expected
    );
}

unsafe void lsp_add_semantic_symbol(
    ref LspSemanticIndex index,
    usize document,
    usize name_start,
    usize name_length,
    usize type_start,
    usize type_length,
    usize kind
) {
    if index.symbols.length >= index.symbols.capacity { return; }
    usize symbol = index.symbols.length;
    write_record_field(index.symbol_data, symbol, 0, document);
    write_record_field(index.symbol_data, symbol, 1, name_start);
    write_record_field(index.symbol_data, symbol, 2, name_length);
    write_record_field(index.symbol_data, symbol, 3, type_start);
    write_record_field(index.symbol_data, symbol, 4, type_length);
    write_record_field(index.detail_data, symbol, 0, kind);
    write_record_field(index.detail_data, symbol, 1, name_start);
    write_record_field(index.detail_data, symbol, 2, name_length);
    write_record_field(index.detail_data, symbol, 3, 1);
    write_record_field(index.detail_data, symbol, 4, 0);
    index.symbols.length = symbol + 1;
}

unsafe void lsp_index_document(
    ref LspSemanticIndex index,
    ref LspState state,
    usize document
) {
    text source = lsp_document_source(state, document);
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
    usize depth = 0;
    usize token = 0;
    while token + 1 < tokens.length {
        if lsp_token_is(source, token_data, token, "}") {
            if depth > 0 { depth = depth - 1; }
        }
        if depth == 0 {
            usize kind = read_record_field(token_data, token, 0);
            if kind == 5 && (
                lsp_token_is(source, token_data, token, "struct") ||
                lsp_token_is(source, token_data, token, "resource") ||
                lsp_token_is(source, token_data, token, "enum")
            ) {
                usize name_token = token + 1;
                if name_token < tokens.length &&
                    read_record_field(
                        token_data, name_token, 0
                    ) == 1 {
                    usize symbol_kind = 2;
                    if lsp_token_is(
                        source, token_data, token, "resource"
                    ) {
                        symbol_kind = 3;
                    } else if lsp_token_is(
                        source, token_data, token, "enum"
                    ) {
                        symbol_kind = 4;
                    }
                    usize name_start = read_record_field(
                        token_data, name_token, 1
                    );
                    usize name_length = read_record_field(
                        token_data, name_token, 2
                    );
                    lsp_add_semantic_symbol(
                        index, document,
                        name_start, name_length,
                        name_start, name_length, symbol_kind
                    );
                }
            } else if kind == 5 && lsp_token_is(
                source, token_data, token, "const"
            ) {
                usize type_token = token + 1;
                usize name_token = token + 2;
                if name_token < tokens.length &&
                    read_record_field(
                        token_data, name_token, 0
                    ) == 1 {
                    lsp_add_semantic_symbol(
                        index, document,
                        read_record_field(
                            token_data, name_token, 1
                        ),
                        read_record_field(
                            token_data, name_token, 2
                        ),
                        read_record_field(
                            token_data, type_token, 1
                        ),
                        read_record_field(
                            token_data, type_token, 2
                        ),
                        6
                    );
                }
            } else if kind == 1 && token > 0 &&
                token + 1 < tokens.length &&
                lsp_token_is(
                    source, token_data, token + 1, "("
                ) {
                usize prior_kind = read_record_field(
                    token_data, token - 1, 0
                );
                if prior_kind == 1 || prior_kind == 5 {
                    lsp_add_semantic_symbol(
                        index, document,
                        read_record_field(token_data, token, 1),
                        read_record_field(token_data, token, 2),
                        read_record_field(
                            token_data, token - 1, 1
                        ),
                        read_record_field(
                            token_data, token - 1, 2
                        ),
                        1
                    );
                }
            }
        }
        if lsp_token_is(source, token_data, token, "{") {
            depth = depth + 1;
        }
        token = token + 1;
    }
}

unsafe LspSemanticIndex lsp_build_semantic_index(
    ref LspState state
) {
    LspSemanticIndex index = lsp_semantic_index_create();
    usize rank = 0;
    usize count = lsp_project_document_count(state);
    while rank < count {
        usize document = lsp_sorted_document(state, rank);
        if document < lsp_max_documents() {
            lsp_index_document(index, state, document);
        }
        rank = rank + 1;
    }
    return index;
}

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

unsafe bool lsp_identifier_at(
    text source,
    usize offset,
    out TextSpan identifier
) {
    identifier = TextSpan{ start = 0, length = 0 };
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
            identifier = TextSpan{ start = start, length = length };
            return true;
        }
        token = token + 1;
    }
    return false;
}

unsafe bool lsp_request_identifier(
    ref LspState state,
    text request,
    out usize document,
    out TextSpan identifier
) {
    document = lsp_request_document(state, request);
    identifier = TextSpan{ start = 0, length = 0 };
    if document >= lsp_max_documents() ||
        !lsp_document_in_project(state, document) {
        return false;
    }
    text source = lsp_document_source(state, document);
    usize offset = lsp_offset_at_position(
        source,
        lsp_json_usize(request, "line", 0),
        lsp_json_usize(request, "character", 0)
    );
    TextSpan found;
    bool result = lsp_identifier_at(source, offset, out found);
    identifier = found;
    return result;
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

unsafe void lsp_respond_document_symbols(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document = lsp_request_document(state, request);
    if document >= lsp_max_documents() ||
        !lsp_document_in_project(state, document) {
        lsp_respond_error(
            request, id, -32602, "document is not open in the project"
        );
        return;
    }
    LspSemanticIndex index = lsp_build_semantic_index(state);
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":[");
    usize symbol = 0;
    usize emitted = 0;
    while symbol < index.symbols.length {
        if read_record_field(index.symbol_data, symbol, 0) ==
            document {
            if emitted != 0 { d_put(payload, ","); }
            d_put(payload, "{\"name\":\"");
            lsp_put_symbol_name(payload, index, state, symbol);
            d_put(payload, "\",\"detail\":\"");
            lsp_put_symbol_detail(payload, index, state, symbol);
            d_put(payload, "\",\"kind\":");
            d_put_usize(
                payload, lsp_symbol_lsp_kind(index, symbol)
            );
            usize start = read_record_field(
                index.symbol_data, symbol, 1
            );
            usize length = read_record_field(
                index.symbol_data, symbol, 2
            );
            d_put(payload, ",\"range\":");
            lsp_put_range(
                payload, lsp_document_source(state, document),
                start, length
            );
            d_put(payload, ",\"selectionRange\":");
            lsp_put_range(
                payload, lsp_document_source(state, document),
                start, length
            );
            d_put(payload, "}");
            emitted = emitted + 1;
        }
        symbol = symbol + 1;
    }
    d_put(payload, "]}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
    lsp_semantic_index_destroy(index);
}

unsafe void lsp_respond_hover(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document;
    TextSpan name;
    if !lsp_request_identifier(
        state, request, out document, out name
    ) {
        lsp_respond_null(request, id);
        return;
    }
    LspSemanticIndex index = lsp_build_semantic_index(state);
    usize symbol = lsp_find_symbol(
        index, state, lsp_document_source(state, document), name
    );
    if symbol == index.symbols.length {
        lsp_semantic_index_destroy(index);
        lsp_respond_null(request, id);
        return;
    }
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":{\"contents\":{\"kind\":\"markdown\",");
    d_put(payload, "\"value\":\"```openc\\n");
    lsp_put_symbol_detail(payload, index, state, symbol);
    d_put(payload, "\\n```\"},\"range\":");
    lsp_put_range(
        payload, lsp_document_source(state, document),
        name.start, name.length
    );
    d_put(payload, "}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
    lsp_semantic_index_destroy(index);
}

unsafe void lsp_respond_definition(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document;
    TextSpan name;
    LspSemanticIndex index = lsp_build_semantic_index(state);
    usize symbol = index.symbols.length;
    if lsp_request_identifier(
        state, request, out document, out name
    ) {
        symbol = lsp_find_symbol(
            index, state,
            lsp_document_source(state, document), name
        );
    }
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":[");
    if symbol < index.symbols.length {
        lsp_put_symbol_location(payload, index, state, symbol);
    }
    d_put(payload, "]}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
    lsp_semantic_index_destroy(index);
}

unsafe bool lsp_span_equals(
    text left,
    usize left_start,
    usize left_length,
    text right,
    usize right_start,
    usize right_length
) {
    if left_length != right_length { return false; }
    usize cursor = 0;
    while cursor < left_length {
        if byte_at_or_zero(left, left_start + cursor) !=
            byte_at_or_zero(right, right_start + cursor) {
            return false;
        }
        cursor = cursor + 1;
    }
    return true;
}

unsafe usize lsp_document_reference_count(
    text source,
    text name_source,
    TextSpan name
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
    usize count = 0;
    usize token = 0;
    while token < tokens.length {
        usize start = read_record_field(token_data, token, 1);
        usize length = read_record_field(token_data, token, 2);
        if read_record_field(token_data, token, 0) == 1 &&
            lsp_span_equals(
                source, start, length,
                name_source, name.start, name.length
            ) {
            count = count + 1;
        }
        token = token + 1;
    }
    return count;
}

unsafe usize lsp_put_document_references(
    ref DBuffer output,
    text uri,
    text source,
    text name_source,
    TextSpan name,
    usize emitted
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
            lsp_span_equals(
                source, start, length,
                name_source, name.start, name.length
            ) {
            if emitted != 0 { d_put(output, ","); }
            d_put(output, "{\"uri\":");
            cli_json_text(output, uri);
            d_put(output, ",\"range\":");
            lsp_put_range(output, source, start, length);
            d_put(output, "}");
            emitted = emitted + 1;
        }
        token = token + 1;
    }
    return emitted;
}

unsafe void lsp_respond_references(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document;
    TextSpan name;
    bool found = lsp_request_identifier(
        state, request, out document, out name
    );
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":[");
    if found {
        text name_source = lsp_document_source(state, document);
        usize emitted = 0;
        usize rank = 0;
        usize count = lsp_project_document_count(state);
        while rank < count {
            usize candidate = lsp_sorted_document(state, rank);
            emitted = lsp_put_document_references(
                payload,
                lsp_document_uri(state, candidate),
                lsp_document_source(state, candidate),
                name_source, name, emitted
            );
            rank = rank + 1;
        }
    }
    d_put(payload, "]}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}

unsafe bool lsp_symbol_name_less(
    ref LspSemanticIndex index,
    ref LspState state,
    usize left,
    usize right
) {
    usize left_document = read_record_field(
        index.symbol_data, left, 0
    );
    usize right_document = read_record_field(
        index.symbol_data, right, 0
    );
    text left_source = lsp_document_source(state, left_document);
    text right_source = lsp_document_source(state, right_document);
    usize left_start = read_record_field(
        index.symbol_data, left, 1
    );
    usize right_start = read_record_field(
        index.symbol_data, right, 1
    );
    usize left_length = read_record_field(
        index.symbol_data, left, 2
    );
    usize right_length = read_record_field(
        index.symbol_data, right, 2
    );
    usize count = left_length;
    if right_length < count { count = right_length; }
    usize cursor = 0;
    while cursor < count {
        u8 left_byte = byte_at_or_zero(
            left_source, left_start + cursor
        );
        u8 right_byte = byte_at_or_zero(
            right_source, right_start + cursor
        );
        if left_byte < right_byte { return true; }
        if left_byte > right_byte { return false; }
        cursor = cursor + 1;
    }
    return left_length < right_length;
}

unsafe bool lsp_symbol_names_equal(
    ref LspSemanticIndex index,
    ref LspState state,
    usize left,
    usize right
) {
    usize left_document = read_record_field(
        index.symbol_data, left, 0
    );
    usize right_document = read_record_field(
        index.symbol_data, right, 0
    );
    return lsp_span_equals(
        lsp_document_source(state, left_document),
        read_record_field(index.symbol_data, left, 1),
        read_record_field(index.symbol_data, left, 2),
        lsp_document_source(state, right_document),
        read_record_field(index.symbol_data, right, 1),
        read_record_field(index.symbol_data, right, 2)
    );
}

unsafe bool lsp_symbol_is_first_name(
    ref LspSemanticIndex index,
    ref LspState state,
    usize symbol
) {
    usize prior = 0;
    while prior < symbol {
        if lsp_symbol_names_equal(
            index, state, prior, symbol
        ) {
            return false;
        }
        prior = prior + 1;
    }
    return true;
}

unsafe usize lsp_sorted_unique_symbol(
    ref LspSemanticIndex index,
    ref LspState state,
    usize rank
) {
    usize symbol = 0;
    while symbol < index.symbols.length {
        if lsp_symbol_is_first_name(index, state, symbol) {
            usize before = 0;
            usize other = 0;
            while other < index.symbols.length {
                if lsp_symbol_is_first_name(
                    index, state, other
                ) && lsp_symbol_name_less(
                    index, state, other, symbol
                ) {
                    before = before + 1;
                }
                other = other + 1;
            }
            if before == rank { return symbol; }
        }
        symbol = symbol + 1;
    }
    return index.symbols.length;
}

unsafe usize lsp_unique_symbol_count(
    ref LspSemanticIndex index,
    ref LspState state
) {
    usize count = 0;
    usize symbol = 0;
    while symbol < index.symbols.length {
        if lsp_symbol_is_first_name(index, state, symbol) {
            count = count + 1;
        }
        symbol = symbol + 1;
    }
    return count;
}

unsafe void lsp_respond_completion(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document = lsp_request_document(state, request);
    if document >= lsp_max_documents() ||
        !lsp_document_in_project(state, document) {
        lsp_respond_error(
            request, id, -32602, "document is not open in the project"
        );
        return;
    }
    LspSemanticIndex index = lsp_build_semantic_index(state);
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":{\"isIncomplete\":false,\"items\":[");
    usize rank = 0;
    usize count = lsp_unique_symbol_count(index, state);
    while rank < count {
        usize symbol = lsp_sorted_unique_symbol(
            index, state, rank
        );
        if rank != 0 { d_put(payload, ","); }
        d_put(payload, "{\"label\":\"");
        lsp_put_symbol_name(payload, index, state, symbol);
        d_put(payload, "\",\"kind\":");
        d_put_usize(
            payload, lsp_completion_lsp_kind(index, symbol)
        );
        d_put(payload, ",\"detail\":\"");
        lsp_put_symbol_detail(payload, index, state, symbol);
        d_put(payload, "\"}");
        rank = rank + 1;
    }
    d_put(payload, "]}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
    lsp_semantic_index_destroy(index);
}

unsafe void lsp_respond_prepare_rename(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document;
    TextSpan name;
    if !lsp_request_identifier(
        state, request, out document, out name
    ) {
        lsp_respond_error(
            request, id, -32602, "rename target is not an identifier"
        );
        return;
    }
    LspSemanticIndex index = lsp_build_semantic_index(state);
    usize symbol = lsp_find_symbol(
        index, state, lsp_document_source(state, document), name
    );
    if symbol == index.symbols.length {
        lsp_semantic_index_destroy(index);
        lsp_respond_error(
            request, id, -32602, "rename target has no declaration"
        );
        return;
    }
    DBuffer payload = d_buffer_create(65536);
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":{\"range\":");
    lsp_put_range(
        payload, lsp_document_source(state, document),
        name.start, name.length
    );
    d_put(payload, ",\"placeholder\":\"");
    d_put_slice(
        payload, lsp_document_source(state, document),
        name.start, name.length
    );
    d_put(payload, "\"}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
    lsp_semantic_index_destroy(index);
}

bool lsp_valid_identifier(text value) {
    usize length = text.byte_length(value);
    if length == 0 ||
        !is_identifier_start(byte_at_or_zero(value, 0)) {
        return false;
    }
    usize cursor = 1;
    while cursor < length {
        if !is_identifier_continue(byte_at_or_zero(value, cursor)) {
            return false;
        }
        cursor = cursor + 1;
    }
    return !is_keyword(value, 0, length);
}

unsafe bool lsp_rename_collides(
    ref LspSemanticIndex index,
    ref LspState state,
    text old_source,
    TextSpan old_name,
    text new_name
) {
    TextSpan new_span = TextSpan{
        start = 0, length = text.byte_length(new_name)
    };
    usize symbol = 0;
    while symbol < index.symbols.length {
        if lsp_symbol_name_equal(
            index, state, symbol, new_name, new_span
        ) && !lsp_symbol_name_equal(
            index, state, symbol, old_source, old_name
        ) {
            return true;
        }
        symbol = symbol + 1;
    }
    return false;
}

unsafe usize lsp_put_document_rename_edits(
    ref DBuffer output,
    text source,
    text old_source,
    TextSpan old_name,
    text new_name
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
    usize edits = 0;
    usize token = 0;
    while token < tokens.length {
        usize start = read_record_field(token_data, token, 1);
        usize length = read_record_field(token_data, token, 2);
        if read_record_field(token_data, token, 0) == 1 &&
            lsp_span_equals(
                source, start, length,
                old_source, old_name.start, old_name.length
            ) {
            if edits != 0 { d_put(output, ","); }
            d_put(output, "{\"range\":");
            lsp_put_range(output, source, start, length);
            d_put(output, ",\"newText\":");
            cli_json_text(output, new_name);
            d_put(output, "}");
            edits = edits + 1;
        }
        token = token + 1;
    }
    return edits;
}

unsafe void lsp_respond_rename(
    ref LspState state,
    text request,
    TextSpan id
) {
    usize document;
    TextSpan old_name;
    if !lsp_request_identifier(
        state, request, out document, out old_name
    ) {
        lsp_respond_error(
            request, id, -32602, "rename target is not an identifier"
        );
        return;
    }
    DBuffer new_name = d_buffer_create(1024);
    if !lsp_json_string(request, "newName", new_name) ||
        !lsp_valid_identifier(d_buffer_text(new_name)) {
        d_buffer_destroy(new_name);
        lsp_respond_error(
            request, id, -32602, "newName is not a safe OpenC identifier"
        );
        return;
    }
    text old_source = lsp_document_source(state, document);
    LspSemanticIndex index = lsp_build_semantic_index(state);
    usize symbol = lsp_find_symbol(
        index, state, old_source, old_name
    );
    if symbol == index.symbols.length ||
        lsp_rename_collides(
            index, state, old_source, old_name,
            d_buffer_text(new_name)
        ) {
        lsp_semantic_index_destroy(index);
        d_buffer_destroy(new_name);
        lsp_respond_error(
            request, id, -32602,
            "rename is unresolved or collides with a declaration"
        );
        return;
    }
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":{\"changes\":{");
    usize emitted_documents = 0;
    usize rank = 0;
    usize count = lsp_project_document_count(state);
    while rank < count {
        usize candidate = lsp_sorted_document(state, rank);
        text candidate_source = lsp_document_source(
            state, candidate
        );
        usize references = lsp_document_reference_count(
            candidate_source, old_source, old_name
        );
        if references != 0 {
            if emitted_documents != 0 { d_put(payload, ","); }
            cli_json_text(
                payload, lsp_document_uri(state, candidate)
            );
            d_put(payload, ":[");
            lsp_put_document_rename_edits(
                payload, candidate_source,
                old_source, old_name, d_buffer_text(new_name)
            );
            d_put(payload, "]");
            emitted_documents = emitted_documents + 1;
        }
        rank = rank + 1;
    }
    d_put(payload, "}}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
    lsp_semantic_index_destroy(index);
    d_buffer_destroy(new_name);
}
