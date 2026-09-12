import system.file;
import system.io;
import system.memory;
import system.text;

external(c, "ocb_lsp_read_frame") status lsp_read_frame(out text request);

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
