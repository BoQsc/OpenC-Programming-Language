import system.file;
import system.io;
import system.memory;
import system.text;

unsafe usize lsp_update_document(
    ref LspState state,
    text request,
    bool opening
) {
    DBuffer uri = d_buffer_create(16384);
    DBuffer source = d_buffer_create(4194304);
    bool decoded = lsp_json_string(request, "uri", uri) &&
        lsp_json_string(request, "text", source);
    usize document = lsp_max_documents();
    if decoded {
        document = lsp_find_document(state, d_buffer_text(uri));
        if document == lsp_max_documents() && opening {
            document = lsp_free_document(state);
        }
        if document < lsp_max_documents() {
            usize prior_version = lsp_document_version(
                state, document
            );
            usize version = lsp_json_usize(
                request, "version", prior_version
            );
            if !lsp_store_document_at(
                state, document, d_buffer_text(uri),
                d_buffer_text(source), version
            ) {
                document = lsp_max_documents();
            }
        }
    }
    d_buffer_destroy(source);
    d_buffer_destroy(uri);
    return document;
}

unsafe usize lsp_request_document(
    ref LspState state,
    text request
) {
    DBuffer uri = d_buffer_create(16384);
    bool decoded = lsp_json_string(request, "uri", uri);
    usize document = lsp_max_documents();
    if decoded {
        document = lsp_find_document(state, d_buffer_text(uri));
    }
    d_buffer_destroy(uri);
    return document;
}

unsafe void lsp_respond_formatting(
    ref LspState state,
    usize document,
    text request,
    TextSpan id
) {
    text source = lsp_document_source(state, document);
    DBuffer payload = d_buffer_create(
        text.byte_length(source) * 16 + 65536
    );
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":[");
    DBuffer diagnostics = d_buffer_create(
        text.byte_length(source) * 16 + 65536
    );
    usize errors = lsp_put_diagnostics(diagnostics, source);
    d_buffer_destroy(diagnostics);
    if errors == 0 {
        DBuffer formatted = d_buffer_create(1);
        if cli_format_source_text(source, formatted) {
            if !text.equal(source, d_buffer_text(formatted)) {
                d_put(payload, "{\"range\":{\"start\":");
                lsp_put_position(payload, source, 0);
                d_put(payload, ",\"end\":");
                lsp_put_position(
                    payload, source, text.byte_length(source)
                );
                d_put(payload, "},\"newText\":");
                cli_json_text(payload, d_buffer_text(formatted));
                d_put(payload, "}");
            }
            d_buffer_destroy(formatted);
        }
    }
    d_put(payload, "]}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}
