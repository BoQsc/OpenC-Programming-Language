import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe i32 cli_pe_coff_audit_command() {
    text root = process.executable_directory();
    text artifacts = "";
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--artifacts=") {
            artifacts = cli_remove_prefix(value, "--artifacts=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else {
            io.error("usage: openc pe-coff-audit --root=ROOT --artifacts=DIR --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(artifacts) == 0 ||
        text.byte_length(output_path) == 0 {
        io.error("usage: openc pe-coff-audit --root=ROOT --artifacts=DIR --output=REPORT.json\n");
        return 64;
    }
    // The secure loader deliberately accepts only an absolute DLL path.
    // Resolve artifact paths against the repository root used by this audit;
    // path.join preserves an already absolute right operand.
    artifacts = path.join(root, artifacts);
    if !cli_release_ensure_directory(artifacts) ||
        !cli_release_ensure_directory(path.directory(output_path)) {
        io.error("error: SH-22 audit output directory unavailable\n");
        return 1;
    }
    text compiler = cli_self_executable();
    text project = path.join(root, "tests/sh22_pe_coff/openc.project.json");
    text manifest = path.join(root, "tests/sh22_pe_coff/app.manifest");
    text resource_path = path.join(
        root, "tests/sh22_pe_coff/resource.txt"
    );
    text object_a = path.join(artifacts, "sh22-a.obj");
    text object_b = path.join(artifacts, "sh22-b.obj");
    text static_a = path.join(artifacts, "sh22-static-a.lib");
    text static_b = path.join(artifacts, "sh22-static-b.lib");
    text import_a = path.join(artifacts, "sh22-import-a.lib");
    text import_b = path.join(artifacts, "sh22-import-b.lib");
    text dll_a = path.join(artifacts, "openc-sh22.dll");
    text dll_b = path.join(artifacts, "openc-sh22-b.dll");
    text gui_a = path.join(artifacts, "sh22-gui-a.exe");
    text gui_b = path.join(artifacts, "sh22-gui-b.exe");
    text console_a = path.join(artifacts, "sh22-console-a.exe");
    text console_b = path.join(artifacts, "sh22-console-b.exe");

    bool object_generated = cli_sh22_run_artifact(
        compiler, project, "coff-object", object_a, "", "", "", ""
    ) && cli_sh22_run_artifact(
        compiler, project, "coff-object", object_b, "", "", "", ""
    );
    bool static_generated = cli_sh22_run_artifact(
        compiler, project, "static-library", static_a, "", "", "", ""
    ) && cli_sh22_run_artifact(
        compiler, project, "static-library", static_b, "", "", "", ""
    );
    bool import_generated = cli_sh22_run_artifact(
        compiler, project, "import-library", import_a, "",
        "openc-sh22.dll", "", ""
    ) && cli_sh22_run_artifact(
        compiler, project, "import-library", import_b, "",
        "openc-sh22.dll", "", ""
    );
    bool dll_generated = cli_sh22_run_artifact(
        compiler, project, "dll", dll_a, "console", "openc-sh22.dll",
        manifest, resource_path
    ) && cli_sh22_run_artifact(
        compiler, project, "dll", dll_b, "console", "openc-sh22.dll",
        manifest, resource_path
    );
    bool gui_generated = cli_sh22_run_artifact(
        compiler, project, "exe", gui_a, "windows", "",
        manifest, resource_path
    ) && cli_sh22_run_artifact(
        compiler, project, "exe", gui_b, "windows", "",
        manifest, resource_path
    );
    bool console_generated = cli_sh22_run_artifact(
        compiler, project, "exe", console_a, "console", "", "", ""
    ) && cli_sh22_run_artifact(
        compiler, project, "exe", console_b, "console", "", "", ""
    );

    CliSh22Counts counts = CliSh22Counts{ total = 0, passed = 0 };
    DBuffer checks = d_buffer_create(16384);
    cli_sh22_put_check(checks, counts, "coff_object_generated", object_generated);
    cli_sh22_put_check(checks, counts, "static_library_generated", static_generated);
    cli_sh22_put_check(checks, counts, "import_library_generated", import_generated);
    cli_sh22_put_check(checks, counts, "dll_generated", dll_generated);
    cli_sh22_put_check(checks, counts, "gui_executable_generated", gui_generated);
    cli_sh22_put_check(checks, counts, "console_executable_generated", console_generated);
    cli_sh22_put_check(checks, counts, "coff_deterministic", object_generated && cli_sh22_files_equal(object_a, object_b));
    cli_sh22_put_check(checks, counts, "static_library_deterministic", static_generated && cli_sh22_files_equal(static_a, static_b));
    cli_sh22_put_check(checks, counts, "import_library_deterministic", import_generated && cli_sh22_files_equal(import_a, import_b));
    cli_sh22_put_check(checks, counts, "dll_deterministic", dll_generated && cli_sh22_files_equal(dll_a, dll_b));
    cli_sh22_put_check(checks, counts, "gui_executable_deterministic", gui_generated && cli_sh22_files_equal(gui_a, gui_b));
    cli_sh22_put_check(checks, counts, "console_executable_deterministic", console_generated && cli_sh22_files_equal(console_a, console_b));

    CliSh22Coff coff = CliSh22Coff{
        valid = false, sections = 0, symbols = 0,
        text_relocations = 0, unwind_relocations = 0
    };
    usize object_length = cli_sh22_audit_object(
        object_a, checks, counts, coff
    );
    cli_sh22_audit_static_library(static_a, checks, counts);
    cli_sh22_audit_import_library(import_a, checks, counts);
    usize dll_length = cli_sh22_audit_dll(dll_a, checks, counts);
    cli_sh22_audit_gui(gui_a, checks, counts);
    cli_sh22_audit_console(console_a, checks, counts);

    text probe = path.join(artifacts, "sh22-load-time-probe.exe");
    status probe_written = pe32_write_import_probe(
        probe, "openc-sh22.dll"
    );
    cli_sh22_put_check(checks, counts, "load_time_probe_generated", probe_written.ok);
    i32 probe_exit;
    text probe_output;
    DBuffer probe_command = d_buffer_create(32768);
    native_put_quoted(probe_command, probe);
    status probe_ran = cli_process_run_bounded(
        d_buffer_text(probe_command), cast(usize, 30000),
        out probe_exit, out probe_output
    );
    d_buffer_destroy(probe_command);
    bool probe_passed = false;
    usize observed_probe_exit = 0;
    if probe_ran.ok {
        probe_passed = probe_exit == 42;
        observed_probe_exit = cast(usize, probe_exit);
    }
    cli_sh22_put_check(
        checks, counts, "load_time_dll_import_call",
        probe_written.ok && probe_passed
    );
    i32 dynamic_result = cli_sh22_dynamic_probe(dll_a);
    cli_sh22_put_check(checks, counts, "secure_runtime_dll_call", dynamic_result == 42);
    cli_sh22_put_check(checks, counts, "secure_loader_source_contract", cli_sh22_source_contract(root));
    bool all_generated = object_generated && static_generated &&
        import_generated && dll_generated && gui_generated &&
        console_generated;
    cli_sh22_put_check(checks, counts, "no_external_build_tools", all_generated);

    bool passed = counts.passed == counts.total && counts.total == 40;
    DBuffer report = d_buffer_create(checks.length + 2048);
    d_put(report, "{\n  \"schema\": \"openc.native_pe_coff_audit.v1\",\n");
    d_put(report, "  \"milestone\": \"SH-22_PE_COFF_ECOSYSTEM\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"artifacts\": ");
    cli_json_text(report, artifacts);
    d_put(report, ",\n  \"observations\": {\n    \"coff_bytes\": ");
    d_put_usize(report, object_length);
    d_put(report, ",\n    \"coff_symbols\": ");
    d_put_usize(report, coff.symbols);
    d_put(report, ",\n    \"coff_text_relocations\": ");
    d_put_usize(report, coff.text_relocations);
    d_put(report, ",\n    \"coff_unwind_relocations\": ");
    d_put_usize(report, coff.unwind_relocations);
    d_put(report, ",\n    \"dll_bytes\": ");
    d_put_usize(report, dll_length);
    d_put(report, ",\n    \"dynamic_call_result\": ");
    if dynamic_result < 0 {
        d_put(report, "-");
        d_put_usize(report, cast(usize, 0 - dynamic_result));
    } else {
        d_put_usize(report, cast(usize, dynamic_result));
    }
    d_put(report, ",\n    \"load_time_exit_code\": ");
    d_put_usize(report, observed_probe_exit);
    d_put(report, "\n  },\n  \"checks\": {\n");
    d_put(report, d_buffer_text(checks));
    d_put(report, "\n  },\n  \"checks_passed\": ");
    d_put_usize(report, counts.passed);
    d_put(report, ",\n  \"checks_total\": ");
    d_put_usize(report, counts.total);
    d_put(report, ",\n  \"toolchain\": {\"python\":false,\"d\":false,\"c_compiler\":false,\"tinycc\":false,\"assembler\":false,\"linker\":false},\n  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");
    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    d_buffer_destroy(checks);
    if !report_ok || !written.ok {
        io.error("error: SH-22 PE/COFF audit report could not be written\n");
        return 1;
    }
    io.print("OpenC PE/COFF ecosystem audit: ");
    if passed { io.println("PASS (40/40)"); return 0; }
    io.print("FAIL (");
    io.print(counts.passed);
    io.print("/");
    io.print(counts.total);
    io.println(")");
    return 1;
}
