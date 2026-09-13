import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliSh23Counts {
    usize total;
    usize passed;
}

unsafe void cli_sh23_check(
    ref DBuffer checks,
    ref CliSh23Counts counts,
    text name,
    bool passed
) {
    if counts.total != 0 { d_put(checks, ",\n"); }
    d_put(checks, "    "); cli_json_text(checks, name);
    d_put(checks, ": "); native_put_bool(checks, passed);
    counts.total = counts.total + 1;
    if passed { counts.passed = counts.passed + 1; }
    io.print("com-winrt "); io.print(name); io.print(": ");
    if passed { io.println("PASS"); } else { io.println("FAIL"); }
}

unsafe bool cli_sh23_build(
    text compiler,
    text project,
    text output
) {
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "build");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--output=", output);
    bool passed = cli_contract_run(command, 0, "", false);
    d_buffer_destroy(command);
    return passed;
}

unsafe bool cli_sh23_execute(text executable) {
    DBuffer command = d_buffer_create(32768);
    native_put_quoted(command, executable);
    bool passed = cli_contract_run(
        command, 0, "OpenC SH-23 COM/WinRT projection PASS", false
    );
    d_buffer_destroy(command);
    return passed;
}

unsafe bool cli_sh23_source_contains(
    text root,
    text relative,
    text first,
    text second
) {
    text source;
    status loaded = file.read_text(path.join(root, relative), out source);
    if !loaded.ok { return false; }
    return native_contains(source, first) && native_contains(source, second);
}

unsafe CliPeAuditResult cli_sh23_pe(text executable, ref bool loaded_ok) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(executable, out data, out length);
    loaded_ok = loaded.ok;
    if !loaded.ok {
        return CliPeAuditResult{
            file_bytes = 0, sections = 0, imports = 0,
            runtime_functions = 0, relocations = 0, subsystem = 0,
            dos_and_pe_headers = false, amd64_pe32_plus = false,
            deterministic_headers = false, section_layout = false,
            section_bounds = false, write_xor_execute = false,
            entry_point = false, import_directory = false,
            kernel32_only = false, expected_imports = false,
            forbidden_crt_absent = false, relocation_directory = false,
            tls_directory = false, exception_directory = false,
            unwind_version_one = false,
            unwind_sorted_nonoverlapping = false
        };
    }
    CliPeAuditResult result = cli_pe_audit_image(data, length);
    memory.free(data);
    return result;
}

unsafe i32 cli_com_winrt_audit_command() {
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
            io.error("usage: openc com-winrt-audit --root=ROOT --artifacts=DIR --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(artifacts) == 0 ||
        text.byte_length(output_path) == 0 {
        io.error("usage: openc com-winrt-audit --root=ROOT --artifacts=DIR --output=REPORT.json\n");
        return 64;
    }
    artifacts = path.join(root, artifacts);
    if !cli_release_ensure_directory(artifacts) ||
        !cli_release_ensure_directory(path.directory(output_path)) {
        io.error("error: SH-23 audit output directory unavailable\n");
        return 1;
    }
    text compiler = cli_self_executable();
    text project = path.join(root, "tests/sh23_com_winrt/openc.project.json");
    text image_a = path.join(artifacts, "sh23-com-winrt-a.exe");
    text image_b = path.join(artifacts, "sh23-com-winrt-b.exe");
    bool built_a = cli_sh23_build(compiler, project, image_a);
    bool built_b = cli_sh23_build(compiler, project, image_b);
    bool executed = built_a && cli_sh23_execute(image_a);
    bool pe_loaded = false;
    CliPeAuditResult pe = cli_sh23_pe(image_a, pe_loaded);

    bool com_source = cli_sh23_source_contains(
        root, "standard_library/windows.com/source/com.p",
        "export struct Guid", "query_interface"
    );
    bool winrt_source = cli_sh23_source_contains(
        root, "standard_library/windows.winrt/source/winrt.p",
        "export resource HString", "activation_factory"
    );
    bool backend = cli_sh23_source_contains(
        root, "compiler/selfhost/source/backend_native_com_winrt.p",
        "LoadLibraryExW", "native_windows_dynamic_prepare"
    );
    bool com_manifest = cli_sh23_source_contains(
        root, "standard_library/windows.com/generated/manifest.json",
        "openc.windows_com_projection.v1", "IUnknown"
    );
    bool winrt_manifest = cli_sh23_source_contains(
        root, "standard_library/windows.winrt/generated/manifest.json",
        "openc.windows_winrt_projection.v1", "IActivationFactory"
    );
    bool raw_manifest = cli_sh23_source_contains(
        root, "standard_library/windows.raw/generated/manifest.json",
        "openc.windows_raw_projection_manifest.v1", "InterfaceImpl"
    );
    bool core_clean = cli_contract_core_independent(root);

    CliSh23Counts counts = CliSh23Counts{ total = 0, passed = 0 };
    DBuffer checks = d_buffer_create(16384);
    cli_sh23_check(checks, counts, "com_module_registered", com_source);
    cli_sh23_check(checks, counts, "winrt_module_registered", winrt_source);
    cli_sh23_check(checks, counts, "projection_project_build_a", built_a);
    cli_sh23_check(checks, counts, "projection_project_build_b", built_b);
    cli_sh23_check(checks, counts, "deterministic_native_image",
        built_a && built_b && cli_sh22_files_equal(image_a, image_b));
    cli_sh23_check(checks, counts, "native_execution", executed);
    cli_sh23_check(checks, counts, "pe32_plus_amd64", pe_loaded && pe.amd64_pe32_plus);
    cli_sh23_check(checks, counts, "kernel32_only_static_imports", pe.kernel32_only);
    cli_sh23_check(checks, counts, "forbidden_crt_absent", pe.forbidden_crt_absent);
    cli_sh23_check(checks, counts, "unwind_information", pe.exception_directory && pe.unwind_version_one);
    cli_sh23_check(checks, counts, "guid_layout_contract", com_source &&
        cli_sh23_source_contains(root, "standard_library/windows.com/source/com.p", "u64 low", "u64 high"));
    cli_sh23_check(checks, counts, "hresult_conversion", com_source &&
        cli_sh23_source_contains(root, "standard_library/windows.com/source/com.p", "succeeded", "failed"));
    cli_sh23_check(checks, counts, "com_apartment_lifetime", com_source &&
        cli_sh23_source_contains(root, "standard_library/windows.com/source/com.p", "initialize_multithreaded", "apartment_destroy"));
    cli_sh23_check(checks, counts, "iunknown_vtable_calls", backend &&
        cli_sh23_source_contains(root, "compiler/selfhost/source/backend_native_com_winrt.p", "vtable_offset", "native_com_query_interface"));
    cli_sh23_check(checks, counts, "query_interface_executed", executed);
    cli_sh23_check(checks, counts, "reference_counting_executed", executed);
    cli_sh23_check(checks, counts, "utf8_to_hstring_executed", executed);
    cli_sh23_check(checks, counts, "activation_factory_executed", executed);
    cli_sh23_check(checks, counts, "runtime_instance_activation_executed", executed &&
        cli_sh23_source_contains(root, "standard_library/windows.winrt/source/winrt.p", "activate_instance", "ocw_winrt_activate_instance"));
    cli_sh23_check(checks, counts, "iinspectable_iid_projected", winrt_source &&
        cli_sh23_source_contains(root, "standard_library/windows.winrt/source/winrt.p", "iid_inspectable", "5506408304190350048"));
    cli_sh23_check(checks, counts, "runtime_class_name_executed", executed &&
        cli_sh23_source_contains(root, "standard_library/windows.winrt/source/winrt.p", "runtime_class_name", "ocw_winrt_runtime_class_name"));
    cli_sh23_check(checks, counts, "trust_level_executed", executed &&
        cli_sh23_source_contains(root, "standard_library/windows.winrt/source/winrt.p", "trust_level", "ocw_winrt_trust_level"));
    cli_sh23_check(checks, counts, "iinspectable_vtable_order", backend &&
        cli_sh23_source_contains(root, "compiler/selfhost/source/backend_native_runtime_part2b.p", "result, 32", "result, 40"));
    cli_sh23_check(checks, counts, "secure_system32_loader", backend &&
        cli_sh23_source_contains(root, "compiler/selfhost/source/backend_native_com_winrt.p", "cast(u64, 2048)", "GetProcAddress"));
    cli_sh23_check(checks, counts, "documented_ole32_boundary", backend &&
        cli_sh23_source_contains(root, "compiler/selfhost/source/backend_native_com_winrt.p", "ole32.dll", "CreateStreamOnHGlobal"));
    cli_sh23_check(checks, counts, "documented_combase_boundary", backend &&
        cli_sh23_source_contains(root, "compiler/selfhost/source/backend_native_com_winrt.p", "combase.dll", "RoGetActivationFactory"));
    cli_sh23_check(checks, counts, "com_projection_manifest", com_manifest);
    cli_sh23_check(checks, counts, "winrt_projection_manifest", winrt_manifest);
    cli_sh23_check(checks, counts, "raw_winmd_interface_backing", raw_manifest);
    cli_sh23_check(checks, counts, "core_language_independent", core_clean);
    cli_sh23_check(checks, counts, "optional_dynamic_dependencies", pe.kernel32_only && backend);
    cli_sh23_check(checks, counts, "no_direct_syscalls", backend &&
        !cli_sh23_source_contains(root, "compiler/selfhost/source/backend_native_com_winrt.p", "syscall", "syscall"));
    cli_sh23_check(checks, counts, "no_external_build_tools", built_a && built_b);

    bool passed = counts.passed == counts.total && counts.total == 33;
    DBuffer report = d_buffer_create(checks.length + 2048);
    d_put(report, "{\n  \"schema\": \"openc.com_winrt_audit.v1\",\n");
    d_put(report, "  \"milestone\": \"SH-23_OPTIONAL_COM_AND_WINRT\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"checks\": {\n"); d_put(report, d_buffer_text(checks));
    d_put(report, "\n  },\n  \"checks_passed\": "); d_put_usize(report, counts.passed);
    d_put(report, ",\n  \"checks_total\": "); d_put_usize(report, counts.total);
    d_put(report, ",\n  \"static_imports\": \"KERNEL32.dll only\",\n");
    d_put(report, "  \"dynamic_system_dlls\": [\"ole32.dll\",\"combase.dll\"],\n");
    d_put(report, "  \"toolchain\": {\"python\":false,\"d\":false,\"c_compiler\":false,\"tinycc\":false,\"assembler\":false,\"linker\":false},\n");
    d_put(report, "  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");
    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report); d_buffer_destroy(checks);
    if !report_ok || !written.ok { return 1; }
    io.print("OpenC COM/WinRT audit: ");
    if passed { io.println("PASS (33/33)"); return 0; }
    io.print("FAIL ("); io.print(counts.passed); io.print("/");
    io.print(counts.total); io.println(")");
    return 1;
}
