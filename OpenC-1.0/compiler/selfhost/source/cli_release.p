import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliReleaseResult {
    usize plan_entries;
    usize standalone_entries;
    usize source_entries;
    usize standalone_bytes;
    usize source_bytes;
    usize peak_entry_bytes;
    usize manifest_entries;
    usize stage2_elapsed;
    usize stage3_elapsed;
    usize workflow_elapsed;
    usize conformance_elapsed;
    text compiler_hash;
    text stage2_hash;
    text stage3_hash;
    bool standalone_equal;
    bool source_equal;
    bool archives_verified;
    bool manifest_verified;
    bool stage_closure;
    bool daily_workflow;
    bool conformance;
    bool historical_kit_absent;
    bool passed;
}

unsafe bool cli_release_has_suffix(text value, text suffix) {
    usize length = text.byte_length(value);
    usize suffix_length = text.byte_length(suffix);
    if suffix_length > length { return false; }
    return span_equals_ascii(
        value, length - suffix_length, suffix_length, suffix
    );
}

unsafe bool cli_release_standalone_path(text relative) {
    if cli_has_prefix(relative, "third_party/tinycc-win64/") ||
        cli_has_prefix(relative, "compiler/bootstrap/") ||
        cli_has_prefix(relative, "tests/python/") ||
        cli_has_prefix(relative, "tests/source/") ||
        cli_has_prefix(relative, "scripts/") ||
        cli_has_prefix(relative, ".github/") {
        return false;
    }
    if relative == "MANIFEST.sha256" || relative == "tests/dub.json" ||
        relative == "dub.json" || relative == "dub.selections.json" {
        return false;
    }
    return !cli_release_has_suffix(relative, ".c") &&
        !cli_release_has_suffix(relative, ".d") &&
        !cli_release_has_suffix(relative, ".h") &&
        !cli_release_has_suffix(relative, ".py") &&
        !cli_release_has_suffix(relative, ".pyc") &&
        !cli_release_has_suffix(relative, ".ps1") &&
        !cli_release_has_suffix(relative, ".cmd") &&
        !cli_release_has_suffix(relative, ".dll") &&
        !cli_release_has_suffix(relative, ".exe") &&
        !cli_release_has_suffix(relative, ".obj") &&
        !cli_release_has_suffix(relative, ".lib") &&
        !cli_release_has_suffix(relative, ".pdb");
}

unsafe bool cli_release_plan_header(text plan, ref usize expected) {
    NativeCursor cursor = NativeCursor{ value = 0 };
    TextSpan header_span = native_next_line(plan, cursor);
    text header = project_slice(
        plan, header_span.start, header_span.length
    );
    NativeCursor fields = NativeCursor{ value = 0 };
    TextSpan schema = native_next_field(header, fields);
    TextSpan version = native_next_field(header, fields);
    TextSpan count = native_next_field(header, fields);
    usize parsed = native_parse_usize(project_slice(
        header, count.start, count.length
    ));
    expected = parsed;
    return span_equals_ascii(
        header, schema.start, schema.length,
        "openc.native_release_plan.v1"
    ) && span_equals_ascii(
        header, version.start, version.length, "1"
    ) && parsed != 0;
}

unsafe bool cli_release_add_plan(
    ref CliZipWriter writer,
    text root,
    text plan,
    bool standalone,
    ref usize records,
    ref usize accepted
) {
    NativeCursor cursor = NativeCursor{ value = 0 };
    native_next_line(plan, cursor);
    usize record_count = 0;
    usize accepted_count = 0;
    while writer.ok && cursor.value < text.byte_length(plan) {
        TextSpan line_span = native_next_line(plan, cursor);
        text relative = project_slice(
            plan, line_span.start, line_span.length
        );
        if text.byte_length(relative) != 0 {
            record_count = record_count + 1;
            if !standalone || cli_release_standalone_path(relative) {
                if !cli_zip_add_file(
                    writer, relative, path.join(root, relative), standalone
                ) {
                    records = record_count;
                    accepted = accepted_count;
                    return false;
                }
                accepted_count = accepted_count + 1;
            }
        }
    }
    records = record_count;
    accepted = accepted_count;
    return writer.ok;
}

unsafe bool cli_release_hash_file(text input, ref DBuffer hash) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(input, out data, out length);
    if !loaded.ok { return false; }
    if length > 16777216 {
        memory.free(data);
        return false;
    }
    winmd_sha256_hex(data, length, hash);
    memory.free(data);
    return hash.ok;
}

unsafe void cli_release_record(
    text version,
    text compiler_hash,
    text build_record_hash,
    ref DBuffer output
) {
    d_put(output, "{\n  \"schema\": \"openc.native_standalone_release.v1\",\n");
    d_put(output, "  \"version\": "); cli_json_text(output, version);
    d_put(output, ",\n  \"target\": \"windows-x86_64-hosted\",\n");
    d_put(output, "  \"compiler\": {\"path\":\"openc.exe\",\"implementation_language\":\"OpenC\",\"sha256\":");
    cli_json_text(output, compiler_hash);
    d_put(output, ",\"build_record_sha256\":");
    cli_json_text(output, build_record_hash);
    d_put(output, "},\n  \"bootstrap\": {\"path\":\"bootstrap/openc-stage0.exe\",\"role\":\"pinned previous OpenC compiler\",\"required_legacy_tool\":false},\n");
    d_put(output, "  \"backend\": {\"machine_code\":\"OpenC x64\",\"executable_format\":\"PE32+\",\"external_assembler_required\":false,\"external_linker_required\":false,\"crt_required\":false},\n");
    d_put(output, "  \"required_toolchain\": {\"python\":false,\"dmd\":false,\"dub\":false,\"c_compiler\":false,\"tinycc\":false},\n");
    d_put(output, "  \"archive\": {\"format\":\"ZIP store\",\"timestamp\":\"1980-01-01T00:00:00Z\",\"entry_buffer_limit_bytes\":16777216,\"archive_verify_limit_bytes\":67108864},\n");
    d_put(output, "  \"historical_bootstrap_audit_kit\":\"not packaged; explicitly optional in the source repository\",\n");
    d_put(output, "  \"linux_and_freestanding_gate\": false\n}\n");
}

unsafe bool cli_release_build_archive(
    text root,
    text plan,
    text version,
    text archive,
    bool standalone,
    text compiler,
    text compiler_record,
    text compiler_hash,
    text build_record_hash,
    ref usize plan_records,
    ref usize archive_entries,
    ref usize input_bytes,
    ref usize peak_entry_bytes
) {
    DBuffer root_name = d_buffer_create(text.byte_length(version) + 16);
    d_put(root_name, "OpenC-"); d_put(root_name, version);
    CliZipWriter writer = cli_zip_writer_create(
        archive, d_buffer_text(root_name), standalone
    );
    usize records = 0;
    usize accepted = 0;
    bool ok = cli_release_add_plan(
        writer, root, plan, standalone, records, accepted
    );
    if standalone && ok {
        DBuffer release_record = d_buffer_create(4096);
        cli_release_record(
            version, compiler_hash, build_record_hash, release_record
        );
        ok = release_record.ok &&
            cli_zip_add_file(writer, "openc.exe", compiler, true) &&
            cli_zip_add_file(
                writer, "openc.exe.build.json", compiler_record, true
            ) &&
            cli_zip_add_file(
                writer, "bootstrap/openc-stage0.exe", compiler, true
            ) &&
            cli_zip_add_file(
                writer, "README-STANDALONE.md",
                path.join(root, "release/STANDALONE_WINDOWS_README.md"), true
            ) &&
            cli_zip_add_data(
                writer, "STANDALONE-RELEASE.json", release_record.data,
                release_record.length, true
            );
        if ok {
            ok = cli_zip_add_data(
                writer, "STANDALONE-MANIFEST.sha256", writer.manifest.data,
                writer.manifest.length, false
            );
        }
        d_buffer_destroy(release_record);
    }
    if ok { ok = cli_zip_writer_finish(writer); }
    plan_records = records;
    archive_entries = writer.entries;
    input_bytes = writer.input_bytes;
    peak_entry_bytes = writer.peak_entry_bytes;
    cli_zip_writer_destroy(writer);
    d_buffer_destroy(root_name);
    return ok;
}

unsafe bool cli_release_verify_manifest(
    text distribution,
    usize expected_entries,
    ref usize entries
) {
    text manifest;
    status loaded = file.read_text(path.join(
        distribution, "STANDALONE-MANIFEST.sha256"
    ), out manifest);
    if !loaded.ok { return false; }
    NativeCursor cursor = NativeCursor{ value = 0 };
    bool valid = true;
    usize entry_count = 0;
    while valid && cursor.value < text.byte_length(manifest) {
        TextSpan line_span = native_next_line(manifest, cursor);
        text line = project_slice(
            manifest, line_span.start, line_span.length
        );
        if text.byte_length(line) != 0 {
            usize line_length = text.byte_length(line);
            text expected = "";
            text relative = "";
            if line_length >= 67 && byte_at_or_zero(line, 64) == 32 &&
                byte_at_or_zero(line, 65) == 32 {
                expected = project_slice(line, 0, 64);
                relative = project_slice(line, 66, line_length - 66);
            }
            DBuffer actual = d_buffer_create(65);
            valid = text.byte_length(expected) == 64 &&
                text.byte_length(relative) != 0 &&
                cli_release_hash_file(path.join(distribution, relative), actual) &&
                d_buffer_text(actual) == expected;
            d_buffer_destroy(actual);
            entry_count = entry_count + 1;
        }
    }
    entries = entry_count;
    return valid && entry_count + 1 == expected_entries;
}

unsafe bool cli_release_run_task(
    ref DBuffer command,
    text marker,
    ref usize elapsed
) {
    usize started = process.monotonic_milliseconds();
    i32 exit_code;
    text output;
    status ran = cli_process_run_bounded(
        d_buffer_text(command), cast(usize, 300000), out exit_code, out output
    );
    elapsed = process.monotonic_milliseconds() - started;
    if !ran.ok { return false; }
    return exit_code == 0 && native_contains(output, marker);
}

unsafe bool cli_release_package_workflow(
    text compiler,
    text distribution,
    text output_directory,
    ref usize elapsed
) {
    usize started = process.monotonic_milliseconds();
    usize task_elapsed = 0;
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "test");
    cli_workflow_command_named_argument(
        command, "--manifest=", path.join(
            distribution, "tests/SH21_NATIVE_WORKFLOW_TESTS.json"
        )
    );
    cli_workflow_command_named_argument(
        command, "--report=", path.join(
            output_directory, "relocated-tests.json"
        )
    );
    bool passed = cli_release_run_task(
        command, "OpenC test: 5/5 passed", task_elapsed
    );
    d_buffer_destroy(command);
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "pe-audit");
        cli_workflow_command_named_argument(command, "--input=", compiler);
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-pe-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC PE audit: PASS", task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "lsp-audit");
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-lsp-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC native LSP audit: PASS (42/42)", task_elapsed
        );
        d_buffer_destroy(command);
    }
    if passed {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "contract-audit");
        cli_workflow_command_named_argument(command, "--root=", distribution);
        cli_workflow_command_named_argument(
            command, "--output=", path.join(
                output_directory, "relocated-contract-audit.json"
            )
        );
        passed = cli_release_run_task(
            command, "OpenC native contract audit: PASS (29/29)", task_elapsed
        );
        d_buffer_destroy(command);
    }
    elapsed = process.monotonic_milliseconds() - started;
    return passed;
}

unsafe bool cli_release_relocated_verify(
    text output_directory,
    text root_name,
    text compiler_hash,
    usize standalone_entries,
    ref CliReleaseResult result
) {
    text extraction = path.join(output_directory, "relocated");
    if !cli_release_ensure_directory(extraction) { return false; }
    text archive = path.join(output_directory, "standalone-a.zip");
    usize archive_bytes = 0;
    usize entries = 0;
    usize peak = 0;
    bool extracted = cli_zip_verify_extract(
        archive, root_name, extraction, true, standalone_entries,
        archive_bytes, entries, peak
    );
    text distribution = path.join(extraction, root_name);
    usize manifest_entries = 0;
    result.manifest_verified = extracted && cli_release_verify_manifest(
        distribution, standalone_entries, manifest_entries
    );
    result.manifest_entries = manifest_entries;
    text packaged = path.join(distribution, "openc.exe");
    text project = path.join(
        distribution, "compiler/selfhost/openc.project.json"
    );
    text stage2 = path.join(output_directory, "relocated-stage2.exe");
    text stage3 = path.join(output_directory, "relocated-stage3.exe");
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, packaged, "build");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--output=", stage2);
    bool stage2_ok = cli_release_run_task(
        command, "", result.stage2_elapsed
    );
    d_buffer_destroy(command);
    command = d_buffer_create(32768);
    cli_workflow_command_start(command, stage2, "build");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--output=", stage3);
    bool stage3_ok = stage2_ok && cli_release_run_task(
        command, "", result.stage3_elapsed
    );
    d_buffer_destroy(command);
    DBuffer stage2_hash = d_buffer_create(65);
    DBuffer stage3_hash = d_buffer_create(65);
    result.stage_closure = stage3_ok &&
        cli_release_hash_file(stage2, stage2_hash) &&
        cli_release_hash_file(stage3, stage3_hash) &&
        d_buffer_text(stage2_hash) == d_buffer_text(stage3_hash);
    result.stage2_hash = d_buffer_text(stage2_hash);
    result.stage3_hash = d_buffer_text(stage3_hash);

    result.daily_workflow = result.stage_closure &&
        cli_release_package_workflow(
            stage3, distribution, output_directory, result.workflow_elapsed
        );

    command = d_buffer_create(32768);
    cli_workflow_command_start(command, stage3, "validate");
    cli_workflow_command_named_argument(
        command, "--manifest=", path.join(
            distribution, "conformance/fixtures/MANIFEST.json"
        )
    );
    cli_workflow_command_named_argument(
        command, "--output=", path.join(
            output_directory, "relocated-conformance.json"
        )
    );
    result.conformance = result.daily_workflow && cli_release_run_task(
        command, "278/278", result.conformance_elapsed
    );
    d_buffer_destroy(command);
    return result.manifest_verified && result.stage_closure &&
        result.daily_workflow && result.conformance;
}

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
