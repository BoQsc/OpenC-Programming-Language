import system.file;
import system.io;
import system.memory;
import system.text;

unsafe void lsp_send(ref DBuffer payload) {
    io.print("Content-Length: ");
    io.print(payload.length);
    io.print("\r\n\r\n");
    io.print(d_buffer_text(payload));
}

unsafe void lsp_put_response_start(
    ref DBuffer payload,
    text request,
    TextSpan id
) {
    d_put(payload, "{\"jsonrpc\":\"2.0\",\"id\":");
    d_put_slice(payload, request, id.start, id.length);
}

unsafe void lsp_respond_error(
    text request,
    TextSpan id,
    i32 code,
    text message
) {
    DBuffer payload = d_buffer_create(65536);
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"error\":{\"code\":");
    if code < 0 {
        d_put(payload, "-");
        d_put_usize(payload, cast(usize, 0 - code));
    } else {
        d_put_usize(payload, cast(usize, code));
    }
    d_put(payload, ",\"message\":");
    cli_json_text(payload, message);
    d_put(payload, "}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}

unsafe void lsp_respond_initialize(
    ref LspState state,
    text request,
    TextSpan id
) {
    state.root_uri.length = 0;
    state.root_uri.ok = true;
    lsp_json_string(request, "rootUri", state.root_uri);
    DBuffer payload = d_buffer_create(65536);
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":{\"capabilities\":{");
    d_put(payload, "\"positionEncoding\":\"utf-8\",");
    d_put(payload, "\"textDocumentSync\":{\"openClose\":true,\"change\":2},");
    d_put(payload, "\"documentFormattingProvider\":true,");
    d_put(payload, "\"documentSymbolProvider\":true,");
    d_put(payload, "\"hoverProvider\":true,");
    d_put(payload, "\"definitionProvider\":true,");
    d_put(payload, "\"referencesProvider\":true,");
    d_put(payload, "\"completionProvider\":{\"resolveProvider\":false},");
    d_put(payload, "\"renameProvider\":{\"prepareProvider\":true},");
    d_put(payload, "\"workspace\":{\"workspaceFolders\":{");
    d_put(payload, "\"supported\":true,\"changeNotifications\":true}}");
    d_put(payload, "},\"serverInfo\":{\"name\":\"openc-lsp\",\"version\":");
    cli_json_text(payload, cli_version());
    d_put(payload, "}}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}

unsafe void lsp_respond_null(text request, TextSpan id) {
    DBuffer payload = d_buffer_create(1024);
    lsp_put_response_start(payload, request, id);
    d_put(payload, ",\"result\":null}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}

unsafe void lsp_put_position(
    ref DBuffer output,
    text source,
    usize offset
) {
    SourcePosition position = position_at(source, offset);
    d_put(output, "{\"line\":");
    d_put_usize(output, position.line - 1);
    d_put(output, ",\"character\":");
    d_put_usize(output, position.column - 1);
    d_put(output, "}");
}

unsafe usize lsp_put_diagnostics(
    ref DBuffer output,
    text source
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
        source,
        token_data, tokens,
        diagnostic_data, diagnostics
    );
    PackedBuffer syntax = PackedBuffer{
        length = 0, capacity = tokens.length * 6 + 8
    };
    ptr byte syntax_data = memory.alloc(
        syntax.capacity * record_stride()
    );
    scope memory.free(syntax_data);
    parse_source_syntax(
        source, token_data, tokens,
        syntax_data, syntax,
        diagnostic_data, diagnostics
    );
    assign_diagnostic_positions(source, diagnostic_data, diagnostics);
    usize diagnostic = 0;
    while diagnostic < diagnostics.length {
        if diagnostic != 0 { d_put(output, ","); }
        usize start = read_record_field(
            diagnostic_data, diagnostic, 1
        );
        usize length = read_record_field(
            diagnostic_data, diagnostic, 2
        );
        usize end = start + length;
        if end > source_length { end = source_length; }
        text rule = diagnostic_rule(read_record_field(
            diagnostic_data, diagnostic, 0
        ));
        d_put(output, "{\"range\":{\"start\":");
        lsp_put_position(output, source, start);
        d_put(output, ",\"end\":");
        lsp_put_position(output, source, end);
        d_put(output, "},\"severity\":1,\"code\":");
        cli_json_text(output, rule);
        d_put(output, ",\"source\":\"openc\",\"message\":");
        DBuffer message = d_buffer_create(
            text.byte_length(rule) + 40
        );
        d_put(message, "OpenC source rejected by ");
        d_put(message, rule);
        cli_json_text(output, d_buffer_text(message));
        d_buffer_destroy(message);
        d_put(output, ",\"data\":{\"byteStart\":");
        d_put_usize(output, start);
        d_put(output, ",\"byteLength\":");
        d_put_usize(output, length);
        d_put(output, "}}");
        diagnostic = diagnostic + 1;
    }
    return diagnostics.length;
}

unsafe void lsp_publish_diagnostics(
    ref LspState state,
    usize document
) {
    text source = lsp_document_source(state, document);
    DBuffer payload = d_buffer_create(
        text.byte_length(source) * 16 + 65536
    );
    d_put(payload, "{\"jsonrpc\":\"2.0\",\"method\":");
    cli_json_text(payload, "textDocument/publishDiagnostics");
    d_put(payload, ",\"params\":{\"uri\":");
    cli_json_text(payload, lsp_document_uri(state, document));
    d_put(payload, ",\"version\":");
    d_put_usize(payload, lsp_document_version(state, document));
    d_put(payload, ",\"diagnostics\":[");
    lsp_put_diagnostics(payload, source);
    d_put(payload, "]}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}

unsafe void lsp_publish_empty_diagnostics(
    ref LspState state,
    usize document
) {
    DBuffer payload = d_buffer_create(65536);
    d_put(payload, "{\"jsonrpc\":\"2.0\",\"method\":");
    cli_json_text(payload, "textDocument/publishDiagnostics");
    d_put(payload, ",\"params\":{\"uri\":");
    cli_json_text(payload, lsp_document_uri(state, document));
    d_put(payload, ",\"version\":");
    d_put_usize(payload, lsp_document_version(state, document));
    d_put(payload, ",\"diagnostics\":[]}}");
    if payload.ok { lsp_send(payload); }
    d_buffer_destroy(payload);
}
