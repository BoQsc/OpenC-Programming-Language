import system.file;
import system.io;
import system.memory;
import system.text;

unsafe i32 lsp_handle_message(
    ref LspState state,
    text request
) {
    DBuffer method = d_buffer_create(256);
    bool has_method = lsp_json_string(request, "method", method);
    usize id_result = lsp_json_field_value(request, "id");
    bool has_id = id_result != 0;
    TextSpan id = TextSpan{ start = 0, length = 0 };
    if has_id {
        id = TextSpan{
            start = lsp_json_span_start(id_result),
            length = lsp_json_span_length(id_result)
        };
    }
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
    if name == "$/cancelRequest" {
        lsp_cancel_request(state, lsp_json_usize(request, "id", 0));
        d_buffer_destroy(method);
        return -2;
    }
    if has_id && lsp_take_cancelled_request(
        state, lsp_json_usize(request, "id", 0)
    ) {
        lsp_respond_error(request, id, -32800, "request cancelled");
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
    } else if name == "workspace/didChangeWorkspaceFolders" {
        lsp_change_workspace_folders(state, request);
    } else if name == "workspace/didChangeConfiguration" {
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
        cancellation_cursor = 0,
        cancelled0 = 0,
        cancelled1 = 0,
        cancelled2 = 0,
        cancelled3 = 0,
        cancelled4 = 0,
        cancelled5 = 0,
        cancelled6 = 0,
        cancelled7 = 0,
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
        status read = lsp_read_frame(out request);
        if !read.ok {
            io.error(
                "error[OPENC-LSP-STDIO-READ]: standard-input frame read failed\n"
            );
            lsp_state_destroy(state);
            return 1;
        }
        if text.byte_length(request) == 0 {
            lsp_state_destroy(state);
            return 0;
        }
        i32 action = lsp_handle_message(state, request);
        if action != -2 {
            lsp_state_destroy(state);
            return action;
        }
    }
    return 0;
}
