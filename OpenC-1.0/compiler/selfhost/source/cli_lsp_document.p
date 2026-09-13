import system.file;
import system.io;
import system.memory;
import system.text;

unsafe usize lsp_find_from(
    text source,
    text expected,
    usize start
) {
    usize length = text.byte_length(source);
    if start >= length { return length + 1; }
    text suffix = project_slice(source, start, length - start);
    usize relative = native_find(suffix, expected);
    if relative > text.byte_length(suffix) { return length + 1; }
    return start + relative;
}

unsafe usize lsp_json_usize_from(
    text source,
    text field,
    usize start,
    usize fallback
) {
    DBuffer needle = d_buffer_create(text.byte_length(field) + 3);
    d_put(needle, "\"");
    d_put(needle, field);
    d_put(needle, "\"");
    if !needle.ok {
        d_buffer_destroy(needle);
        return fallback;
    }
    usize found = lsp_find_from(source, d_buffer_text(needle), start);
    usize needle_length = text.byte_length(d_buffer_text(needle));
    d_buffer_destroy(needle);
    usize length = text.byte_length(source);
    if found > length { return fallback; }
    usize cursor = lsp_skip_json_space(
        source, found + needle_length
    );
    if cursor >= length || byte_at_or_zero(source, cursor) != 58 {
        return fallback;
    }
    cursor = lsp_skip_json_space(source, cursor + 1);
    if cursor >= length { return fallback; }
    usize value = 0;
    usize digits = 0;
    while cursor < length {
        u8 digit = byte_at_or_zero(source, cursor);
        if digit < 48 || digit > 57 { break; }
        value = value * 10 + cast(usize, digit - 48);
        digits = digits + 1;
        cursor = cursor + 1;
    }
    if digits == 0 { return fallback; }
    return value;
}

unsafe usize lsp_position_offset(
    text source,
    usize wanted_line,
    usize wanted_character
) {
    usize length = text.byte_length(source);
    usize cursor = 0;
    usize line = 0;
    while line < wanted_line && cursor < length {
        if byte_at_or_zero(source, cursor) == 10 {
            line = line + 1;
        }
        cursor = cursor + 1;
    }
    if line != wanted_line { return length + 1; }
    usize line_start = cursor;
    while cursor < length && byte_at_or_zero(source, cursor) != 10 &&
        byte_at_or_zero(source, cursor) != 13 {
        cursor = cursor + 1;
    }
    if wanted_character > cursor - line_start { return length + 1; }
    return line_start + wanted_character;
}

unsafe bool lsp_apply_incremental_change(
    ref LspState state,
    usize document,
    text uri,
    text replacement,
    usize version,
    text request
) {
    usize range = native_find(request, "\"range\"");
    usize request_length = text.byte_length(request);
    if range > request_length {
        return lsp_store_document_at(
            state, document, uri, replacement, version
        );
    }
    usize start = lsp_find_from(request, "\"start\"", range);
    usize end = lsp_find_from(request, "\"end\"", start + 1);
    if start > request_length || end > request_length {
        return false;
    }
    usize invalid = request_length + 1;
    usize start_line = lsp_json_usize_from(
        request, "line", start, invalid
    );
    usize start_character = lsp_json_usize_from(
        request, "character", start, invalid
    );
    usize end_line = lsp_json_usize_from(
        request, "line", end, invalid
    );
    usize end_character = lsp_json_usize_from(
        request, "character", end, invalid
    );
    if start_line == invalid || start_character == invalid ||
        end_line == invalid || end_character == invalid {
        return false;
    }
    text prior = lsp_document_source(state, document);
    usize prior_length = text.byte_length(prior);
    usize first = lsp_position_offset(
        prior, start_line, start_character
    );
    usize last = lsp_position_offset(prior, end_line, end_character);
    if first > prior_length || last > prior_length || last < first {
        return false;
    }
    usize replacement_length = text.byte_length(replacement);
    if first + replacement_length + prior_length - last >
        lsp_max_message_bytes() {
        return false;
    }
    DBuffer updated = d_buffer_create(lsp_max_message_bytes());
    d_put_slice(updated, prior, 0, first);
    d_put(updated, replacement);
    d_put_slice(updated, prior, last, prior_length - last);
    bool stored = updated.ok && lsp_store_document_at(
        state, document, uri, d_buffer_text(updated), version
    );
    d_buffer_destroy(updated);
    return stored;
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
            bool stored = false;
            if opening {
                stored = lsp_store_document_at(
                    state, document, d_buffer_text(uri),
                    d_buffer_text(source), version
                );
            } else if version > prior_version {
                stored = lsp_apply_incremental_change(
                    state, document, d_buffer_text(uri),
                    d_buffer_text(source), version, request
                );
            }
            if !stored {
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

unsafe void lsp_change_workspace_folders(
    ref LspState state,
    text request
) {
    usize length = text.byte_length(request);
    usize added = native_find(request, "\"added\"");
    usize removed = native_find(request, "\"removed\"");
    if added <= length && (removed > length || added < removed) {
        text suffix = project_slice(request, added, length - added);
        DBuffer uri = d_buffer_create(16384);
        if lsp_json_string(suffix, "uri", uri) {
            state.root_uri.length = 0;
            state.root_uri.ok = true;
            d_put(state.root_uri, d_buffer_text(uri));
        }
        d_buffer_destroy(uri);
    } else if removed <= length {
        text suffix = project_slice(request, removed, length - removed);
        DBuffer uri = d_buffer_create(16384);
        if lsp_json_string(suffix, "uri", uri) &&
            text.equal(d_buffer_text(uri), d_buffer_text(state.root_uri)) {
            state.root_uri.length = 0;
            state.root_uri.ok = true;
        }
        d_buffer_destroy(uri);
    }
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
