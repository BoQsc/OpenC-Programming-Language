import system.memory;
import system.text;

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
    LspRequestIdentifierResult target = lsp_request_identifier(
        state, request
    );
    if !target.found {
        lsp_respond_error(
            request, id, -32602, "rename target is not an identifier"
        );
        return;
    }
    usize document = target.document;
    TextSpan old_name = target.identifier;
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
