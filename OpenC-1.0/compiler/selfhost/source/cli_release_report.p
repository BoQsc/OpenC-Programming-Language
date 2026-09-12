import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool cli_release_write_report(
    text output_path,
    ref CliReleaseResult result
) {
    DBuffer report = d_buffer_create(16384);
    d_put(report, "{\n  \"schema\": \"openc.native_release_workflow.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"status\": \"");
    if result.passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\",\n  \"counts\": {\"plan_entries\":");
    d_put_usize(report, result.plan_entries);
    d_put(report, ",\"standalone_entries\":");
    d_put_usize(report, result.standalone_entries);
    d_put(report, ",\"source_entries\":");
    d_put_usize(report, result.source_entries);
    d_put(report, ",\"manifest_entries\":");
    d_put_usize(report, result.manifest_entries);
    d_put(report, "},\n  \"bytes\": {\"standalone_inputs\":");
    d_put_usize(report, result.standalone_bytes);
    d_put(report, ",\"source_inputs\":");
    d_put_usize(report, result.source_bytes);
    d_put(report, ",\"peak_entry_buffer\":");
    d_put_usize(report, result.peak_entry_bytes);
    d_put(report, "},\n  \"hashes\": {\"compiler\":");
    cli_json_text(report, result.compiler_hash);
    d_put(report, ",\"stage2\":"); cli_json_text(report, result.stage2_hash);
    d_put(report, ",\"stage3\":"); cli_json_text(report, result.stage3_hash);
    d_put(report, "},\n  \"elapsed_milliseconds\": {\"stage2\":");
    d_put_usize(report, result.stage2_elapsed);
    d_put(report, ",\"stage3\":"); d_put_usize(report, result.stage3_elapsed);
    d_put(report, ",\"daily_workflow\":"); d_put_usize(report, result.workflow_elapsed);
    d_put(report, ",\"conformance\":"); d_put_usize(report, result.conformance_elapsed);
    d_put(report, "},\n  \"checks\": {\"standalone_archives_byte_equal\":");
    native_put_bool(report, result.standalone_equal);
    d_put(report, ",\"source_archives_byte_equal\":"); native_put_bool(report, result.source_equal);
    d_put(report, ",\"zip_structure_crc_and_paths\":"); native_put_bool(report, result.archives_verified);
    d_put(report, ",\"standalone_manifest\":"); native_put_bool(report, result.manifest_verified);
    d_put(report, ",\"relocated_stage2_stage3_exact\":"); native_put_bool(report, result.stage_closure);
    d_put(report, ",\"relocated_daily_workflow\":"); native_put_bool(report, result.daily_workflow);
    d_put(report, ",\"relocated_conformance_278\":"); native_put_bool(report, result.conformance);
    d_put(report, ",\"historical_python_d_c_tinycc_absent\":"); native_put_bool(report, result.historical_kit_absent);
    d_put(report, "},\n  \"limits\": {\"entry_buffer_bytes\":16777216,\"archive_verify_bytes\":67108864,\"child_private_bytes\":268435456,\"child_working_set_bytes\":67108864,\"captured_output_bytes\":4194304},\n");
    d_put(report, "  \"toolchain\": {\"python_invoked\":false,\"d_invoked\":false,\"c_compiler_invoked\":false,\"tinycc_invoked\":false,\"external_assembler_invoked\":false,\"external_linker_invoked\":false}\n}\n");
    bool ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    return ok && written.ok;
}

unsafe i32 cli_release_command() {
    text root = process.executable_directory();
    text output_directory = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--output=") {
            output_directory = cli_remove_prefix(value, "--output=");
        } else {
            io.error("usage: openc release --root=ROOT --output=DIR\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(output_directory) == 0 ||
        !cli_release_ensure_directory(output_directory) {
        io.error("usage: openc release --root=ROOT --output=DIR\n");
        return 64;
    }
    text version_source;
    status version_loaded = file.read_text(
        path.join(root, "VERSION"), out version_source
    );
    if !version_loaded.ok {
        io.error("error: VERSION could not be read\n");
        return 1;
    }
    text plan;
    status plan_loaded = file.read_text(path.join(
        root, "release/SH21_NATIVE_RELEASE_PLAN.tsv"
    ), out plan);
    if !plan_loaded.ok {
        io.error("error: native release plan could not be read\n");
        return 1;
    }
    usize expected_plan = 0;
    bool inputs_ok = cli_release_plan_header(plan, expected_plan);
    NativeCursor version_cursor = NativeCursor{ value = 0 };
    TextSpan version_span = native_next_line(version_source, version_cursor);
    text version = project_slice(
        version_source, version_span.start, version_span.length
    );
    text compiler = process.executable_path();
    DBuffer compiler_record_path = d_buffer_create(
        text.byte_length(compiler) + 16
    );
    d_put(compiler_record_path, compiler);
    d_put(compiler_record_path, ".build.json");
    DBuffer compiler_hash = d_buffer_create(65);
    DBuffer build_record_hash = d_buffer_create(65);
    inputs_ok = inputs_ok && cli_release_hash_file(compiler, compiler_hash) &&
        cli_release_hash_file(
            d_buffer_text(compiler_record_path), build_record_hash
        );
    DBuffer root_name = d_buffer_create(text.byte_length(version) + 16);
    d_put(root_name, "OpenC-"); d_put(root_name, version);
    DBuffer standalone_a_path = d_buffer_create(
        text.byte_length(output_directory) + 24
    );
    d_put(standalone_a_path, output_directory);
    d_put(standalone_a_path, "/standalone-a.zip");
    DBuffer standalone_b_path = d_buffer_create(
        text.byte_length(output_directory) + 24
    );
    d_put(standalone_b_path, output_directory);
    d_put(standalone_b_path, "/standalone-b.zip");
    DBuffer source_a_path = d_buffer_create(
        text.byte_length(output_directory) + 16
    );
    d_put(source_a_path, output_directory);
    d_put(source_a_path, "/source-a.zip");
    DBuffer source_b_path = d_buffer_create(
        text.byte_length(output_directory) + 16
    );
    d_put(source_b_path, output_directory);
    d_put(source_b_path, "/source-b.zip");
    text standalone_a = d_buffer_text(standalone_a_path);
    text standalone_b = d_buffer_text(standalone_b_path);
    text source_a = d_buffer_text(source_a_path);
    text source_b = d_buffer_text(source_b_path);
    CliReleaseResult result = CliReleaseResult{
        plan_entries = 0, standalone_entries = 0, source_entries = 0,
        standalone_bytes = 0, source_bytes = 0, peak_entry_bytes = 0,
        manifest_entries = 0, stage2_elapsed = 0, stage3_elapsed = 0,
        workflow_elapsed = 0, conformance_elapsed = 0,
        compiler_hash = d_buffer_text(compiler_hash), stage2_hash = "",
        stage3_hash = "", standalone_equal = false, source_equal = false,
        archives_verified = false, manifest_verified = false,
        stage_closure = false, daily_workflow = false, conformance = false,
        historical_kit_absent = true, passed = false
    };
    usize plan_a = 0; usize entries_a = 0; usize bytes_a = 0; usize peak_a = 0;
    usize plan_b = 0; usize entries_b = 0; usize bytes_b = 0; usize peak_b = 0;
    usize source_plan_a = 0; usize source_entries_a = 0; usize source_bytes_a = 0; usize source_peak_a = 0;
    usize source_plan_b = 0; usize source_entries_b = 0; usize source_bytes_b = 0; usize source_peak_b = 0;
    bool built = inputs_ok && cli_release_build_archive(
        root, plan, version, standalone_a, true, compiler,
        d_buffer_text(compiler_record_path), d_buffer_text(compiler_hash),
        d_buffer_text(build_record_hash), plan_a, entries_a, bytes_a, peak_a
    ) && cli_release_build_archive(
        root, plan, version, standalone_b, true, compiler,
        d_buffer_text(compiler_record_path), d_buffer_text(compiler_hash),
        d_buffer_text(build_record_hash), plan_b, entries_b, bytes_b, peak_b
    ) && cli_release_build_archive(
        root, plan, version, source_a, false, compiler,
        d_buffer_text(compiler_record_path), d_buffer_text(compiler_hash),
        d_buffer_text(build_record_hash), source_plan_a, source_entries_a,
        source_bytes_a, source_peak_a
    ) && cli_release_build_archive(
        root, plan, version, source_b, false, compiler,
        d_buffer_text(compiler_record_path), d_buffer_text(compiler_hash),
        d_buffer_text(build_record_hash), source_plan_b, source_entries_b,
        source_bytes_b, source_peak_b
    );
    result.plan_entries = plan_a;
    result.standalone_entries = entries_a;
    result.source_entries = source_entries_a;
    result.standalone_bytes = bytes_a;
    result.source_bytes = source_bytes_a;
    result.peak_entry_bytes = peak_a;
    if source_peak_a > result.peak_entry_bytes {
        result.peak_entry_bytes = source_peak_a;
    }
    result.standalone_equal = built && cli_release_files_equal(
        standalone_a, standalone_b
    );
    result.source_equal = built && cli_release_files_equal(source_a, source_b);
    usize verify_bytes = 0; usize verify_entries = 0; usize verify_peak = 0;
    usize source_verify_bytes = 0; usize source_verify_entries = 0; usize source_verify_peak = 0;
    result.archives_verified = result.standalone_equal && result.source_equal &&
        plan_a == expected_plan && plan_b == expected_plan &&
        source_plan_a == expected_plan && source_plan_b == expected_plan &&
        entries_a == entries_b && source_entries_a == source_entries_b &&
        cli_zip_verify_extract(
            standalone_a, d_buffer_text(root_name), "", false, entries_a,
            verify_bytes, verify_entries, verify_peak
        ) && cli_zip_verify_extract(
            source_a, d_buffer_text(root_name), "", false, source_entries_a,
            source_verify_bytes, source_verify_entries, source_verify_peak
        );
    bool relocated = result.archives_verified && cli_release_relocated_verify(
        output_directory, d_buffer_text(root_name), d_buffer_text(compiler_hash),
        entries_a, result
    );
    result.passed = relocated && result.historical_kit_absent;
    text report_path = path.join(output_directory, "native-release-result.json");
    bool report_ok = cli_release_write_report(report_path, result);
    d_buffer_destroy(source_b_path);
    d_buffer_destroy(source_a_path);
    d_buffer_destroy(standalone_b_path);
    d_buffer_destroy(standalone_a_path);
    d_buffer_destroy(root_name);
    d_buffer_destroy(build_record_hash);
    d_buffer_destroy(compiler_hash);
    d_buffer_destroy(compiler_record_path);
    if !report_ok { io.error("error: release report could not be written\n"); return 1; }
    io.print("OpenC native release: ");
    if result.passed { io.println("PASS"); return 0; }
    io.println("FAIL");
    return 1;
}
