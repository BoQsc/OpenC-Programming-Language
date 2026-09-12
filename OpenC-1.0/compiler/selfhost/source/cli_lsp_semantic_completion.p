import system.memory;
import system.text;

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
    TextSpan name = target.identifier;
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
