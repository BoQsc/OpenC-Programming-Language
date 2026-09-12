import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

text cli_test_kind_name(usize kind) {
    if kind == 0 { return "PASS"; }
    if kind == 1 { return "LANGUAGE_FAILURE"; }
    if kind == 2 { return "ASSERTION_FAILURE"; }
    return "INFRASTRUCTURE_FAILURE";
}

unsafe void cli_test_report_header(
    ref DBuffer report,
    text manifest_path,
    bool no_run,
    bool list_only,
    usize jobs,
    text target
) {
    d_put(report, "{\n  \"schema\": \"openc.test_result.v1\",\n");
    d_put(report, "  \"implementation\": {\n");
    d_put(report, "    \"name\": \"OpenC\",\n");
    d_put(report, "    \"version\": ");
    cli_json_text(report, cli_version());
    d_put(report, ",\n    \"language\": \"OpenC\"\n  },\n");
    d_put(report, "  \"target\": ");
    cli_json_text(report, target);
    d_put(report, ",\n  \"manifest\": ");
    cli_json_text(report, manifest_path);
    d_put(report, ",\n  \"command\": \"openc test\",\n");
    d_put(report, "  \"mode\": \"");
    if list_only { d_put(report, "list"); }
    else if no_run { d_put(report, "no-run"); }
    else { d_put(report, "run"); }
    d_put(report, "\",\n  \"requested_jobs\": ");
    d_put_usize(report, jobs);
    d_put(report, ",\n  \"execution_order\": \"name-sorted\",\n");
    d_put(report, "  \"results\": [\n");
}

unsafe void cli_test_report_case(
    ref DBuffer report,
    bool first,
    text name,
    text project_path,
    usize expected_exit,
    bool list_only,
    ref CliTestOutcome outcome
) {
    if !first { d_put(report, ",\n"); }
    d_put(report, "    {\n      \"name\": ");
    cli_json_text(report, name);
    d_put(report, ",\n      \"project\": ");
    cli_json_text(report, project_path);
    d_put(report, ",\n      \"expected_exit\": ");
    d_put_usize(report, expected_exit);
    if list_only {
        d_put(report, ",\n      \"status\": \"DISCOVERED\"");
    } else {
        d_put(report, ",\n      \"status\": ");
        cli_json_text(report, cli_test_kind_name(outcome.kind));
        d_put(report, ",\n      \"source_hash\": {\n");
        d_put(report, "        \"algorithm\": \"openc-stable32\",\n");
        d_put(report, "        \"value\": \"");
        cli_put_hex_usize(report, outcome.source_hash);
        d_put(report, "\"\n      },\n");
        d_put(report, "      \"exit_code\": ");
        d_put_usize(report, cast(usize, outcome.exit_code));
        d_put(report, ",\n      \"stdout\": ");
        cli_json_text(report, outcome.output);
        d_put(report, ",\n      \"diagnostics\": ");
        cli_json_text(report, outcome.diagnostics);
    }
    d_put(report, "\n    }");
}

unsafe i32 cli_test_finish_report(
    ref DBuffer report,
    text report_path,
    usize selected,
    usize passed,
    usize language_failures,
    usize assertion_failures,
    usize infrastructure_failures,
    bool list_only
) {
    d_put(report, "\n  ],\n  \"summary\": {\n");
    d_put(report, "    \"selected\": ");
    d_put_usize(report, selected);
    d_put(report, ",\n    \"passed\": ");
    d_put_usize(report, passed);
    d_put(report, ",\n    \"language_failures\": ");
    d_put_usize(report, language_failures);
    d_put(report, ",\n    \"assertion_failures\": ");
    d_put_usize(report, assertion_failures);
    d_put(report, ",\n    \"infrastructure_failures\": ");
    d_put_usize(report, infrastructure_failures);
    d_put(report, "\n  },\n  \"status\": \"");
    if selected == 0 { d_put(report, "NO_TESTS"); }
    else if list_only || (
        language_failures == 0 &&
        assertion_failures == 0 &&
        infrastructure_failures == 0
    ) {
        d_put(report, "PASS");
    } else {
        d_put(report, "FAIL");
    }
    d_put(report, "\"\n}\n");
    if !report.ok {
        io.error("error: test report capacity exceeded\n");
        return 1;
    }
    if text.byte_length(report_path) != 0 {
        status written = file.write_text(
            report_path, d_buffer_text(report)
        );
        if !written.ok {
            io.error("error: test report could not be written\n");
            return 1;
        }
    }
    if selected == 0 {
        io.println("OpenC test: NO_TESTS");
        return 1;
    }
    if list_only {
        io.print("OpenC test: ");
        io.print(selected);
        io.println(" test(s) discovered");
        return 0;
    }
    io.print("OpenC test: ");
    io.print(passed);
    io.print("/");
    io.print(selected);
    io.println(" passed");
    if language_failures != 0 ||
        assertion_failures != 0 ||
        infrastructure_failures != 0 {
        return 1;
    }
    return 0;
}

unsafe i32 cli_test_direct(
    text project_path,
    text report_path,
    text filter,
    bool list_only,
    bool no_run,
    usize jobs,
    text target
) {
    text name = project_path;
    DBuffer report = d_buffer_create(4194304);
    cli_test_report_header(
        report, "", no_run, list_only, jobs, target
    );
    usize selected = 0;
    usize passed = 0;
    usize language_failures = 0;
    usize assertion_failures = 0;
    usize infrastructure_failures = 0;
    if text.byte_length(filter) == 0 || native_contains(name, filter) {
        selected = 1;
        if list_only {
            io.println(name);
            CliTestOutcome listed = CliTestOutcome{
                kind = 0, exit_code = 0, source_hash = 0,
                output = "", diagnostics = ""
            };
            cli_test_report_case(
                report, true, name, project_path, 0, true, listed
            );
        } else {
            CliTestOutcome outcome = cli_test_execute(
                project_path, 0, no_run, 0
            );
            io.print("test ");
            io.print(name);
            io.print(": ");
            io.println(cli_test_kind_name(outcome.kind));
            if outcome.kind == 0 { passed = 1; }
            if outcome.kind == 1 { language_failures = 1; }
            if outcome.kind == 2 { assertion_failures = 1; }
            if outcome.kind == 3 { infrastructure_failures = 1; }
            cli_test_report_case(
                report, true, name, project_path, 0, false, outcome
            );
        }
    }
    i32 result = cli_test_finish_report(
        report, report_path, selected, passed,
        language_failures, assertion_failures,
        infrastructure_failures, list_only
    );
    d_buffer_destroy(report);
    return result;
}

unsafe i32 cli_test_manifest(
    text manifest_path,
    text report_path,
    text filter,
    bool list_only,
    bool no_run,
    usize jobs,
    text target
) {
    text manifest;
    status loaded = file.read_text(manifest_path, out manifest);
    if !loaded.ok {
        io.error("error: test manifest could not be read\n");
        return 1;
    }
    PackedBuffer tests = PackedBuffer{
        length = 0,
        capacity = text.byte_length(manifest) + 1
    };
    ptr byte test_data = memory.alloc(
        tests.capacity * record_stride()
    );
    scope memory.free(test_data);
    if !cli_test_parse_manifest(manifest, test_data, tests) {
        io.error("error: test manifest is invalid or empty\n");
        return 1;
    }
    project_sort_modules(manifest, test_data, tests);
    text manifest_root = path.directory(manifest_path);
    DBuffer report = d_buffer_create(4194304);
    cli_test_report_header(
        report, manifest_path, no_run, list_only, jobs, target
    );
    usize selected = 0;
    usize passed = 0;
    usize language_failures = 0;
    usize assertion_failures = 0;
    usize infrastructure_failures = 0;
    usize test_record = 0;
    while test_record < tests.length {
        text name = project_slice(
            manifest,
            read_record_field(test_data, test_record, 0),
            read_record_field(test_data, test_record, 1)
        );
        if text.byte_length(filter) != 0 &&
            !native_contains(name, filter) {
            test_record = test_record + 1;
            continue;
        }
        text relative_project = project_slice(
            manifest,
            read_record_field(test_data, test_record, 2),
            read_record_field(test_data, test_record, 3)
        );
        text project_path = path.join(
            manifest_root, relative_project
        );
        usize expected_exit = read_record_field(
            test_data, test_record, 4
        );
        if list_only {
            io.println(name);
            CliTestOutcome listed = CliTestOutcome{
                kind = 0, exit_code = 0, source_hash = 0,
                output = "", diagnostics = ""
            };
            cli_test_report_case(
                report, selected == 0, name, project_path,
                expected_exit, true, listed
            );
        } else {
            CliTestOutcome outcome = cli_test_execute(
                project_path, expected_exit, no_run, selected
            );
            io.print("test ");
            io.print(name);
            io.print(": ");
            io.println(cli_test_kind_name(outcome.kind));
            if outcome.kind == 0 { passed = passed + 1; }
            if outcome.kind == 1 {
                language_failures = language_failures + 1;
            }
            if outcome.kind == 2 {
                assertion_failures = assertion_failures + 1;
            }
            if outcome.kind == 3 {
                infrastructure_failures =
                    infrastructure_failures + 1;
            }
            cli_test_report_case(
                report, selected == 0, name, project_path,
                expected_exit, false, outcome
            );
        }
        selected = selected + 1;
        test_record = test_record + 1;
    }
    i32 result = cli_test_finish_report(
        report, report_path, selected, passed,
        language_failures, assertion_failures,
        infrastructure_failures, list_only
    );
    d_buffer_destroy(report);
    return result;
}

unsafe i32 cli_test_command() {
    text manifest_path = "";
    text project_path = "";
    text report_path = "";
    text filter = "";
    text target = "windows-x86_64-hosted";
    bool list_only = false;
    bool no_run = false;
    usize jobs = 1;
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--manifest=") {
            manifest_path = cli_remove_prefix(value, "--manifest=");
        } else if cli_has_prefix(value, "--project=") {
            project_path = cli_remove_prefix(value, "--project=");
        } else if cli_has_prefix(value, "--report=") {
            report_path = cli_remove_prefix(value, "--report=");
        } else if cli_has_prefix(value, "--filter=") {
            filter = cli_remove_prefix(value, "--filter=");
        } else if cli_has_prefix(value, "--jobs=") {
            jobs = native_parse_usize(
                cli_remove_prefix(value, "--jobs=")
            );
        } else if cli_has_prefix(value, "--target=") {
            target = cli_remove_prefix(value, "--target=");
        } else if value == "--list" {
            list_only = true;
        } else if value == "--no-run" {
            no_run = true;
        } else {
            io.error("usage: openc test (--manifest=TESTS.json|--project=PROJECT) [--list] [--filter=TEXT] [--jobs=N] [--target=TARGET] [--report=RESULT.json] [--no-run]\n");
            return 64;
        }
        argument = argument + 1;
    }
    if jobs == 0 ||
        target != "windows-x86_64-hosted" ||
        (text.byte_length(manifest_path) == 0 &&
            text.byte_length(project_path) == 0) ||
        (text.byte_length(manifest_path) != 0 &&
            text.byte_length(project_path) != 0) {
        io.error("usage: openc test (--manifest=TESTS.json|--project=PROJECT) [--list] [--filter=TEXT] [--jobs=N] [--target=windows-x86_64-hosted] [--report=RESULT.json] [--no-run]\n");
        return 64;
    }
    if text.byte_length(project_path) != 0 {
        return cli_test_direct(
            project_path, report_path, filter, list_only,
            no_run, jobs, target
        );
    }
    return cli_test_manifest(
        manifest_path, report_path, filter, list_only,
        no_run, jobs, target
    );
}
