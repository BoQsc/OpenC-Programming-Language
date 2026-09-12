import system.memory;
import system.text;

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
    LspRequestIdentifierResult target = lsp_request_identifier(
        state, request
    );
    if !target.found {
        lsp_respond_null(request, id);
        return;
    }
    usize document = target.document;
    TextSpan name = target.identifier;
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
    LspSemanticIndex index = lsp_build_semantic_index(state);
    usize symbol = index.symbols.length;
    LspRequestIdentifierResult target = lsp_request_identifier(
        state, request
    );
    if target.found {
        symbol = lsp_find_symbol(
            index, state,
            lsp_document_source(state, target.document), target.identifier
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
    LspRequestIdentifierResult target = lsp_request_identifier(
        state, request
    );
    DBuffer payload = d_buffer_create(
        lsp_semantic_output_capacity(state)
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":[");
    if target.found {
        text name_source = lsp_document_source(state, target.document);
        usize emitted = 0;
        usize rank = 0;
        usize count = lsp_project_document_count(state);
        while rank < count {
            usize candidate = lsp_sorted_document(state, rank);
            emitted = lsp_put_document_references(
                payload,
                lsp_document_uri(state, candidate),
                lsp_document_source(state, candidate),
                name_source, target.identifier, emitted
            );
            rank = rank + 1;
        }
    }
    d_put(payload, "]}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}
