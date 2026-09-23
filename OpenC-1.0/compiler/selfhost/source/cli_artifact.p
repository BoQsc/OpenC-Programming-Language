import system.file;
import system.io;
import system.process;
import system.text;

text cli_artifact_kind_name(usize kind) {
    if kind == native_artifact_executable() { return "exe"; }
    if kind == native_artifact_coff_object() { return "coff-object"; }
    if kind == native_artifact_dll() { return "dll"; }
    if kind == native_artifact_static_library() { return "static-library"; }
    return "import-library";
}
usize cli_artifact_kind(text value) {
    if value == "exe" { return native_artifact_executable(); }
    if value == "coff-object" { return native_artifact_coff_object(); }
    if value == "dll" { return native_artifact_dll(); }
    if value == "static-library" { return native_artifact_static_library(); }
    if value == "import-library" { return native_artifact_import_library(); }
    return 99;
}

unsafe bool cli_artifact_write_record(
    text path,
    text project,
    text output_path,
    ref NativeArtifactOptions options,
    ref BuildTimings timings,
    bool passed
) {
    if text.byte_length(path) == 0 { return true; }
    DBuffer record = d_buffer_create(4096);
    d_put(record, "{\n  \"schema\": \"openc.windows_artifact.v1\",\n");
    d_put(record, "  \"status\": \"");
    if passed { d_put(record, "PASS"); } else { d_put(record, "FAIL"); }
    d_put(record, "\",\n  \"implementation_language\": \"OpenC\",\n");
    d_put(record, "  \"project\": "); cli_json_text(record, project);
    d_put(record, ",\n  \"output\": "); cli_json_text(record, output_path);
    d_put(record, ",\n  \"kind\": ");
    cli_json_text(record, cli_artifact_kind_name(options.kind));
    d_put(record, ",\n  \"subsystem\": \"");
    if options.subsystem == pe32_subsystem_windows_gui() {
        d_put(record, "windows");
    } else {
        d_put(record, "console");
    }
    d_put(record, "\",\n  \"dll_name\": ");
    cli_json_text(record, options.dll_name);
    d_put(record, ",\n  \"manifest_embedded\": ");
    native_put_bool(record, text.byte_length(options.manifest_path) != 0);
    d_put(record, ",\n  \"resource_embedded\": ");
    native_put_bool(record, text.byte_length(options.resource_path) != 0);
    d_put(record, ",\n  \"source_files\": ");
    d_put_usize(record, timings.source_files);
    d_put(record, ",\n  \"source_bytes\": ");
    d_put_usize(record, timings.source_bytes);
    d_put(record, ",\n  \"output_bytes\": ");
    d_put_usize(record, timings.output_bytes);
    d_put(record, ",\n  \"toolchain\": {\"python\":false,\"d\":false,\"c_compiler\":false,\"tinycc\":false,\"assembler\":false,\"linker\":false}\n}\n");
    bool ok = record.ok;
    status written = file.write_text(path, d_buffer_text(record));
    d_buffer_destroy(record);
    return ok && written.ok;
}

unsafe i32 cli_artifact_command() {
    text project = "";
    text output_path = "";
    text report_path = "";
    text timing_path = "";
    text kind_name = "";
    NativeArtifactOptions options = native_artifact_default_options();
    usize argument = 1;
    bool valid = true;
    bool profile_type_queries = false;
    bool source_chunks_explicit = false;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--project=") {
            project = cli_remove_prefix(value, "--project=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else if cli_has_prefix(value, "--report=") {
            report_path = cli_remove_prefix(value, "--report=");
        } else if cli_has_prefix(value, "--timings=") {
            timing_path = cli_remove_prefix(value, "--timings=");
        } else if value == "--profile-type-queries" {
            profile_type_queries = true;
        } else if cli_has_prefix(value, "--kind=") {
            kind_name = cli_remove_prefix(value, "--kind=");
        } else if cli_has_prefix(value, "--subsystem=") {
            text subsystem = cli_remove_prefix(value, "--subsystem=");
            if subsystem == "console" {
                options.subsystem = pe32_subsystem_windows_console();
            } else if subsystem == "windows" {
                options.subsystem = pe32_subsystem_windows_gui();
            } else {
                valid = false;
            }
        } else if cli_has_prefix(value, "--manifest=") {
            options.manifest_path = cli_remove_prefix(value, "--manifest=");
        } else if cli_has_prefix(value, "--resource=") {
            options.resource_path = cli_remove_prefix(value, "--resource=");
        } else if cli_has_prefix(value, "--dll-name=") {
            options.dll_name = cli_remove_prefix(value, "--dll-name=");
        } else if cli_has_prefix(value, "--source-chunks=") {
            source_chunks_explicit = true;
            text chunks = cli_remove_prefix(value, "--source-chunks=");
            if chunks == "1" { options.source_chunks = 1; }
            else if chunks == "2" { options.source_chunks = 2; }
            else if chunks == "4" { options.source_chunks = 4; }
            else if chunks == "auto" { options.source_chunks = 0; }
            else { valid = false; }
        } else {
            valid = false;
        }
        argument = argument + 1;
    }
    options.kind = cli_artifact_kind(kind_name);
    if !source_chunks_explicit &&
        options.kind != native_artifact_executable() {
        options.source_chunks = 1;
    }
    if text.byte_length(project) == 0 ||
        text.byte_length(output_path) == 0 || options.kind > 4 {
        valid = false;
    }
    if (options.kind == native_artifact_dll() ||
            options.kind == native_artifact_import_library()) &&
        text.byte_length(options.dll_name) == 0 {
        valid = false;
    }
    if (options.kind == native_artifact_coff_object() ||
            options.kind == native_artifact_static_library() ||
            options.kind == native_artifact_import_library()) &&
        (text.byte_length(options.manifest_path) != 0 ||
            text.byte_length(options.resource_path) != 0) {
        valid = false;
    }
    if options.source_chunks != 1 &&
        options.kind != native_artifact_executable() { valid = false; }
    if profile_type_queries && text.byte_length(timing_path) == 0 {
        valid = false;
    }
    if !valid {
        io.error("usage: openc artifact --project=PROJECT --kind=(exe|coff-object|dll|static-library|import-library) --output=FILE [--subsystem=(console|windows)] [--manifest=FILE] [--resource=FILE] [--dll-name=NAME] [--report=REPORT.json] [--timings=TIMINGS.json] [--profile-type-queries] [--source-chunks=(1|2|4|auto)]\n");
        return 64;
    }
    BuildTimings timings = build_timings_empty();
    timings.emission_mode = 2;
    timings.profile_type_queries_enabled = profile_type_queries;
    i32 result = emit_bootstrap_d_mode_artifact(
        project, output_path, true, true, timings, options
    );
    bool passed = result == 0;
    if !write_build_timings(timing_path, timings, passed) {
        io.error("error: artifact timings could not be written\n");
        return 1;
    }
    if !cli_artifact_write_record(
        report_path, project, output_path, options, timings, passed
    ) {
        io.error("error: artifact record could not be written\n");
        return 1;
    }
    if passed {
        io.print("OpenC Windows artifact: PASS (");
        io.print(cli_artifact_kind_name(options.kind));
        io.println(")");
        return 0;
    }
    io.print("OpenC Windows artifact: FAIL (");
    io.print(cli_artifact_kind_name(options.kind));
    io.println(")");
    return 1;
}
