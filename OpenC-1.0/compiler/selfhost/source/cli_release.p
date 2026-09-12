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
    d_put(output, "  \"backend\": {\"machine_code\":\"OpenC x64\",\"artifact_formats\":[\"PE32+ EXE\",\"PE32+ DLL\",\"AMD64 COFF object\",\"COFF static library\",\"COFF import library\"],\"external_assembler_required\":false,\"external_linker_required\":false,\"crt_required\":false},\n");
    d_put(output, "  \"required_toolchain\": {\"python\":false,\"dmd\":false,\"dub\":false,\"c_compiler\":false,\"tinycc\":false},\n");
    d_put(output, "  \"archive\": {\"format\":\"ZIP store\",\"timestamp\":\"1980-01-01T00:00:00Z\",\"entry_buffer_limit_bytes\":16777216,\"archive_verify_limit_bytes\":67108864},\n");
    d_put(output, "  \"historical_bootstrap_audit_kit\":\"not packaged; explicitly optional in the source repository\",\n");
    d_put(output, "  \"linux_and_freestanding_gate\": false\n}\n");
}
