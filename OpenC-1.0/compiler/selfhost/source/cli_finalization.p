import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliEditorPackageResult {
    usize entries;
    usize archive_bytes;
    usize input_bytes;
    usize peak_entry_bytes;
    text compiler_hash;
    text archive_hash;
    bool structure_valid;
    bool passed;
}

unsafe bool cli_editor_package_build(
    text root,
    text compiler,
    text output_path,
    ref CliEditorPackageResult result
) {
    CliZipWriter writer = cli_zip_writer_create(output_path, "", false);
    bool ok =
        cli_zip_add_file(writer, "[Content_Types].xml", path.join(
            root, "editors/vscode/[Content_Types].xml"
        ), false) &&
        cli_zip_add_file(writer, "extension.vsixmanifest", path.join(
            root, "editors/vscode/extension.vsixmanifest"
        ), false) &&
        cli_zip_add_file(writer, "extension/LICENSE", path.join(
            root, "LICENSE"
        ), false) &&
        cli_zip_add_file(writer, "extension/README.md", path.join(
            root, "editors/vscode/README.md"
        ), false) &&
        cli_zip_add_file(writer, "extension/bin/VERSION", path.join(
            root, "VERSION"
        ), false) &&
        cli_zip_add_file(writer, "extension/bin/openc.exe", compiler, false) &&
        cli_zip_add_file(writer, "extension/extension.js", path.join(
            root, "editors/vscode/extension.js"
        ), false) &&
        cli_zip_add_file(writer, "extension/language-configuration.json", path.join(
            root, "editors/vscode/language-configuration.json"
        ), false) &&
        cli_zip_add_file(writer, "extension/package.json", path.join(
            root, "editors/vscode/package.json"
        ), false);
    if ok { ok = cli_zip_writer_finish(writer); }
    result.entries = writer.entries;
    result.input_bytes = writer.input_bytes;
    result.peak_entry_bytes = writer.peak_entry_bytes;
    cli_zip_writer_destroy(writer);
    if !ok || result.entries != 9 { return false; }

    usize verified_entries = 0;
    usize verified_peak = 0;
    usize archive_bytes = 0;
    result.structure_valid = cli_zip_verify_extract(
        output_path, "", "", false, 9, archive_bytes,
        verified_entries, verified_peak
    );
    result.archive_bytes = archive_bytes;
    DBuffer compiler_hash = d_buffer_create(65);
    DBuffer archive_hash = d_buffer_create(65);
    bool hashed = cli_release_hash_file(compiler, compiler_hash) &&
        cli_release_hash_file(output_path, archive_hash);
    result.compiler_hash = d_buffer_text(compiler_hash);
    result.archive_hash = d_buffer_text(archive_hash);
    result.passed = hashed && result.structure_valid &&
        verified_entries == 9 && verified_peak <= 16777216 &&
        result.peak_entry_bytes <= 16777216;
    // Result text is copied into the report before these buffers are destroyed.
    if !result.passed {
        d_buffer_destroy(compiler_hash);
        d_buffer_destroy(archive_hash);
        result.compiler_hash = "";
        result.archive_hash = "";
        return false;
    }

    DBuffer report = d_buffer_create(4096);
    d_put(report, "{\n  \"schema\": \"openc.vscode_package.v1\",\n");
    d_put(report, "  \"version\": \"1.0.0\",\n");
    d_put(report, "  \"target\": \"windows-x86_64-hosted\",\n");
    d_put(report, "  \"extension_id\": \"openc-language.openc\",\n");
    d_put(report, "  \"entries\": "); d_put_usize(report, result.entries);
    d_put(report, ",\n  \"archive_bytes\": "); d_put_usize(report, result.archive_bytes);
    d_put(report, ",\n  \"input_bytes\": "); d_put_usize(report, result.input_bytes);
    d_put(report, ",\n  \"peak_entry_bytes\": "); d_put_usize(report, result.peak_entry_bytes);
    d_put(report, ",\n  \"compiler_sha256\": "); cli_json_text(report, d_buffer_text(compiler_hash));
    d_put(report, ",\n  \"vsix_sha256\": "); cli_json_text(report, d_buffer_text(archive_hash));
    d_put(report, ",\n  \"zip_store\": true,\n");
    d_put(report, "  \"deterministic_timestamp\": \"1980-01-01T00:00:00Z\",\n");
    d_put(report, "  \"python_invoked\": false,\n");
    d_put(report, "  \"node_or_npm_invoked\": false,\n");
    d_put(report, "  \"network_required\": false,\n");
    d_put(report, "  \"status\": \"PASS\"\n}\n");
    text report_path = path.join(
        path.directory(output_path), "vscode-package-report.json"
    );
    status written = file.write_text(report_path, d_buffer_text(report));
    bool report_ok = report.ok && written.ok;
    d_buffer_destroy(report);
    d_buffer_destroy(compiler_hash);
    d_buffer_destroy(archive_hash);
    result.compiler_hash = "";
    result.archive_hash = "";
    return report_ok;
}

unsafe i32 cli_editor_package_command() {
    text root = "";
    text compiler = cli_self_executable();
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--compiler=") {
            compiler = cli_remove_prefix(value, "--compiler=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else {
            io.error("usage: openc editor-package --root=ROOT [--compiler=OPENC.exe] --output=EXTENSION.vsix\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(root) == 0 || text.byte_length(output_path) == 0 ||
        !cli_release_ensure_directory(path.directory(output_path)) {
        io.error("usage: openc editor-package --root=ROOT [--compiler=OPENC.exe] --output=EXTENSION.vsix\n");
        return 64;
    }
    CliEditorPackageResult result = CliEditorPackageResult{
        entries = 0, archive_bytes = 0, input_bytes = 0,
        peak_entry_bytes = 0, compiler_hash = "", archive_hash = "",
        structure_valid = false, passed = false
    };
    bool packaged = cli_editor_package_build(
        root, compiler, output_path, result
    );
    io.print("OpenC VS Code package: ");
    if packaged { io.print("PASS"); } else { io.print("FAIL"); }
    io.print(" ("); io.print(result.entries); io.println("/9 entries)");
    if packaged { return 0; }
    return 1;
}

unsafe text cli_sh25_load(text root, text relative) {
    text output;
    status loaded = file.read_text(path.join(root, relative), out output);
    if loaded.ok { return output; }
    return "";
}

unsafe text cli_sh25_load_path(text input_path) {
    text output;
    status loaded = file.read_text(input_path, out output);
    if loaded.ok { return output; }
    return "";
}

unsafe bool cli_sh25_write_report(
    text output_path,
    text compiler_hash,
    text vsix_hash,
    usize archive_bytes,
    ref CliLspAuditCounts counts,
    ref DBuffer checks,
    bool passed
) {
    DBuffer report = d_buffer_create(131072);
    d_put(report, "{\n  \"schema\": \"openc.sh25_finalization_audit.v1\",\n");
    d_put(report, "  \"milestone\": \"SH-25_WINDOWS_1_0_FINALIZATION\",\n");
    d_put(report, "  \"target\": \"windows-x86_64-hosted\",\n");
    d_put(report, "  \"compiler_sha256\": "); cli_json_text(report, compiler_hash);
    d_put(report, ",\n  \"vsix_sha256\": "); cli_json_text(report, vsix_hash);
    d_put(report, ",\n  \"vsix_bytes\": "); d_put_usize(report, archive_bytes);
    d_put(report, ",\n  \"review_class\": \"INTERNAL_MAINTAINER_REVIEW\",\n");
    d_put(report, "  \"independent_review_claimed\": false,\n");
    d_put(report, "  \"open_p0\": 0,\n  \"open_p1\": 0,\n");
    d_put(report, "  \"checks\": [\n");
    d_put(report, d_buffer_text(checks));
    d_put(report, "\n  ],\n  \"checks_passed\": "); d_put_usize(report, counts.passed);
    d_put(report, ",\n  \"checks_total\": "); d_put_usize(report, counts.total);
    d_put(report, ",\n  \"historical_rule_id_matches_disclosed\": 93,\n");
    d_put(report, "  \"linux_and_freestanding_gate\": false,\n");
    d_put(report, "  \"python_invoked_by_native_audit\": false,\n");
    d_put(report, "  \"d_c_tinycc_assembler_linker_invoked\": false,\n");
    d_put(report, "  \"network_required\": false,\n  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");
    status written = file.write_text(output_path, d_buffer_text(report));
    bool ok = report.ok && written.ok;
    d_buffer_destroy(report);
    return ok;
}

unsafe i32 cli_finalization_audit_command() {
    text root = "";
    text vsix_a = "";
    text vsix_b = "";
    text clean_profile_path = "";
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--vsix-a=") {
            vsix_a = cli_remove_prefix(value, "--vsix-a=");
        } else if cli_has_prefix(value, "--vsix-b=") {
            vsix_b = cli_remove_prefix(value, "--vsix-b=");
        } else if cli_has_prefix(value, "--clean-profile=") {
            clean_profile_path = cli_remove_prefix(value, "--clean-profile=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else {
            io.error("usage: openc finalization-audit --root=ROOT --vsix-a=A.vsix --vsix-b=B.vsix --clean-profile=EVIDENCE.json --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(root) == 0 || text.byte_length(vsix_a) == 0 ||
        text.byte_length(vsix_b) == 0 ||
        text.byte_length(clean_profile_path) == 0 ||
        text.byte_length(output_path) == 0 ||
        !cli_release_ensure_directory(path.directory(output_path)) {
        io.error("usage: openc finalization-audit --root=ROOT --vsix-a=A.vsix --vsix-b=B.vsix --clean-profile=EVIDENCE.json --output=REPORT.json\n");
        return 64;
    }

    text plan = cli_sh25_load(root, "tests/SH25_FINALIZATION_AUDIT_PLAN.tsv");
    text content_types = cli_sh25_load(root, "editors/vscode/[Content_Types].xml");
    text vsix_manifest = cli_sh25_load(root, "editors/vscode/extension.vsixmanifest");
    text package = cli_sh25_load(root, "editors/vscode/package.json");
    text extension = cli_sh25_load(root, "editors/vscode/extension.js");
    text review_program = cli_sh25_load(root, "review/REVIEW_PROGRAM.md");
    text invitation = cli_sh25_load(root, "review/SH25_INDEPENDENT_REVIEW_INVITATION.md");
    text intake = cli_sh25_load(root, "review/SH25_REVIEW_INTAKE.json");
    text internal_review = cli_sh25_load(root, "review/SH25_FINAL_INTERNAL_REVIEW.md");
    text release_authority = cli_sh25_load(root, "release/RELEASE_AUTHORITY.md");
    text status_source = cli_sh25_load(root, "STATUS.md");
    text clean_profile = cli_sh25_load_path(clean_profile_path);
    bool plan_read = text.byte_length(plan) != 0;
    bool content_types_read = text.byte_length(content_types) != 0;
    bool vsix_manifest_read = text.byte_length(vsix_manifest) != 0;
    bool package_read = text.byte_length(package) != 0;
    bool extension_read = text.byte_length(extension) != 0;
    bool review_program_read = text.byte_length(review_program) != 0;
    bool invitation_read = text.byte_length(invitation) != 0;
    bool intake_read = text.byte_length(intake) != 0;
    bool internal_review_read = text.byte_length(internal_review) != 0;
    bool authority_read = text.byte_length(release_authority) != 0;
    bool status_read = text.byte_length(status_source) != 0;
    bool clean_read = text.byte_length(clean_profile) != 0;

    usize entries_a = 0;
    usize entries_b = 0;
    usize peak_a = 0;
    usize peak_b = 0;
    usize bytes_a = 0;
    usize bytes_b = 0;
    text extraction = path.join(path.directory(output_path), "sh25-vsix-extract");
    bool extraction_ready = cli_release_ensure_directory(extraction);
    bool structure_a = extraction_ready && cli_zip_verify_extract(
        vsix_a, "", extraction, true, 9, bytes_a, entries_a, peak_a
    );
    bool structure_b = cli_zip_verify_extract(
        vsix_b, "", "", false, 9, bytes_b, entries_b, peak_b
    );
    bool archives_equal = structure_a && structure_b &&
        cli_release_files_equal(vsix_a, vsix_b);
    DBuffer compiler_hash = d_buffer_create(65);
    DBuffer payload_hash = d_buffer_create(65);
    DBuffer vsix_hash = d_buffer_create(65);
    bool hashes_ok = cli_release_hash_file(cli_self_executable(), compiler_hash) &&
        cli_release_hash_file(path.join(
            extraction, "extension/bin/openc.exe"
        ), payload_hash) && cli_release_hash_file(vsix_a, vsix_hash);

    DBuffer checks = d_buffer_create(131072);
    CliLspAuditCounts counts = CliLspAuditCounts{
        total = 0, passed = 0, primary_frames = 0, semantic_frames = 0
    };
    cli_lsp_audit_case(checks, counts, "audit_plan_readable", plan_read);
    cli_lsp_audit_case(checks, counts, "audit_plan_contract", plan_read && native_contains(plan, "openc.sh25_finalization_audit_plan.v1\t1\t44"));
    cli_lsp_audit_case(checks, counts, "vsix_content_types", content_types_read && native_contains(content_types, "application/octet-stream"));
    cli_lsp_audit_case(checks, counts, "vsix_manifest", vsix_manifest_read && native_contains(vsix_manifest, "Id=\"openc\"") && native_contains(vsix_manifest, "Version=\"1.0.0\""));
    cli_lsp_audit_case(checks, counts, "extension_version", package_read && native_contains(package, "\"version\": \"1.0.0\""));
    cli_lsp_audit_case(checks, counts, "openc_p_registration", package_read && native_contains(package, "\"extensions\": [\".p\"]"));
    cli_lsp_audit_case(checks, counts, "extension_zero_bsd", package_read && native_contains(package, "\"license\": \"0BSD\""));
    cli_lsp_audit_case(checks, counts, "extension_dependency_free", package_read && !native_contains(package, "\"dependencies\"") && !native_contains(package, "\"devDependencies\""));
    cli_lsp_audit_case(checks, counts, "packaged_compiler_preferred", extension_read && native_contains(extension, "path.join('bin', 'openc.exe')"));
    cli_lsp_audit_case(checks, counts, "extension_probe_markers", extension_read && native_contains(extension, "[OpenC] extension activated") && native_contains(extension, "[OpenC] language server ready") && native_contains(extension, "[OpenC] diagnostics:"));
    cli_lsp_audit_case(checks, counts, "vsix_a_structure", structure_a);
    cli_lsp_audit_case(checks, counts, "vsix_b_structure", structure_b);
    cli_lsp_audit_case(checks, counts, "vsix_byte_determinism", archives_equal);
    cli_lsp_audit_case(checks, counts, "vsix_a_entry_count", entries_a == 9);
    cli_lsp_audit_case(checks, counts, "vsix_b_entry_count", entries_b == 9);
    cli_lsp_audit_case(checks, counts, "vsix_archive_limit", bytes_a <= 67108864 && peak_a <= 16777216 && bytes_b <= 67108864 && peak_b <= 16777216);
    cli_lsp_audit_case(checks, counts, "packaged_compiler_byte_exact", hashes_ok && d_buffer_text(compiler_hash) == d_buffer_text(payload_hash));
    cli_lsp_audit_case(checks, counts, "clean_profile_evidence_readable", clean_read);
    cli_lsp_audit_case(checks, counts, "clean_profile_schema", clean_read && native_contains(clean_profile, "\"schema\": \"openc.sh25_clean_vscode_profile.v1\""));
    cli_lsp_audit_case(checks, counts, "clean_profile_windows_x64", clean_read && native_contains(clean_profile, "\"platform\": \"windows-x86_64\""));
    cli_lsp_audit_case(checks, counts, "clean_profile_started_empty", clean_read && native_contains(clean_profile, "\"preexisting_extensions\": []"));
    cli_lsp_audit_case(checks, counts, "clean_profile_extension_installed", clean_read && native_contains(clean_profile, "openc-language.openc@1.0.0"));
    cli_lsp_audit_case(checks, counts, "clean_profile_extension_activated", clean_read && native_contains(clean_profile, "\"extension_activated\": true"));
    cli_lsp_audit_case(checks, counts, "clean_profile_server_ready", clean_read && native_contains(clean_profile, "\"language_server_ready\": true"));
    cli_lsp_audit_case(checks, counts, "clean_profile_diagnostics_roundtrip", clean_read && native_contains(clean_profile, "\"diagnostics_roundtrip\": true"));
    cli_lsp_audit_case(checks, counts, "clean_profile_packaged_compiler_selected", clean_read && native_contains(clean_profile, "\"packaged_compiler_selected\": true"));
    cli_lsp_audit_case(checks, counts, "clean_profile_vsix_identity", hashes_ok && native_contains(clean_profile, d_buffer_text(vsix_hash)));
    cli_lsp_audit_case(checks, counts, "clean_profile_compiler_identity", hashes_ok && native_contains(clean_profile, d_buffer_text(compiler_hash)));
    cli_lsp_audit_case(checks, counts, "clean_profile_vscode_supported", clean_read && native_contains(clean_profile, "\"version_supported\": true"));
    cli_lsp_audit_case(checks, counts, "clean_profile_memory_guard", clean_read && native_contains(clean_profile, "\"within_memory_limit\": true") && native_contains(clean_profile, "\"working_set_limit_bytes\": 2147483648") && native_contains(clean_profile, "\"openc_working_set_limit_bytes\": 67108864"));
    cli_lsp_audit_case(checks, counts, "clean_profile_status", clean_read && native_contains(clean_profile, "\"unexpected_server_exits\": 0") && native_contains(clean_profile, "\"provider_failures\": 0") && native_contains(clean_profile, "\"vscode_process_tree_terminated\": true") && native_contains(clean_profile, "\"status\": \"PASS\""));
    cli_lsp_audit_case(checks, counts, "review_program_readable", review_program_read);
    cli_lsp_audit_case(checks, counts, "review_independence_preserved", review_program_read && native_contains(review_program, "never `INDEPENDENT_REVIEW`") && native_contains(review_program, "recommended post-release"));
    cli_lsp_audit_case(checks, counts, "review_invitation_readable", invitation_read);
    cli_lsp_audit_case(checks, counts, "review_tracks_complete", invitation_read && native_contains(invitation, "Grammar") && native_contains(invitation, "Semantics") && native_contains(invitation, "Security") && native_contains(invitation, "Editor") && native_contains(invitation, "Release"));
    cli_lsp_audit_case(checks, counts, "reviewer_declaration_required", invitation_read && native_contains(invitation, "independence declaration"));
    cli_lsp_audit_case(checks, counts, "review_intake_schema", intake_read && native_contains(intake, "openc.sh25_review_intake.v1"));
    cli_lsp_audit_case(checks, counts, "five_external_tracks_open", intake_read && native_contains(intake, "\"tracks_open\": 5") && native_contains(intake, "\"independent_reviews_received\": 0"));
    cli_lsp_audit_case(checks, counts, "no_open_p0_or_p1", intake_read && native_contains(intake, "\"open_p0\": 0") && native_contains(intake, "\"open_p1\": 0"));
    cli_lsp_audit_case(checks, counts, "internal_review_honestly_labelled", internal_review_read && native_contains(internal_review, "INTERNAL_MAINTAINER_REVIEW") && native_contains(internal_review, "independent third-party review"));
    cli_lsp_audit_case(checks, counts, "licensing_frozen", status_read && native_contains(status_source, "software license:                    0BSD") && native_contains(status_source, "specification/docs/assets:           CC0-1.0"));
    cli_lsp_audit_case(checks, counts, "windows_scope_and_optional_targets", status_read && native_contains(status_source, "Linux/freestanding verified:         NO; OPTIONAL FUTURE TARGETS"));
    cli_lsp_audit_case(checks, counts, "owner_publication_authority", authority_read && native_contains(release_authority, "project owner") && native_contains(release_authority, "Publication is a distinct act"));
    cli_lsp_audit_case(checks, counts, "historical_rule_ids_disclosed", status_read && native_contains(status_source, "PRIOR 93 COMPATIBILITY DISCLOSED"));

    bool passed = counts.total == 44 && counts.passed == counts.total &&
        hashes_ok && archives_equal;
    bool written = cli_sh25_write_report(
        output_path, d_buffer_text(compiler_hash), d_buffer_text(vsix_hash),
        bytes_a, counts, checks, passed
    );
    d_buffer_destroy(compiler_hash);
    d_buffer_destroy(payload_hash);
    d_buffer_destroy(vsix_hash);
    d_buffer_destroy(checks);
    if !written {
        io.error("error: SH-25 finalization report could not be written\n");
        return 1;
    }
    io.print("OpenC SH-25 finalization audit: ");
    if passed { io.print("PASS"); } else { io.print("FAIL"); }
    io.print(" ("); io.print(counts.passed); io.print("/");
    io.print(counts.total); io.println(")");
    if passed { return 0; }
    return 1;
}
