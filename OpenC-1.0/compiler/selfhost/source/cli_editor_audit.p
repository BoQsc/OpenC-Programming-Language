import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe DBuffer cli_editor_audit_resilience_transcript() {
    DBuffer transcript = d_buffer_create(65536);
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"rootUri\":\"file:///workspace\",\"capabilities\":{\"workspace\":{\"workspaceFolders\":true}}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"i32 main(){return 0;}\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\",\"version\":2},\"contentChanges\":[{\"range\":{\"start\":{\"line\":0,\"character\":18},\"end\":{\"line\":0,\"character\":19}},\"rangeLength\":1,\"text\":\"1\"}]}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\",\"version\":1},\"contentChanges\":[{\"text\":\"i32 main( {\"}]}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"options\":{\"tabSize\":4,\"insertSpaces\":true}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"$/cancelRequest\",\"params\":{\"id\":77}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":77,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/main.p\"},\"position\":{\"line\":0,\"character\":5}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"workspace/didChangeWorkspaceFolders\",\"params\":{\"event\":{\"added\":[{\"uri\":\"file:///new\",\"name\":\"new\"}],\"removed\":[{\"uri\":\"file:///workspace\",\"name\":\"workspace\"}]}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///new/types.p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"struct NewType { i32 value; }\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/old.p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"struct OldType { i32 value; }\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///new/app.p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"i32 main(){return 0;}\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"file:///new/app.p\"},\"position\":{\"line\":0,\"character\":5}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didClose\",\"params\":{\"textDocument\":{\"uri\":\"file:///new/app.p\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///new/app.p\",\"languageId\":\"openc\",\"version\":2,\"text\":\"i32 main(){return 2;}\"}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"shutdown\",\"params\":null}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}");
    return transcript;
}

unsafe DBuffer cli_editor_audit_capacity_transcript() {
    DBuffer transcript = d_buffer_create(65536);
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"rootUri\":\"file:///capacity\"}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}");
    usize index = 0;
    while index < 9 {
        DBuffer message = d_buffer_create(1024);
        d_put(message, "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///capacity/document");
        d_put_usize(message, index);
        d_put(message, ".p\",\"languageId\":\"openc\",\"version\":1,\"text\":\"i32 main(){return 0;}\"}}}");
        cli_lsp_audit_put_frame(transcript, d_buffer_text(message));
        d_buffer_destroy(message);
        index = index + 1;
    }
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":90,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///capacity/document8.p\"},\"options\":{}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":91,\"method\":\"textDocument/formatting\",\"params\":{\"textDocument\":{\"uri\":\"file:///capacity/document0.p\"},\"options\":{}}}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"id\":92,\"method\":\"shutdown\",\"params\":null}");
    cli_lsp_audit_put_frame(transcript, "{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}");
    return transcript;
}

struct CliEditorAuditRun {
    bool launched;
    i32 exit_code;
    text output;
}

unsafe CliEditorAuditRun cli_editor_audit_run(
    text compiler,
    text frame_path,
    ref DBuffer transcript
) {
    status written = file.write_text(frame_path, d_buffer_text(transcript));
    if !written.ok {
        return CliEditorAuditRun{
            launched = false, exit_code = 1, output = ""
        };
    }
    DBuffer command = d_buffer_create(
        text.byte_length(compiler) + text.byte_length(frame_path) + 64
    );
    cli_lsp_audit_batch_process(command, compiler, frame_path);
    i32 exit_code;
    text output;
    status ran = process.run(
        d_buffer_text(command), out exit_code, out output
    );
    d_buffer_destroy(command);
    if !ran.ok {
        return CliEditorAuditRun{
            launched = false, exit_code = 1, output = ""
        };
    }
    return CliEditorAuditRun{
        launched = true, exit_code = exit_code, output = output
    };
}

unsafe bool cli_editor_audit_write_report(
    text output_path,
    text compiler,
    ref CliLspAuditCounts counts,
    ref DBuffer cases,
    text resilience_hash,
    text capacity_hash,
    bool passed
) {
    DBuffer report = d_buffer_create(131072);
    d_put(report, "{\n  \"schema\": \"openc.native_editor_audit.v1\",\n");
    d_put(report, "  \"compiler\": "); cli_json_text(report, compiler);
    d_put(report, ",\n  \"client\": \"editors/vscode\",\n");
    d_put(report, "  \"limits\": {\"message_bytes\":4194304,\"header_bytes\":8192,\"pending_requests\":128,\"documents\":8,\"cancelled_requests\":8,\"restart_attempts\":3},\n");
    d_put(report, "  \"observations\": {\"resilience_frames\":");
    d_put_usize(report, counts.primary_frames);
    d_put(report, ",\"capacity_frames\":");
    d_put_usize(report, counts.semantic_frames);
    d_put(report, ",\"resilience_sha256\":"); cli_json_text(report, resilience_hash);
    d_put(report, ",\"capacity_sha256\":"); cli_json_text(report, capacity_hash);
    d_put(report, "},\n  \"cases\": [\n");
    d_put(report, d_buffer_text(cases));
    d_put(report, "\n  ],\n  \"total\": "); d_put_usize(report, counts.total);
    d_put(report, ",\n  \"passed\": "); d_put_usize(report, counts.passed);
    d_put(report, ",\n  \"failed\": "); d_put_usize(report, counts.total - counts.passed);
    d_put(report, ",\n  \"python_invoked\": false,\n  \"d_invoked\": false,\n");
    d_put(report, "  \"c_compiler_invoked\": false,\n  \"node_invoked\": false,\n");
    d_put(report, "  \"network_required\": false,\n  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");
    bool ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    return ok && written.ok;
}

unsafe i32 cli_editor_audit_command() {
    text root = "";
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else {
            io.error("usage: openc editor-audit --root=ROOT --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(root) == 0 || text.byte_length(output_path) == 0 {
        io.error("usage: openc editor-audit --root=ROOT --output=REPORT.json\n");
        return 64;
    }
    text package_read_source;
    text extension_read_source;
    text readme_read_source;
    text runtime_read_source;
    status package_read = file.read_text(
        path.join(root, "editors/vscode/package.json"), out package_read_source
    );
    status extension_read = file.read_text(
        path.join(root, "editors/vscode/extension.js"), out extension_read_source
    );
    status readme_read = file.read_text(
        path.join(root, "editors/vscode/README.md"), out readme_read_source
    );
    status runtime_read = file.read_text(path.join(
        root, "compiler/selfhost/source/backend_native_runtime_lsp.p"
    ), out runtime_read_source);
    text package_source = "";
    text extension_source = "";
    text readme_source = "";
    text runtime_source = "";
    if package_read.ok { package_source = package_read_source; }
    if extension_read.ok { extension_source = extension_read_source; }
    if readme_read.ok { readme_source = readme_read_source; }
    if runtime_read.ok { runtime_source = runtime_read_source; }
    DBuffer cases = d_buffer_create(131072);
    CliLspAuditCounts counts = CliLspAuditCounts{
        total = 0, passed = 0, primary_frames = 0, semantic_frames = 0
    };
    cli_lsp_audit_case(cases, counts, "client_manifest_readable", package_read.ok);
    cli_lsp_audit_case(cases, counts, "client_source_readable", extension_read.ok);
    cli_lsp_audit_case(cases, counts, "client_documentation_readable", readme_read.ok);
    cli_lsp_audit_case(cases, counts, "openc_p_language_registration", package_read.ok && native_contains(package_source, "\"extensions\": [\".p\"]"));
    cli_lsp_audit_case(cases, counts, "zero_bsd_code_license", package_read.ok && native_contains(package_source, "\"license\": \"0BSD\""));
    cli_lsp_audit_case(cases, counts, "dependency_free_client", package_read.ok && !native_contains(package_source, "\"dependencies\"") && !native_contains(package_source, "\"devDependencies\""));
    cli_lsp_audit_case(cases, counts, "packaged_native_server_launch", extension_read.ok && native_contains(extension_source, "['lsp', '--stdio']") && native_contains(extension_source, "'..', '..', 'openc.exe'"));
    cli_lsp_audit_case(cases, counts, "content_length_framing", extension_read.ok && native_contains(extension_source, "Content-Length: ${body.length}") && native_contains(extension_source, "indexOf('\\r\\n\\r\\n')"));
    cli_lsp_audit_case(cases, counts, "client_message_limit", extension_read.ok && native_contains(extension_source, "MAX_MESSAGE_BYTES = 4 * 1024 * 1024"));
    cli_lsp_audit_case(cases, counts, "client_header_limit", extension_read.ok && native_contains(extension_source, "MAX_HEADER_BYTES = 8 * 1024"));
    cli_lsp_audit_case(cases, counts, "client_pending_request_limit", extension_read.ok && native_contains(extension_source, "MAX_PENDING_REQUESTS = 128"));
    cli_lsp_audit_case(cases, counts, "client_document_limit", extension_read.ok && native_contains(extension_source, "MAX_DOCUMENTS = 8"));
    cli_lsp_audit_case(cases, counts, "client_restart_limit", extension_read.ok && native_contains(extension_source, "MAX_RESTARTS = 3"));
    cli_lsp_audit_case(cases, counts, "monotonic_document_versions", extension_read.ok && native_contains(extension_source, "event.document.version <= state.version"));
    cli_lsp_audit_case(cases, counts, "incremental_range_sync", extension_read.ok && native_contains(extension_source, "rangeLength: change.rangeLength") && native_contains(extension_source, "textDocument/didChange"));
    cli_lsp_audit_case(cases, counts, "cancellation_propagation", extension_read.ok && native_contains(extension_source, "$/cancelRequest"));
    cli_lsp_audit_case(cases, counts, "workspace_folder_lifecycle", extension_read.ok && native_contains(extension_source, "workspace/didChangeWorkspaceFolders") && native_contains(extension_source, "onDidChangeWorkspaceFolders"));
    cli_lsp_audit_case(cases, counts, "bounded_restart_and_resynchronization", extension_read.ok && native_contains(extension_source, "restartCount >= MAX_RESTARTS") && native_contains(extension_source, "this.resynchronize()"));
    cli_lsp_audit_case(cases, counts, "documented_resource_limits", readme_read.ok && native_contains(readme_source, "4 MiB per protocol message") && native_contains(readme_source, "3 restart attempts"));
    cli_lsp_audit_case(cases, counts, "server_message_allocation_guard", runtime_read.ok && native_contains(runtime_source, "cast(u64, 4194304)") && native_contains(runtime_source, "cast(u64, 8192)") && !native_contains(runtime_source, "cast(u64, 16777216)"));

    text compiler = cli_self_executable();
    DBuffer resilience = cli_editor_audit_resilience_transcript();
    DBuffer resilience_path = d_buffer_create(text.byte_length(output_path) + 32);
    d_put(resilience_path, output_path); d_put(resilience_path, ".resilience.frames");
    CliEditorAuditRun resilience_run = cli_editor_audit_run(
        compiler, d_buffer_text(resilience_path), resilience
    );
    text resilience_output = resilience_run.output;
    CliLspDecode resilience_decoded = cli_lsp_audit_decode(resilience_output, 0);
    counts.primary_frames = resilience_decoded.frames;
    cli_lsp_audit_case(cases, counts, "resilience_process_clean_exit", resilience_run.launched && resilience_run.exit_code == 0);
    cli_lsp_audit_case(cases, counts, "resilience_frame_count", resilience_run.launched && resilience_decoded.valid && resilience_decoded.frames == 12);
    cli_lsp_audit_case(cases, counts, "incremental_and_workspace_capabilities", cli_lsp_audit_frame_contains(resilience_output, 0, "\"change\":2") && cli_lsp_audit_frame_contains(resilience_output, 0, "\"workspaceFolders\":{\"supported\":true,\"changeNotifications\":true}"));
    cli_lsp_audit_case(cases, counts, "incremental_edit_applied", cli_lsp_audit_frame_contains(resilience_output, 2, "\"version\":2,\"diagnostics\":[]") && cli_lsp_audit_frame_contains(resilience_output, 3, "return 1;"));
    cli_lsp_audit_case(cases, counts, "stale_version_rejected", cli_lsp_audit_frame_contains(resilience_output, 3, "return 1;") && !cli_lsp_audit_frame_contains(resilience_output, 3, "i32 main( {"));
    cli_lsp_audit_case(cases, counts, "cancelled_request_response", cli_lsp_audit_frame_contains(resilience_output, 4, "\"id\":77,\"error\":{\"code\":-32800"));
    cli_lsp_audit_case(cases, counts, "workspace_root_transition", cli_lsp_audit_frame_contains(resilience_output, 8, "\"label\":\"NewType\"") && !cli_lsp_audit_frame_contains(resilience_output, 8, "OldType"));
    cli_lsp_audit_case(cases, counts, "close_reopen_resynchronization", cli_lsp_audit_frame_contains(resilience_output, 9, "\"diagnostics\":[]") && cli_lsp_audit_frame_contains(resilience_output, 10, "\"version\":2,\"diagnostics\":[]"));
    cli_lsp_audit_case(cases, counts, "resilience_shutdown", cli_lsp_audit_frame_contains(resilience_output, 11, "\"id\":4,\"result\":null"));
    DBuffer resilience_hash = d_buffer_create(65);
    if resilience_run.launched { cli_lsp_audit_hash(resilience_output, resilience_hash); }
    CliEditorAuditRun repeat_run = cli_editor_audit_run(
        compiler, d_buffer_text(resilience_path), resilience
    );
    text repeat_output = repeat_run.output;
    DBuffer repeat_hash = d_buffer_create(65);
    if repeat_run.launched { cli_lsp_audit_hash(repeat_output, repeat_hash); }
    cli_lsp_audit_case(cases, counts, "resilience_transcript_deterministic", repeat_run.launched && repeat_run.exit_code == 0 && d_buffer_text(resilience_hash) == d_buffer_text(repeat_hash));

    DBuffer capacity = cli_editor_audit_capacity_transcript();
    DBuffer capacity_path = d_buffer_create(text.byte_length(output_path) + 32);
    d_put(capacity_path, output_path); d_put(capacity_path, ".capacity.frames");
    CliEditorAuditRun capacity_run = cli_editor_audit_run(
        compiler, d_buffer_text(capacity_path), capacity
    );
    text capacity_output = capacity_run.output;
    CliLspDecode capacity_decoded = cli_lsp_audit_decode(capacity_output, 0);
    counts.semantic_frames = capacity_decoded.frames;
    cli_lsp_audit_case(cases, counts, "capacity_process_clean_exit", capacity_run.launched && capacity_run.exit_code == 0);
    cli_lsp_audit_case(cases, counts, "bounded_document_capacity", capacity_decoded.valid && capacity_decoded.frames == 12 && cli_lsp_audit_frame_contains(capacity_output, 9, "\"id\":90,\"error\":{\"code\":-32602") && cli_lsp_audit_frame_contains(capacity_output, 10, "\"id\":91,\"result\":["));
    cli_lsp_audit_case(cases, counts, "capacity_shutdown", cli_lsp_audit_frame_contains(capacity_output, 11, "\"id\":92,\"result\":null"));
    DBuffer capacity_hash = d_buffer_create(65);
    if capacity_run.launched { cli_lsp_audit_hash(capacity_output, capacity_hash); }
    bool passed = counts.total == 33 && counts.passed == counts.total &&
        resilience_hash.ok && capacity_hash.ok;
    bool written = cli_editor_audit_write_report(
        output_path, compiler, counts, cases, d_buffer_text(resilience_hash),
        d_buffer_text(capacity_hash), passed
    );
    d_buffer_destroy(resilience);
    d_buffer_destroy(resilience_path);
    d_buffer_destroy(resilience_hash);
    d_buffer_destroy(repeat_hash);
    d_buffer_destroy(capacity);
    d_buffer_destroy(capacity_path);
    d_buffer_destroy(capacity_hash);
    d_buffer_destroy(cases);
    if !written {
        io.error("error: native editor audit report could not be written\n");
        return 1;
    }
    io.print("OpenC native editor audit: ");
    if passed { io.print("PASS"); } else { io.print("FAIL"); }
    io.print(" ("); io.print(counts.passed); io.print("/");
    io.print(counts.total); io.println(")");
    if passed { return 0; }
    return 1;
}
