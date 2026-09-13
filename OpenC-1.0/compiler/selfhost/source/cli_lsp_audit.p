import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;
struct CliLspAuditCounts {
    usize total;
    usize passed;
    usize primary_frames;
    usize semantic_frames;
}
struct CliLspDecode {
    bool valid;
    text body;
    usize frames;
}
unsafe void cli_lsp_audit_put_frame(ref DBuffer transcript, text message) {
    d_put(transcript, "Content-Length: ");
    d_put_usize(transcript, text.byte_length(message));
    d_put(transcript, "\r\n\r\n");
    d_put(transcript, message);
}
unsafe DBuffer cli_lsp_audit_primary_transcript() {
    DBuffer transcript = d_buffer_create(65536);
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"i32 main( {\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"options\":{\"tabSize\":4,\"insertSpaces\":true}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\",\"version\":2},\"contentChanges\":[{\"text\":\"i32 main(){return 0;}\"}]}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"options\":{\"tabSize\":4,\"insertSpaces\":true}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"options\":{}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"openc/notImplemented\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"shutdown\",\"params\":null}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}");
    return transcript;
}
unsafe DBuffer cli_lsp_audit_semantic_transcript() {
    DBuffer transcript = d_buffer_create(65536);
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"rootUri\":\"file:///workspace\",\"capabilities\":{}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/types.p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"struct Point {\\n    i32 x;\\n}\\n\\nconst i32 origin = 0;\\n\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\",\"languageId\":\"openc\",\"version\":2,\"text\":\"i32 area(Point point) {\\n    return point.x;\\n}\\n\\ni32 main() {\\n    Point point;\\n    return area(point);\\n}\\n\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///vendor/foreign.p\",\"languageId\":\"openc\",\"version\":3,\"text\":\"struct Foreign {\\n    i32 value;\\n}\\n\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/documentSymbol\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/types.p\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/documentSymbol\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":5}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"textDocument/references\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10},\"context\":{\"includeDeclaration\":true}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":6,\"character\":11}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"textDocument/prepareRename\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"textDocument/rename\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10},\"newName\":\"Vertex\"}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"textDocument/rename\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10},\"newName\":\"struct\"}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"textDocument/rename\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10},\"newName\":\"area\"}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/types.p\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":10}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":13,\"method\":\"shutdown\",\"params\":null}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}");
    return transcript;
}
unsafe DBuffer cli_lsp_audit_preinitialize_transcript() {
    DBuffer transcript = d_buffer_create(2048);
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"textDocument/formatting\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}");
    return transcript;
}
unsafe DBuffer cli_lsp_audit_duplicate_transcript() {
    DBuffer transcript = d_buffer_create(4096);
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"initialize\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"shutdown\",\"params\":null}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}");
    return transcript;
}
unsafe CliLspDecode cli_lsp_audit_decode(text stream, usize wanted) {
    CliLspDecode result = CliLspDecode{
        valid = false, body = "", frames = 0
    };
    usize cursor = 0;
    usize length = text.byte_length(stream);
    while cursor < length {
        text prefix = "Content-Length: ";
        usize prefix_length = text.byte_length(prefix);
        if cursor > length || prefix_length > length - cursor || ! span_equals_ascii(stream, cursor, prefix_length, prefix) {
            return result;
        }
        cursor = cursor + prefix_length;
        usize body_length = 0;
        usize digits = 0;
        while cursor < length {
            u8 octet = byte_at_or_zero(stream, cursor);
            if octet < 48 || octet > 57 {
                break;
            }
            if body_length > 1677721 {
                return result;
            }
            body_length = body_length * 10 + cast(usize, octet - 48);
            cursor = cursor + 1;
            digits = digits + 1;
        }
        if digits == 0 || body_length == 0 || body_length > 1048576 || cursor > length || length - cursor < 4 || byte_at_or_zero(stream, cursor) != 13 || byte_at_or_zero(stream, cursor + 1) != 10 || byte_at_or_zero(stream, cursor + 2) != 13 || byte_at_or_zero(stream, cursor + 3) != 10 {
            return result;
        }
        cursor = cursor + 4;
        if cursor > length || body_length > length - cursor {
            return result;
        }
        text current = project_slice(stream, cursor, body_length);
        if byte_at_or_zero(current, 0) != 123 || ! native_contains(current, "\"jsonrpc\":\"2.0\"") {
            return result;
        }
        if result.frames == wanted {
            result.body = current;
        }
        result.frames = result.frames + 1;
        cursor = cursor + body_length;
    }
    result.valid = cursor == length && result.frames != 0 && wanted < result.frames;
    return result;
}
unsafe bool cli_lsp_audit_frame_contains(text stream, usize frame, text expected) {
    CliLspDecode decoded = cli_lsp_audit_decode(stream, frame);
    return decoded.valid && native_contains(decoded.body, expected);
}
unsafe i32 cli_lsp_audit_batch_command(text input_path) {
    text stream;
    status loaded = file.read_text(input_path, out stream);
    if ! loaded.ok {
        io.error("error: native LSP audit batch could not be read\n");
        return 1;
    }
    if text.byte_length(stream) > 65536 {
        io.error("error: native LSP audit batch exceeds 64 KiB\n");
        return 1;
    }
    CliLspDecode complete = cli_lsp_audit_decode(stream, 0);
    if ! complete.valid {
        io.error("error: native LSP audit batch framing is invalid\n");
        return 1;
    }
    LspState state = LspState{
        initialized = false, shutdown_requested = false,
        cancellation_cursor = 0, cancelled0 = 0, cancelled1 = 0,
        cancelled2 = 0, cancelled3 = 0, cancelled4 = 0,
        cancelled5 = 0, cancelled6 = 0, cancelled7 = 0,
        root_uri = d_buffer_create(16384),
        document0 = lsp_document_create(), document1 = lsp_document_create(),
        document2 = lsp_document_create(), document3 = lsp_document_create(),
        document4 = lsp_document_create(), document5 = lsp_document_create(),
        document6 = lsp_document_create(), document7 = lsp_document_create()
    };
    usize frame = 0;
    while frame < complete.frames {
        CliLspDecode decoded = cli_lsp_audit_decode(stream, frame);
        if ! decoded.valid {
            lsp_state_destroy(state);
            return 1;
        }
        i32 action = lsp_handle_message(state, decoded.body);
        if action != - 2 {
            lsp_state_destroy(state);
            return action;
        }
        frame = frame + 1;
    }
    lsp_state_destroy(state);
    return 1;
}
unsafe void cli_lsp_audit_batch_process(ref DBuffer command, text compiler, text input_path) {
    native_put_quoted(command, compiler);
    d_put(command, " --lsp-audit-batch ");
    native_put_quoted(command, input_path);
}
unsafe void cli_lsp_audit_case(ref DBuffer cases, ref CliLspAuditCounts counts, text name, bool passed) {
    if counts.total != 0 {
        d_put(cases, ",\n");
    }
    d_put(cases, "    {\"name\":");
    cli_json_text(cases, name);
    d_put(cases, ",\"passed\":");
    native_put_bool(cases, passed);
    d_put(cases, "}");
    counts.total = counts.total + 1;
    if passed {
        counts.passed = counts.passed + 1;
    }
}
unsafe void cli_lsp_audit_hash(text value, ref DBuffer output) {
    usize length = text.byte_length(value);
    ptr byte data = memory.alloc(length + 1);
    text.copy_utf8_unchecked(data, value);
    winmd_sha256_hex(data, length, output);
    memory.free(data);
}
unsafe bool cli_lsp_audit_write_report(text output_path, text compiler, ref CliLspAuditCounts counts, ref DBuffer cases, ref DBuffer primary_hash, ref DBuffer semantic_hash, bool passed) {
    DBuffer report = d_buffer_create(65536);
    d_put(report, "{\n  \"schema\": \"openc.native_lsp_audit.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"compiler\": ");
    cli_json_text(report, compiler);
    d_put(report, ",\n  \"transport\": \"stdio-content-length\",\n");
    d_put(report, "  \"limits\": {\"input_bytes\":65536,\"frame_bytes\":1048576,\"captured_output_bytes\":4194304,\"process_memory_bytes\":268435456,\"working_set_bytes\":67108864},\n");
    d_put(report, "  \"observations\": {\"primary_frames\":");
    d_put_usize(report, counts.primary_frames);
    d_put(report, ",\"semantic_frames\":");
    d_put_usize(report, counts.semantic_frames);
    d_put(report, ",\"primary_sha256\":");
    cli_json_text(report, d_buffer_text(primary_hash));
    d_put(report, ",\"semantic_sha256\":");
    cli_json_text(report, d_buffer_text(semantic_hash));
    d_put(report, "},\n  \"cases\": [\n");
    d_put(report, d_buffer_text(cases));
    d_put(report, "\n  ],\n  \"total\": ");
    d_put_usize(report, counts.total);
    d_put(report, ",\n  \"passed\": ");
    d_put_usize(report, counts.passed);
    d_put(report, ",\n  \"failed\": ");
    d_put_usize(report, counts.total - counts.passed);
    d_put(report, ",\n  \"python_invoked\": false,\n");
    d_put(report, "  \"d_invoked\": false,\n");
    d_put(report, "  \"c_compiler_invoked\": false,\n");
    d_put(report, "  \"status\": \"");
    if passed {
        d_put(report, "PASS");
    }
    else {
        d_put(report, "FAIL");
    }
    d_put(report, "\"\n}\n");
    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    return report_ok && written.ok;
}
