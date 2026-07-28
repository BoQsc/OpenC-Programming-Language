import system.file;
import system.io;
import system.memory;
import system.text;

struct LspDocument {
    bool open;
    usize version;
    DBuffer uri;
    DBuffer source;
}

struct LspState {
    bool initialized;
    bool shutdown_requested;
    DBuffer root_uri;
    LspDocument document0;
    LspDocument document1;
    LspDocument document2;
    LspDocument document3;
    LspDocument document4;
    LspDocument document5;
    LspDocument document6;
    LspDocument document7;
}

usize lsp_max_documents() {
    return 8;
}

unsafe LspDocument lsp_document_create() {
    return LspDocument{
        open = false,
        version = 0,
        uri = d_buffer_create(16384),
        source = d_buffer_create(4194304)
    };
}

unsafe void lsp_document_destroy(ref LspDocument document) {
    d_buffer_destroy(document.source);
    d_buffer_destroy(document.uri);
}

unsafe void lsp_state_destroy(ref LspState state) {
    lsp_document_destroy(state.document7);
    lsp_document_destroy(state.document6);
    lsp_document_destroy(state.document5);
    lsp_document_destroy(state.document4);
    lsp_document_destroy(state.document3);
    lsp_document_destroy(state.document2);
    lsp_document_destroy(state.document1);
    lsp_document_destroy(state.document0);
    d_buffer_destroy(state.root_uri);
}

unsafe bool lsp_document_open(ref LspState state, usize index) {
    if index == 0 { return state.document0.open; }
    if index == 1 { return state.document1.open; }
    if index == 2 { return state.document2.open; }
    if index == 3 { return state.document3.open; }
    if index == 4 { return state.document4.open; }
    if index == 5 { return state.document5.open; }
    if index == 6 { return state.document6.open; }
    if index == 7 { return state.document7.open; }
    return false;
}

unsafe text lsp_document_uri(ref LspState state, usize index) {
    if index == 0 { return d_buffer_text(state.document0.uri); }
    if index == 1 { return d_buffer_text(state.document1.uri); }
    if index == 2 { return d_buffer_text(state.document2.uri); }
    if index == 3 { return d_buffer_text(state.document3.uri); }
    if index == 4 { return d_buffer_text(state.document4.uri); }
    if index == 5 { return d_buffer_text(state.document5.uri); }
    if index == 6 { return d_buffer_text(state.document6.uri); }
    return d_buffer_text(state.document7.uri);
}

unsafe text lsp_document_source(ref LspState state, usize index) {
    if index == 0 { return d_buffer_text(state.document0.source); }
    if index == 1 { return d_buffer_text(state.document1.source); }
    if index == 2 { return d_buffer_text(state.document2.source); }
    if index == 3 { return d_buffer_text(state.document3.source); }
    if index == 4 { return d_buffer_text(state.document4.source); }
    if index == 5 { return d_buffer_text(state.document5.source); }
    if index == 6 { return d_buffer_text(state.document6.source); }
    return d_buffer_text(state.document7.source);
}

unsafe usize lsp_document_version(ref LspState state, usize index) {
    if index == 0 { return state.document0.version; }
    if index == 1 { return state.document1.version; }
    if index == 2 { return state.document2.version; }
    if index == 3 { return state.document3.version; }
    if index == 4 { return state.document4.version; }
    if index == 5 { return state.document5.version; }
    if index == 6 { return state.document6.version; }
    return state.document7.version;
}

unsafe void lsp_document_close(ref LspState state, usize index) {
    if index == 0 {
        state.document0.open = false;
        state.document0.source.length = 0;
    } else if index == 1 {
        state.document1.open = false;
        state.document1.source.length = 0;
    } else if index == 2 {
        state.document2.open = false;
        state.document2.source.length = 0;
    } else if index == 3 {
        state.document3.open = false;
        state.document3.source.length = 0;
    } else if index == 4 {
        state.document4.open = false;
        state.document4.source.length = 0;
    } else if index == 5 {
        state.document5.open = false;
        state.document5.source.length = 0;
    } else if index == 6 {
        state.document6.open = false;
        state.document6.source.length = 0;
    } else if index == 7 {
        state.document7.open = false;
        state.document7.source.length = 0;
    }
}

unsafe bool lsp_text_has_prefix(text value, text prefix) {
    usize prefix_length = text.byte_length(prefix);
    if prefix_length == 0 { return true; }
    if text.byte_length(value) < prefix_length { return false; }
    usize cursor = 0;
    while cursor < prefix_length {
        if byte_at_or_zero(value, cursor) !=
            byte_at_or_zero(prefix, cursor) {
            return false;
        }
        cursor = cursor + 1;
    }
    return true;
}

unsafe bool lsp_document_in_project(
    ref LspState state,
    usize index
) {
    return lsp_document_open(state, index) && lsp_text_has_prefix(
        lsp_document_uri(state, index), d_buffer_text(state.root_uri)
    );
}

unsafe usize lsp_find_document(ref LspState state, text uri) {
    usize index = 0;
    while index < lsp_max_documents() {
        if lsp_document_open(state, index) &&
            text.equal(lsp_document_uri(state, index), uri) {
            return index;
        }
        index = index + 1;
    }
    return lsp_max_documents();
}

unsafe usize lsp_free_document(ref LspState state) {
    usize index = 0;
    while index < lsp_max_documents() {
        if !lsp_document_open(state, index) { return index; }
        index = index + 1;
    }
    return lsp_max_documents();
}

unsafe bool lsp_store_document(
    ref LspDocument document,
    text uri,
    text source,
    usize version
) {
    document.uri.length = 0;
    document.uri.ok = true;
    d_put(document.uri, uri);
    document.source.length = 0;
    document.source.ok = true;
    d_put(document.source, source);
    document.version = version;
    document.open = document.uri.ok && document.source.ok;
    return document.open;
}

unsafe bool lsp_store_document_at(
    ref LspState state,
    usize index,
    text uri,
    text source,
    usize version
) {
    if index == 0 {
        return lsp_store_document(state.document0, uri, source, version);
    }
    if index == 1 {
        return lsp_store_document(state.document1, uri, source, version);
    }
    if index == 2 {
        return lsp_store_document(state.document2, uri, source, version);
    }
    if index == 3 {
        return lsp_store_document(state.document3, uri, source, version);
    }
    if index == 4 {
        return lsp_store_document(state.document4, uri, source, version);
    }
    if index == 5 {
        return lsp_store_document(state.document5, uri, source, version);
    }
    if index == 6 {
        return lsp_store_document(state.document6, uri, source, version);
    }
    if index == 7 {
        return lsp_store_document(state.document7, uri, source, version);
    }
    return false;
}

bool lsp_json_space(u8 value) {
    return value == 32 || value == 9 || value == 10 || value == 13;
}

usize lsp_skip_json_space(text source, usize cursor) {
    usize length = text.byte_length(source);
    while cursor < length && lsp_json_space(
        byte_at_or_zero(source, cursor)
    ) {
        cursor = cursor + 1;
    }
    return cursor;
}

unsafe status lsp_json_field_value(
    text source,
    text field,
    out TextSpan value
) {
    DBuffer needle = d_buffer_create(text.byte_length(field) + 3);
    d_put(needle, "\"");
    d_put(needle, field);
    d_put(needle, "\"");
    if !needle.ok {
        d_buffer_destroy(needle);
        value = TextSpan{ start = 0, length = 0 };
        return status{ code = 1, message = "field buffer capacity" };
    }
    usize found = native_find(source, d_buffer_text(needle));
    usize needle_length = text.byte_length(d_buffer_text(needle));
    d_buffer_destroy(needle);
    usize source_length = text.byte_length(source);
    if found > source_length {
        value = TextSpan{ start = 0, length = 0 };
        return status{ code = 1, message = "field is absent" };
    }
    usize cursor = lsp_skip_json_space(
        source, found + needle_length
    );
    if cursor >= source_length ||
        byte_at_or_zero(source, cursor) != 58 {
        value = TextSpan{ start = 0, length = 0 };
        return status{ code = 1, message = "field has no colon" };
    }
    cursor = lsp_skip_json_space(source, cursor + 1);
    if cursor >= source_length {
        value = TextSpan{ start = 0, length = 0 };
        return status{ code = 1, message = "field value is absent" };
    }
    usize start = cursor;
    u8 first = byte_at_or_zero(source, cursor);
    if first == 34 {
        cursor = cursor + 1;
        bool escaped = false;
        while cursor < source_length {
            u8 current = byte_at_or_zero(source, cursor);
            if escaped {
                escaped = false;
            } else if current == 92 {
                escaped = true;
            } else if current == 34 {
                cursor = cursor + 1;
                value = TextSpan{
                    start = start, length = cursor - start
                };
                return status{ code = 0 };
            }
            cursor = cursor + 1;
        }
        value = TextSpan{ start = 0, length = 0 };
        return status{ code = 1, message = "string is not terminated" };
    }
    while cursor < source_length {
        u8 current = byte_at_or_zero(source, cursor);
        if current == 44 || current == 125 ||
            current == 93 || lsp_json_space(current) {
            value = TextSpan{
                start = start, length = cursor - start
            };
            if value.length != 0 { return status{ code = 0 }; }
            return status{ code = 1, message = "field value is empty" };
        }
        cursor = cursor + 1;
    }
    value = TextSpan{ start = start, length = cursor - start };
    if value.length != 0 { return status{ code = 0 }; }
    return status{ code = 1, message = "field value is empty" };
}

usize lsp_hex_value(u8 value) {
    if value >= 48 && value <= 57 {
        return cast(usize, value - 48);
    }
    if value >= 65 && value <= 70 {
        return cast(usize, value - 65 + 10);
    }
    if value >= 97 && value <= 102 {
        return cast(usize, value - 97 + 10);
    }
    return 16;
}

unsafe bool lsp_put_utf8(ref DBuffer output, usize scalar) {
    if scalar <= 127 {
        d_put_byte(output, cast(u8, scalar));
    } else if scalar <= 2047 {
        d_put_byte(output, cast(u8, 192 + scalar / 64));
        d_put_byte(output, cast(u8, 128 + scalar % 64));
    } else if scalar <= 65535 {
        d_put_byte(output, cast(u8, 224 + scalar / 4096));
        d_put_byte(output, cast(u8, 128 + (scalar / 64) % 64));
        d_put_byte(output, cast(u8, 128 + scalar % 64));
    } else if scalar <= 1114111 {
        d_put_byte(output, cast(u8, 240 + scalar / 262144));
        d_put_byte(output, cast(u8, 128 + (scalar / 4096) % 64));
        d_put_byte(output, cast(u8, 128 + (scalar / 64) % 64));
        d_put_byte(output, cast(u8, 128 + scalar % 64));
    } else {
        return false;
    }
    return output.ok;
}

unsafe bool lsp_decode_json_string(
    text source,
    TextSpan raw,
    ref DBuffer output
) {
    output.length = 0;
    output.ok = true;
    if raw.length < 2 ||
        byte_at_or_zero(source, raw.start) != 34 ||
        byte_at_or_zero(source, raw.start + raw.length - 1) != 34 {
        return false;
    }
    usize cursor = raw.start + 1;
    usize end = raw.start + raw.length - 1;
    while cursor < end {
        u8 value = byte_at_or_zero(source, cursor);
        if value != 92 {
            d_put_byte(output, value);
            cursor = cursor + 1;
        } else {
            cursor = cursor + 1;
            if cursor >= end { return false; }
            u8 escaped = byte_at_or_zero(source, cursor);
            if escaped == 34 || escaped == 92 || escaped == 47 {
                d_put_byte(output, escaped);
            } else if escaped == 98 {
                d_put_byte(output, 8);
            } else if escaped == 102 {
                d_put_byte(output, 12);
            } else if escaped == 110 {
                d_put_byte(output, 10);
            } else if escaped == 114 {
                d_put_byte(output, 13);
            } else if escaped == 116 {
                d_put_byte(output, 9);
            } else if escaped == 117 {
                if cursor + 4 >= end { return false; }
                usize one = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 1)
                );
                usize two = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 2)
                );
                usize three = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 3)
                );
                usize four = lsp_hex_value(
                    byte_at_or_zero(source, cursor + 4)
                );
                if one > 15 || two > 15 || three > 15 || four > 15 {
                    return false;
                }
                usize scalar = one * 4096 + two * 256 +
                    three * 16 + four;
                if scalar >= 55296 && scalar <= 57343 {
                    return false;
                }
                if !lsp_put_utf8(output, scalar) { return false; }
                cursor = cursor + 4;
            } else {
                return false;
            }
            cursor = cursor + 1;
        }
    }
    return output.ok;
}

unsafe bool lsp_json_string(
    text source,
    text field,
    ref DBuffer output
) {
    TextSpan raw;
    status found = lsp_json_field_value(source, field, out raw);
    if !found.ok {
        return false;
    }
    return lsp_decode_json_string(source, raw, output);
}

unsafe usize lsp_json_usize(
    text source,
    text field,
    usize fallback
) {
    TextSpan raw;
    status found = lsp_json_field_value(source, field, out raw);
    if !found.ok {
        return fallback;
    }
    usize value = 0;
    usize cursor = 0;
    if raw.length == 0 { return fallback; }
    while cursor < raw.length {
        u8 digit = byte_at_or_zero(source, raw.start + cursor);
        if digit < 48 || digit > 57 { return fallback; }
        value = value * 10 + cast(usize, digit - 48);
        cursor = cursor + 1;
    }
    return value;
}

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
    d_put(payload, "\"textDocumentSync\":{\"openClose\":true,\"change\":1},");
    d_put(payload, "\"documentFormattingProvider\":true,");
    d_put(payload, "\"documentSymbolProvider\":true,");
    d_put(payload, "\"hoverProvider\":true,");
    d_put(payload, "\"definitionProvider\":true,");
    d_put(payload, "\"referencesProvider\":true,");
    d_put(payload, "\"completionProvider\":{\"resolveProvider\":false},");
    d_put(payload, "\"renameProvider\":{\"prepareProvider\":true}");
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

unsafe i32 lsp_handle_message(
    ref LspState state,
    text request
) {
    DBuffer method = d_buffer_create(256);
    bool has_method = lsp_json_string(request, "method", method);
    TextSpan id = TextSpan{ start = 0, length = 0 };
    status id_status = lsp_json_field_value(request, "id", out id);
    bool has_id = id_status.ok;
    if !has_method {
        if has_id {
            lsp_respond_error(
                request, id, -32600, "invalid JSON-RPC request"
            );
        }
        d_buffer_destroy(method);
        return -2;
    }
    text name = d_buffer_text(method);
    if name == "exit" {
        i32 code = 1;
        if state.shutdown_requested { code = 0; }
        d_buffer_destroy(method);
        return code;
    }
    if state.shutdown_requested {
        if has_id {
            lsp_respond_error(
                request, id, -32600, "server is shutting down"
            );
        }
        d_buffer_destroy(method);
        return -2;
    }
    if name == "initialize" {
        if !has_id {
            d_buffer_destroy(method);
            return -2;
        }
        if state.initialized {
            lsp_respond_error(
                request, id, -32600, "server is already initialized"
            );
        } else {
            state.initialized = true;
            lsp_respond_initialize(state, request, id);
        }
    } else if !state.initialized {
        if has_id {
            lsp_respond_error(
                request, id, -32002, "server is not initialized"
            );
        }
    } else if name == "initialized" {
    } else if name == "shutdown" {
        if has_id {
            state.shutdown_requested = true;
            lsp_respond_null(request, id);
        }
    } else if name == "textDocument/didOpen" {
        usize document = lsp_update_document(state, request, true);
        if document < lsp_max_documents() {
            lsp_publish_diagnostics(state, document);
        }
    } else if name == "textDocument/didChange" {
        usize document = lsp_update_document(state, request, false);
        if document < lsp_max_documents() {
            lsp_publish_diagnostics(state, document);
        }
    } else if name == "textDocument/didClose" {
        usize document = lsp_request_document(state, request);
        if document < lsp_max_documents() {
            lsp_publish_empty_diagnostics(state, document);
            lsp_document_close(state, document);
        }
    } else if name == "textDocument/formatting" {
        if has_id {
            usize document = lsp_request_document(state, request);
            if document < lsp_max_documents() {
                lsp_respond_formatting(
                    state, document, request, id
                );
            } else {
                lsp_respond_error(
                    request, id, -32602, "document is not open"
                );
            }
        }
    } else if name == "textDocument/documentSymbol" {
        if has_id {
            lsp_respond_document_symbols(state, request, id);
        }
    } else if name == "textDocument/hover" {
        if has_id { lsp_respond_hover(state, request, id); }
    } else if name == "textDocument/definition" {
        if has_id { lsp_respond_definition(state, request, id); }
    } else if name == "textDocument/references" {
        if has_id { lsp_respond_references(state, request, id); }
    } else if name == "textDocument/completion" {
        if has_id { lsp_respond_completion(state, request, id); }
    } else if name == "textDocument/prepareRename" {
        if has_id {
            lsp_respond_prepare_rename(state, request, id);
        }
    } else if name == "textDocument/rename" {
        if has_id { lsp_respond_rename(state, request, id); }
    } else if has_id {
        lsp_respond_error(
            request, id, -32601, "method not implemented"
        );
    }
    d_buffer_destroy(method);
    return -2;
}

unsafe i32 cli_lsp_stdio() {
    LspState state = LspState{
        initialized = false,
        shutdown_requested = false,
        root_uri = d_buffer_create(16384),
        document0 = lsp_document_create(),
        document1 = lsp_document_create(),
        document2 = lsp_document_create(),
        document3 = lsp_document_create(),
        document4 = lsp_document_create(),
        document5 = lsp_document_create(),
        document6 = lsp_document_create(),
        document7 = lsp_document_create()
    };
    while true {
        text request;
        status read = file.read_text(
            "@openc-internal:lsp-stdio-frame", out request
        );
        if !read.ok || text.byte_length(request) == 0 {
            lsp_state_destroy(state);
            return 0;
        }
        i32 action = lsp_handle_message(state, request);
        if action != -2 {
            lsp_state_destroy(state);
            return action;
        }
    }
}
