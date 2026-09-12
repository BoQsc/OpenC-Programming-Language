import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

unsafe i32 cli_lsp_audit_command() {
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        }
        else {
            io.error("usage: openc lsp-audit --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(output_path) == 0 {
        io.error("usage: openc lsp-audit --output=REPORT.json\n");
        return 64;
    }
    text compiler = cli_self_executable();
    DBuffer cases = d_buffer_create(65536);
    CliLspAuditCounts counts = CliLspAuditCounts{
        total = 0, passed = 0, primary_frames = 0, semantic_frames = 0
    };
    DBuffer primary_input = cli_lsp_audit_primary_transcript();
    DBuffer primary_path_buffer = d_buffer_create(text.byte_length(output_path) + 32);
    d_put(primary_path_buffer, output_path);
    d_put(primary_path_buffer, ".primary.frames");
    text primary_path = d_buffer_text(primary_path_buffer);
    status primary_written = file.write_text(primary_path, d_buffer_text(primary_input));
    DBuffer lsp_command = d_buffer_create(text.byte_length(compiler) + text.byte_length(primary_path) + 64);
    cli_lsp_audit_batch_process(lsp_command, compiler, primary_path);
    i32 primary_exit;
    text primary_output;
    status primary_ran = process.run(d_buffer_text(lsp_command), out primary_exit, out primary_output);
    i32 primary_exit_value = 0;
    text primary_output_value = "";
    if primary_ran.ok {
        primary_exit_value = primary_exit;
        primary_output_value = primary_output;
    }
    CliLspDecode primary_decoded = cli_lsp_audit_decode(primary_output_value, 0);
    counts.primary_frames = primary_decoded.frames;
    bool primary_frames_ok = primary_written.ok && primary_ran.ok && primary_decoded.valid && primary_decoded.frames == 10;
    cli_lsp_audit_case(cases, counts, "primary_process_launched", primary_ran.ok);
    cli_lsp_audit_case(cases, counts, "primary_shutdown_exit_zero", primary_ran.ok && primary_exit_value == 0);
    cli_lsp_audit_case(cases, counts, "primary_frame_count", primary_frames_ok);
    cli_lsp_audit_case(cases, counts, "primary_jsonrpc_framing", primary_frames_ok);
    cli_lsp_audit_case(cases, counts, "initialize_response", cli_lsp_audit_frame_contains(primary_output_value, 0, "\"id\":1,\"result\":"));
    cli_lsp_audit_case(cases, counts, "utf8_position_encoding", cli_lsp_audit_frame_contains(primary_output_value, 0, "\"positionEncoding\":\"utf-8\""));
    cli_lsp_audit_case(cases, counts, "full_document_sync", cli_lsp_audit_frame_contains(primary_output_value, 0, "\"textDocumentSync\":{\"openClose\":true,\"change\":1}"));
    cli_lsp_audit_case(cases, counts, "formatting_capability", cli_lsp_audit_frame_contains(primary_output_value, 0, "\"documentFormattingProvider\":true"));
    cli_lsp_audit_case(cases, counts, "server_identity", cli_lsp_audit_frame_contains(primary_output_value, 0, "\"serverInfo\":{\"name\":\"openc-lsp\""));
    cli_lsp_audit_case(cases, counts, "did_open_diagnostics", cli_lsp_audit_frame_contains(primary_output_value, 1, "\"method\":\"textDocument/publishDiagnostics\"") && cli_lsp_audit_frame_contains(primary_output_value, 1, "\"version\":1"));
    cli_lsp_audit_case(cases, counts, "stable_diagnostic_rule", cli_lsp_audit_frame_contains(primary_output_value, 1, "\"code\":\"OPENC-SYNTAX-"));
    cli_lsp_audit_case(cases, counts, "stable_diagnostic_shape", cli_lsp_audit_frame_contains(primary_output_value, 1, "\"severity\":1") && cli_lsp_audit_frame_contains(primary_output_value, 1, "\"source\":\"openc\"") && cli_lsp_audit_frame_contains(primary_output_value, 1, "\"data\":{\"byteStart\":"));
    cli_lsp_audit_case(cases, counts, "invalid_document_not_formatted", cli_lsp_audit_frame_contains(primary_output_value, 2, "\"id\":2,\"result\":[]"));
    cli_lsp_audit_case(cases, counts, "did_change_clears_diagnostics", cli_lsp_audit_frame_contains(primary_output_value, 3, "\"version\":2,\"diagnostics\":[]"));
    cli_lsp_audit_case(cases, counts, "canonical_formatter_edit", cli_lsp_audit_frame_contains(primary_output_value, 4, "\"id\":3,\"result\":[") && cli_lsp_audit_frame_contains(primary_output_value, 4, "\"newText\":\"i32 main(){\\n    return 0;\\n}\\n\""));
    cli_lsp_audit_case(cases, counts, "did_close_clears_diagnostics", cli_lsp_audit_frame_contains(primary_output_value, 5, "\"diagnostics\":[]"));
    cli_lsp_audit_case(cases, counts, "closed_document_error", cli_lsp_audit_frame_contains(primary_output_value, 6, "\"code\":-32602") && cli_lsp_audit_frame_contains(primary_output_value, 6, "\"id\":4"));
    cli_lsp_audit_case(cases, counts, "unknown_method_error", cli_lsp_audit_frame_contains(primary_output_value, 7, "\"code\":-32601") && cli_lsp_audit_frame_contains(primary_output_value, 7, "\"id\":5"));
    cli_lsp_audit_case(cases, counts, "shutdown_response", cli_lsp_audit_frame_contains(primary_output_value, 8, "\"id\":6,\"result\":null"));
    cli_lsp_audit_case(cases, counts, "request_after_shutdown_error", cli_lsp_audit_frame_contains(primary_output_value, 9, "\"code\":-32600") && cli_lsp_audit_frame_contains(primary_output_value, 9, "\"id\":7"));
    DBuffer primary_hash = d_buffer_create(65);
    if primary_ran.ok {
        cli_lsp_audit_hash(primary_output_value, primary_hash);
    }
    DBuffer primary_input_again = cli_lsp_audit_primary_transcript();
    primary_written = file.write_text(primary_path, d_buffer_text(primary_input_again));
    i32 primary_exit_again;
    text primary_output_again;
    status primary_ran_again = process.run(d_buffer_text(lsp_command), out primary_exit_again, out primary_output_again);
    i32 primary_exit_again_value = 0;
    text primary_output_again_value = "";
    if primary_ran_again.ok {
        primary_exit_again_value = primary_exit_again;
        primary_output_again_value = primary_output_again;
    }
    DBuffer primary_hash_again = d_buffer_create(65);
    if primary_ran_again.ok {
        cli_lsp_audit_hash(primary_output_again_value, primary_hash_again);
    }
    cli_lsp_audit_case(cases, counts, "primary_repeat_launched", primary_written.ok && primary_ran_again.ok && primary_exit_again_value == 0);
    cli_lsp_audit_case(cases, counts, "primary_transcript_deterministic", primary_written.ok && primary_ran.ok && primary_ran_again.ok && d_buffer_text(primary_hash) == d_buffer_text(primary_hash_again));
    DBuffer preinitialize_input = cli_lsp_audit_preinitialize_transcript();
    DBuffer preinitialize_path_buffer = d_buffer_create(text.byte_length(output_path) + 32);
    d_put(preinitialize_path_buffer, output_path);
    d_put(preinitialize_path_buffer, ".preinitialize.frames");
    text preinitialize_path = d_buffer_text(preinitialize_path_buffer);
    status preinitialize_written = file.write_text(preinitialize_path, d_buffer_text(preinitialize_input));
    d_buffer_destroy(lsp_command);
    lsp_command = d_buffer_create(text.byte_length(compiler) + text.byte_length(preinitialize_path) + 64);
    cli_lsp_audit_batch_process(lsp_command, compiler, preinitialize_path);
    i32 preinitialize_exit;
    text preinitialize_output;
    status preinitialize_ran = process.run(d_buffer_text(lsp_command), out preinitialize_exit, out preinitialize_output);
    i32 preinitialize_exit_value = 0;
    text preinitialize_output_value = "";
    if preinitialize_ran.ok {
        preinitialize_exit_value = preinitialize_exit;
        preinitialize_output_value = preinitialize_output;
    }
    cli_lsp_audit_case(cases, counts, "preinitialize_process_launched", preinitialize_written.ok && preinitialize_ran.ok);
    cli_lsp_audit_case(cases, counts, "request_before_initialize_error", cli_lsp_audit_frame_contains(preinitialize_output_value, 0, "\"code\":-32002"));
    cli_lsp_audit_case(cases, counts, "exit_without_shutdown_fails", preinitialize_ran.ok && preinitialize_exit_value == 1);
    DBuffer duplicate_input = cli_lsp_audit_duplicate_transcript();
    DBuffer duplicate_path_buffer = d_buffer_create(text.byte_length(output_path) + 32);
    d_put(duplicate_path_buffer, output_path);
    d_put(duplicate_path_buffer, ".duplicate.frames");
    text duplicate_path = d_buffer_text(duplicate_path_buffer);
    status duplicate_written = file.write_text(duplicate_path, d_buffer_text(duplicate_input));
    d_buffer_destroy(lsp_command);
    lsp_command = d_buffer_create(text.byte_length(compiler) + text.byte_length(duplicate_path) + 64);
    cli_lsp_audit_batch_process(lsp_command, compiler, duplicate_path);
    i32 duplicate_exit;
    text duplicate_output;
    status duplicate_ran = process.run(d_buffer_text(lsp_command), out duplicate_exit, out duplicate_output);
    i32 duplicate_exit_value = 0;
    text duplicate_output_value = "";
    if duplicate_ran.ok {
        duplicate_exit_value = duplicate_exit;
        duplicate_output_value = duplicate_output;
    }
    cli_lsp_audit_case(cases, counts, "duplicate_process_clean_exit", duplicate_written.ok && duplicate_ran.ok && duplicate_exit_value == 0);
    cli_lsp_audit_case(cases, counts, "duplicate_initialize_error", cli_lsp_audit_frame_contains(duplicate_output_value, 1, "\"id\":2,\"error\":{\"code\":-32600"));
    cli_lsp_audit_case(cases, counts, "duplicate_session_shutdown", cli_lsp_audit_frame_contains(duplicate_output_value, 2, "\"id\":3,\"result\":null"));
    DBuffer semantic_input = cli_lsp_audit_semantic_transcript();
    DBuffer semantic_path_buffer = d_buffer_create(text.byte_length(output_path) + 32);
    d_put(semantic_path_buffer, output_path);
    d_put(semantic_path_buffer, ".semantic.frames");
    text semantic_path = d_buffer_text(semantic_path_buffer);
    status semantic_written = file.write_text(semantic_path, d_buffer_text(semantic_input));
    d_buffer_destroy(lsp_command);
    lsp_command = d_buffer_create(text.byte_length(compiler) + text.byte_length(semantic_path) + 64);
    cli_lsp_audit_batch_process(lsp_command, compiler, semantic_path);
    i32 semantic_exit;
    text semantic_output;
    status semantic_ran = process.run(d_buffer_text(lsp_command), out semantic_exit, out semantic_output);
    i32 semantic_exit_value = 0;
    text semantic_output_value = "";
    if semantic_ran.ok {
        semantic_exit_value = semantic_exit;
        semantic_output_value = semantic_output;
    }
    CliLspDecode semantic_decoded = cli_lsp_audit_decode(semantic_output_value, 0);
    counts.semantic_frames = semantic_decoded.frames;
    bool semantic_frames_ok = semantic_written.ok && semantic_ran.ok && semantic_decoded.valid && semantic_decoded.frames == 17;
    cli_lsp_audit_case(cases, counts, "semantic_process_clean_exit", semantic_ran.ok && semantic_exit_value == 0);
    cli_lsp_audit_case(cases, counts, "semantic_jsonrpc_framing", semantic_frames_ok);
    cli_lsp_audit_case(cases, counts, "semantic_capabilities", cli_lsp_audit_frame_contains(semantic_output_value, 0, "\"documentSymbolProvider\":true") && cli_lsp_audit_frame_contains(semantic_output_value, 0, "\"hoverProvider\":true") && cli_lsp_audit_frame_contains(semantic_output_value, 0, "\"definitionProvider\":true") && cli_lsp_audit_frame_contains(semantic_output_value, 0, "\"referencesProvider\":true"));
    cli_lsp_audit_case(cases, counts, "completion_and_rename_capabilities", cli_lsp_audit_frame_contains(semantic_output_value, 0, "\"completionProvider\":{\"resolveProvider\":false}") && cli_lsp_audit_frame_contains(semantic_output_value, 0, "\"renameProvider\":{\"prepareProvider\":true}"));
    cli_lsp_audit_case(cases, counts, "multi_document_synchronization", cli_lsp_audit_frame_contains(semantic_output_value, 1, "\"diagnostics\":[]") && cli_lsp_audit_frame_contains(semantic_output_value, 2, "\"diagnostics\":[]") && cli_lsp_audit_frame_contains(semantic_output_value, 3, "\"diagnostics\":[]"));
    cli_lsp_audit_case(cases, counts, "document_symbols_and_types", cli_lsp_audit_frame_contains(semantic_output_value, 4, "\"name\":\"Point\",\"detail\":\"struct Point\",\"kind\":23") && cli_lsp_audit_frame_contains(semantic_output_value, 4, "\"name\":\"origin\",\"detail\":\"const origin: i32\",\"kind\":14"));
    cli_lsp_audit_case(cases, counts, "function_symbols_and_hover", cli_lsp_audit_frame_contains(semantic_output_value, 5, "\"detail\":\"function area: i32\"") && cli_lsp_audit_frame_contains(semantic_output_value, 5, "\"detail\":\"function main: i32\"") && cli_lsp_audit_frame_contains(semantic_output_value, 6, "function area: i32"));
    cli_lsp_audit_case(cases, counts, "cross_document_definition_and_references", cli_lsp_audit_frame_contains(semantic_output_value, 7, "\"uri\":\"file:///workspace/types.p\"") && cli_lsp_audit_frame_contains(semantic_output_value, 8, "file:///workspace/main.p") && cli_lsp_audit_frame_contains(semantic_output_value, 8, "file:///workspace/types.p"));
    cli_lsp_audit_case(cases, counts, "deterministic_completion_root_boundary", cli_lsp_audit_frame_contains(semantic_output_value, 9, "\"label\":\"Point\"") && cli_lsp_audit_frame_contains(semantic_output_value, 9, "\"label\":\"origin\"") && ! cli_lsp_audit_frame_contains(semantic_output_value, 9, "Foreign"));
    cli_lsp_audit_case(cases, counts, "prepare_rename", cli_lsp_audit_frame_contains(semantic_output_value, 10, "\"placeholder\":\"Point\""));
    cli_lsp_audit_case(cases, counts, "project_safe_rename_order", cli_lsp_audit_frame_contains(semantic_output_value, 11, "\"newText\":\"Vertex\"") && cli_lsp_audit_frame_contains(semantic_output_value, 11, "file:///workspace/main.p") && cli_lsp_audit_frame_contains(semantic_output_value, 11, "file:///workspace/types.p"));
    cli_lsp_audit_case(cases, counts, "unsafe_and_collision_rename_rejected", cli_lsp_audit_frame_contains(semantic_output_value, 12, "\"code\":-32602") && cli_lsp_audit_frame_contains(semantic_output_value, 13, "\"code\":-32602"));
    cli_lsp_audit_case(cases, counts, "close_removes_symbols_and_shutdown", cli_lsp_audit_frame_contains(semantic_output_value, 14, "\"diagnostics\":[]") && cli_lsp_audit_frame_contains(semantic_output_value, 15, "\"id\":12,\"result\":[]") && cli_lsp_audit_frame_contains(semantic_output_value, 16, "\"id\":13,\"result\":null"));
    DBuffer semantic_hash = d_buffer_create(65);
    if semantic_ran.ok {
        cli_lsp_audit_hash(semantic_output_value, semantic_hash);
    }
    DBuffer semantic_input_again = cli_lsp_audit_semantic_transcript();
    semantic_written = file.write_text(semantic_path, d_buffer_text(semantic_input_again));
    i32 semantic_exit_again;
    text semantic_output_again;
    status semantic_ran_again = process.run(d_buffer_text(lsp_command), out semantic_exit_again, out semantic_output_again);
    i32 semantic_exit_again_value = 0;
    text semantic_output_again_value = "";
    if semantic_ran_again.ok {
        semantic_exit_again_value = semantic_exit_again;
        semantic_output_again_value = semantic_output_again;
    }
    DBuffer semantic_hash_again = d_buffer_create(65);
    if semantic_ran_again.ok {
        cli_lsp_audit_hash(semantic_output_again_value, semantic_hash_again);
    }
    cli_lsp_audit_case(cases, counts, "semantic_transcript_deterministic", semantic_written.ok && semantic_ran_again.ok && semantic_exit_again_value == 0 && d_buffer_text(semantic_hash) == d_buffer_text(semantic_hash_again));
    bool passed = counts.total == 42 && counts.passed == counts.total && primary_hash.ok && semantic_hash.ok;
    bool written = cli_lsp_audit_write_report(output_path, compiler, counts, cases, primary_hash, semantic_hash, passed);
    d_buffer_destroy(primary_input);
    d_buffer_destroy(primary_input_again);
    d_buffer_destroy(preinitialize_input);
    d_buffer_destroy(duplicate_input);
    d_buffer_destroy(semantic_input);
    d_buffer_destroy(semantic_input_again);
    d_buffer_destroy(primary_hash);
    d_buffer_destroy(primary_hash_again);
    d_buffer_destroy(semantic_hash);
    d_buffer_destroy(semantic_hash_again);
    d_buffer_destroy(lsp_command);
    d_buffer_destroy(primary_path_buffer);
    d_buffer_destroy(preinitialize_path_buffer);
    d_buffer_destroy(duplicate_path_buffer);
    d_buffer_destroy(semantic_path_buffer);
    d_buffer_destroy(cases);
    if ! written {
        io.error("error: native LSP audit report could not be written\n");
        return 1;
    }
    io.print("OpenC native LSP audit: ");
    if passed {
        io.print("PASS");
    }
    else {
        io.print("FAIL");
    }
    io.print(" (");
    io.print(counts.passed);
    io.print("/");
    io.print(counts.total);
    io.println(")");
    if passed {
        return 0;
    }
    return 1;
}
