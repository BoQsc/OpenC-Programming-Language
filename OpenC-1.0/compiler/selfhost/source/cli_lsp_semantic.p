import system.memory;
import system.text;

struct LspSemanticIndex {
    PackedBuffer symbols;
    ptr byte symbol_data;
    ptr byte detail_data;
}

struct LspIdentifierResult {
    bool found;
    TextSpan identifier;
}

struct LspRequestIdentifierResult {
    bool found;
    usize document;
    TextSpan identifier;
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
