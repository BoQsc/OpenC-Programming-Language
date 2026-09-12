import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

unsafe bool cli_pe_audit_write_report(text output_path, text input_path, ref CliPeAuditResult result, bool passed) {
    DBuffer report = d_buffer_create(4096);
    d_put(report, "{\n  \"schema\": \"openc.native_pe_audit.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"input\": ");
    cli_json_text(report, input_path);
    d_put(report, ",\n  \"file_bytes\": ");
    d_put_usize(report, result.file_bytes);
    d_put(report, ",\n  \"observations\": {\n    \"sections\": ");
    d_put_usize(report, result.sections);
    d_put(report, ",\n    \"imports\": ");
    d_put_usize(report, result.imports);
    d_put(report, ",\n    \"runtime_functions\": ");
    d_put_usize(report, result.runtime_functions);
    d_put(report, ",\n    \"relocations\": ");
    d_put_usize(report, result.relocations);
    d_put(report, ",\n    \"subsystem\": ");
    d_put_usize(report, result.subsystem);
    d_put(report, "\n  },\n  \"checks\": {\n");
    d_put(report, "    \"dos_and_pe_headers\": ");
    native_put_bool(report, result.dos_and_pe_headers);
    d_put(report, ",\n    \"amd64_pe32_plus\": ");
    native_put_bool(report, result.amd64_pe32_plus);
    d_put(report, ",\n    \"deterministic_headers\": ");
    native_put_bool(report, result.deterministic_headers);
    d_put(report, ",\n    \"section_layout\": ");
    native_put_bool(report, result.section_layout);
    d_put(report, ",\n    \"section_bounds\": ");
    native_put_bool(report, result.section_bounds);
    d_put(report, ",\n    \"write_xor_execute\": ");
    native_put_bool(report, result.write_xor_execute);
    d_put(report, ",\n    \"entry_point\": ");
    native_put_bool(report, result.entry_point);
    d_put(report, ",\n    \"import_directory\": ");
    native_put_bool(report, result.import_directory);
    d_put(report, ",\n    \"kernel32_only\": ");
    native_put_bool(report, result.kernel32_only);
    d_put(report, ",\n    \"expected_imports\": ");
    native_put_bool(report, result.expected_imports);
    d_put(report, ",\n    \"forbidden_crt_absent\": ");
    native_put_bool(report, result.forbidden_crt_absent);
    d_put(report, ",\n    \"relocation_directory\": ");
    native_put_bool(report, result.relocation_directory);
    d_put(report, ",\n    \"tls_directory\": ");
    native_put_bool(report, result.tls_directory);
    d_put(report, ",\n    \"exception_directory\": ");
    native_put_bool(report, result.exception_directory);
    d_put(report, ",\n    \"unwind_version_one\": ");
    native_put_bool(report, result.unwind_version_one);
    d_put(report, ",\n    \"unwind_sorted_nonoverlapping\": ");
    native_put_bool(report, result.unwind_sorted_nonoverlapping);
    d_put(report, "\n  },\n  \"status\": \"");
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
unsafe i32 cli_pe_audit_command() {
    text input_path = "";
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--input=") {
            input_path = cli_remove_prefix(value, "--input=");
        }
        else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        }
        else {
            io.error("usage: openc pe-audit --input=FILE --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(input_path) == 0 || text.byte_length(output_path) == 0 {
        io.error("usage: openc pe-audit --input=FILE --output=REPORT.json\n");
        return 64;
    }
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(input_path, out data, out length);
    CliPeAuditResult result = CliPeAuditResult{
        file_bytes = 0, sections = 0, imports = 0, runtime_functions = 0, relocations = 0, subsystem = 0, dos_and_pe_headers = false, amd64_pe32_plus = false, deterministic_headers = false, section_layout = false, section_bounds = false, write_xor_execute = false, entry_point = false, import_directory = false, kernel32_only = false, expected_imports = false, forbidden_crt_absent = false, relocation_directory = false, tls_directory = false, exception_directory = false, unwind_version_one = false, unwind_sorted_nonoverlapping = false
    };
    if loaded.ok {
        result = cli_pe_audit_image(data, length);
        memory.free(data);
    }
    bool passed = loaded.ok && cli_pe_audit_passed(result);
    if ! cli_pe_audit_write_report(output_path, input_path, result, passed) {
        io.error("error: PE audit report could not be written\n");
        return 1;
    }
    io.print("OpenC PE audit: ");
    if passed {
        io.println("PASS");
    }
    else {
        io.println("FAIL");
    }
    if passed {
        return 0;
    }
    return 1;
}
