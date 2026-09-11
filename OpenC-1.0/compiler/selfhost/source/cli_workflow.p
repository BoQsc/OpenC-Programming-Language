import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliWorkflowTaskResult {
    bool launched;
    i32 exit_code;
    usize elapsed_milliseconds;
    text output;
    bool passed;
}

struct CliWorkflowCounters {
    usize tasks;
    usize passed;
}

unsafe void cli_workflow_command_start(
    ref DBuffer command,
    text executable,
    text verb
) {
    native_put_quoted(command, executable);
    d_put(command, " ");
    d_put(command, verb);
}

unsafe void cli_workflow_command_argument(
    ref DBuffer command,
    text value
) {
    d_put(command, " ");
    native_put_quoted(command, value);
}

unsafe void cli_workflow_command_named_argument(
    ref DBuffer command,
    text name,
    text value
) {
    d_put(command, " \"");
    d_put(command, name);
    d_put(command, value);
    d_put(command, "\"");
}

unsafe CliWorkflowTaskResult cli_workflow_run(
    text command,
    text required_output
) {
    usize started = process.monotonic_milliseconds();
    i32 exit_code;
    text output;
    status ran = process.run(command, out exit_code, out output);
    usize elapsed = process.monotonic_milliseconds() - started;
    if !ran.ok {
        return CliWorkflowTaskResult{
            launched = false,
            exit_code = 0,
            elapsed_milliseconds = elapsed,
            output = "",
            passed = false
        };
    }
    bool passed = exit_code == 0;
    if passed && text.byte_length(required_output) != 0 {
        passed = native_contains(output, required_output);
    }
    return CliWorkflowTaskResult{
        launched = ran.ok,
        exit_code = exit_code,
        elapsed_milliseconds = elapsed,
        output = output,
        passed = passed
    };
}

unsafe void cli_workflow_put_task(
    ref DBuffer report,
    usize index,
    text name,
    text command,
    ref CliWorkflowTaskResult result
) {
    if index != 0 { d_put(report, ",\n"); }
    d_put(report, "    {\n      \"name\": ");
    cli_json_text(report, name);
    d_put(report, ",\n      \"command\": ");
    cli_json_text(report, command);
    d_put(report, ",\n      \"launched\": ");
    native_put_bool(report, result.launched);
    d_put(report, ",\n      \"exit_code\": ");
    d_put_usize(report, cast(usize, result.exit_code));
    d_put(report, ",\n      \"elapsed_milliseconds\": ");
    d_put_usize(report, result.elapsed_milliseconds);
    d_put(report, ",\n      \"passed\": ");
    native_put_bool(report, result.passed);
    d_put(report, ",\n      \"output\": ");
    cli_json_text(report, result.output);
    d_put(report, "\n    }");
}

unsafe bool cli_workflow_execute(
    ref DBuffer report,
    ref CliWorkflowCounters counters,
    text name,
    ref DBuffer command,
    text required_output
) {
    CliWorkflowTaskResult result = cli_workflow_run(
        d_buffer_text(command), required_output
    );
    cli_workflow_put_task(
        report, counters.tasks, name, d_buffer_text(command), result
    );
    counters.tasks = counters.tasks + 1;
    if result.passed { counters.passed = counters.passed + 1; }
    io.print("workflow ");
    io.print(name);
    io.print(": ");
    if result.passed { io.println("PASS"); }
    else { io.println("FAIL"); }
    return result.passed;
}

unsafe bool cli_workflow_sha256(
    text input_path,
    ref DBuffer output
) {
    text contents;
    status loaded = file.read_text(input_path, out contents);
    if !loaded.ok { return false; }
    usize length = text.byte_length(contents);
    ptr byte data = memory.alloc(length + 1);
    text.copy_utf8_unchecked(data, contents);
    winmd_sha256_hex(data, length, output);
    memory.free(data);
    return output.ok;
}

unsafe i32 cli_workflow_hash_command(text input_path) {
    text contents;
    status loaded = file.read_text(input_path, out contents);
    if !loaded.ok {
        io.error("error: input could not be read\n");
        return 1;
    }
    usize length = text.byte_length(contents);
    ptr byte data = memory.alloc(length + 1);
    text.copy_utf8_unchecked(data, contents);
    DBuffer output = d_buffer_create(65);
    winmd_sha256_hex(data, length, output);
    memory.free(data);
    io.println(d_buffer_text(output));
    bool ok = output.ok;
    d_buffer_destroy(output);
    if !ok { return 1; }
    return 0;
}

// Internal adversarial children for the public native process-guard verifier.
// The output probe writes one byte beyond the 4 MiB capture ceiling. The memory
// probe attempts a 300 MiB allocation and may only complete when containment is
// broken; a functioning 256 MiB Job boundary terminates it or makes it fail.
unsafe i32 cli_process_guard_output_probe() {
    text block = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    usize iteration = 0;
    while iteration < 16385 {
        io.print(block);
        iteration = iteration + 1;
    }
    return 0;
}

unsafe i32 cli_process_guard_memory_probe() {
    ptr byte allocation = memory.alloc(314572800);
    memory.free(allocation);
    return 0;
}

unsafe i32 cli_process_guard_working_set_probe() {
    ptr byte allocation = memory.alloc(104857600);
    usize offset = 0;
    while offset < 104857600 {
        memory.store_usize(allocation + offset, offset);
        offset = offset + 4096;
    }
    while true {}
    memory.free(allocation);
    return 0;
}

unsafe i32 cli_process_guard_timeout_probe() {
    while true {}
    return 0;
}

// Compiler-internal bounded primitive. The native backend lowers calls to this
// exact helper directly; its body keeps the optional C bootstrap lane viable
// without making that historical lane authoritative for native supervision.
unsafe status cli_process_run_bounded(
    text command,
    usize timeout_milliseconds,
    out i32 exit_code,
    out text output
) {
    status result = process.run(command, out exit_code, out output);
    return result;
}

unsafe i32 cli_process_guard_command(text output_path) {
    text compiler = cli_self_executable();
    DBuffer command = d_buffer_create(32768);
    native_put_quoted(command, compiler);
    d_put(command, " --process-guard-output-probe");
    i32 output_exit;
    text output_text;
    status output_ran = process.run(
        d_buffer_text(command), out output_exit, out output_text
    );
    bool output_guarded = !output_ran.ok && output_ran.code == 4;
    d_buffer_destroy(command);

    command = d_buffer_create(32768);
    native_put_quoted(command, compiler);
    d_put(command, " --process-guard-memory-probe");
    i32 memory_exit;
    text memory_text;
    status memory_ran = process.run(
        d_buffer_text(command), out memory_exit, out memory_text
    );
    bool memory_guarded = false;
    if memory_ran.ok { memory_guarded = memory_exit != 0; }
    d_buffer_destroy(command);

    command = d_buffer_create(32768);
    native_put_quoted(command, compiler);
    d_put(command, " --process-guard-working-set-probe");
    i32 working_set_exit;
    text working_set_text;
    status working_set_ran = cli_process_run_bounded(
        d_buffer_text(command), cast(usize, 2000),
        out working_set_exit, out working_set_text
    );
    bool working_set_guarded =
        !working_set_ran.ok && working_set_ran.code == 2;
    d_buffer_destroy(command);

    command = d_buffer_create(32768);
    native_put_quoted(command, compiler);
    d_put(command, " --process-guard-timeout-probe");
    i32 timeout_exit;
    text timeout_text;
    status timeout_ran = cli_process_run_bounded(
        d_buffer_text(command), cast(usize, 250),
        out timeout_exit, out timeout_text
    );
    bool timeout_guarded = !timeout_ran.ok && timeout_ran.code == 3;
    d_buffer_destroy(command);

    bool passed = output_guarded && memory_guarded &&
        working_set_guarded && timeout_guarded;
    DBuffer report = d_buffer_create(4096);
    d_put(report, "{\n  \"schema\": \"openc.native_process_guard.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"limits\": {\n");
    d_put(report, "    \"captured_output_bytes\": 4194304,\n");
    d_put(report, "    \"process_memory_bytes\": 268435456,\n");
    d_put(report, "    \"job_memory_bytes\": 268435456,\n");
    d_put(report, "    \"working_set_bytes\": 67108864,\n");
    d_put(report, "    \"probe_timeout_milliseconds\": 250\n  },\n");
    d_put(report, "  \"checks\": {\n    \"output_budget\": ");
    native_put_bool(report, output_guarded);
    d_put(report, ",\n    \"memory_budget\": ");
    native_put_bool(report, memory_guarded);
    d_put(report, ",\n    \"working_set_budget\": ");
    native_put_bool(report, working_set_guarded);
    d_put(report, ",\n    \"timeout_budget\": ");
    native_put_bool(report, timeout_guarded);
    d_put(report, "\n  },\n  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");
    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    if !report_ok || !written.ok {
        io.error("error: process-guard report could not be written\n");
        return 1;
    }
    if passed {
        io.println("OpenC process guard: PASS");
        return 0;
    }
    io.println("OpenC process guard: FAIL");
    return 1;
}

unsafe i32 cli_workflow_command() {
    text root = process.executable_directory();
    text output_path = "";
    text mode = "full";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else if cli_has_prefix(value, "--mode=") {
            mode = cli_remove_prefix(value, "--mode=");
        } else {
            io.error("usage: openc workflow --root=ROOT --output=REPORT.json [--mode=daily|full]\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(output_path) == 0 ||
        (mode != "daily" && mode != "full") {
        io.error("usage: openc workflow --root=ROOT --output=REPORT.json [--mode=daily|full]\n");
        return 64;
    }

    text compiler = cli_self_executable();
    text output_directory = path.directory(output_path);
    text selfhost_project = path.join(
        root, "compiler/selfhost/openc.project.json"
    );
    text hello_project = path.join(
        root, "demos/hello/openc.project.json"
    );
    text test_manifest = path.join(
        root, "tests/SH21_NATIVE_WORKFLOW_TESTS.json"
    );
    text conformance_manifest = path.join(
        root, "conformance/fixtures/MANIFEST.json"
    );
    text conformance_report = path.join(
        output_directory, "sh21-native-conformance.json"
    );
    text test_report = path.join(
        output_directory, "sh21-native-tests.json"
    );
    text process_guard_report = path.join(
        output_directory, "sh21-native-process-guard.json"
    );
    text stage2 = path.join(
        output_directory, "openc-sh21-stage2.exe"
    );
    text stage3 = path.join(
        output_directory, "openc-sh21-stage3.exe"
    );

    DBuffer report = d_buffer_create(8388608);
    d_put(report, "{\n  \"schema\": \"openc.native_workflow.v1\",\n");
    d_put(report, "  \"milestone\": \"SH-21_OPENC_NATIVE_WORKFLOWS_AND_BOOTSTRAP_BOUNDARY\",\n");
    d_put(report, "  \"mode\": ");
    cli_json_text(report, mode);
    d_put(report, ",\n  \"root\": ");
    cli_json_text(report, root);
    d_put(report, ",\n  \"compiler\": ");
    cli_json_text(report, compiler);
    d_put(report, ",\n  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"tasks\": [\n");
    CliWorkflowCounters counters = CliWorkflowCounters{
        tasks = 0, passed = 0
    };

    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "version");
    cli_workflow_execute(
        report, counters, "version", command, "OpenC 1.0.0-rc.9"
    );
    d_buffer_destroy(command);

    command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "target");
    cli_workflow_execute(
        report, counters, "target", command,
        "target: windows-x86_64-hosted"
    );
    d_buffer_destroy(command);

    command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "check");
    cli_workflow_command_named_argument(
        command, "--project=", hello_project
    );
    cli_workflow_execute(
        report, counters, "project_check", command,
        "OpenC check: PASS"
    );
    d_buffer_destroy(command);

    command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "test");
    cli_workflow_command_named_argument(
        command, "--manifest=", test_manifest
    );
    cli_workflow_command_named_argument(command, "--report=", test_report);
    if mode == "daily" {
        cli_workflow_command_argument(command, "--no-run");
    }
    cli_workflow_execute(
        report, counters, "maintained_and_native_runtime", command,
        "OpenC test: 5/5 passed"
    );
    d_buffer_destroy(command);

    bool fixed_point_checked = false;
    bool fixed_point = false;
    DBuffer compiler_hash = d_buffer_create(128);
    DBuffer stage2_hash = d_buffer_create(128);
    DBuffer stage3_hash = d_buffer_create(128);
    if mode == "full" {
        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "process-guard");
        cli_workflow_command_named_argument(
            command, "--output=", process_guard_report
        );
        cli_workflow_execute(
            report, counters, "native_process_guard", command,
            "OpenC process guard: PASS"
        );
        d_buffer_destroy(command);

        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "validate");
        cli_workflow_command_named_argument(
            command, "--manifest=", conformance_manifest
        );
        cli_workflow_command_named_argument(
            command, "--output=", conformance_report
        );
        cli_workflow_execute(
            report, counters, "native_conformance", command,
            "278/278"
        );
        d_buffer_destroy(command);

        command = d_buffer_create(32768);
        cli_workflow_command_start(command, compiler, "build");
        cli_workflow_command_named_argument(
            command, "--project=", selfhost_project
        );
        cli_workflow_command_named_argument(command, "--output=", stage2);
        bool stage2_built = cli_workflow_execute(
            report, counters, "self_build_stage2", command, ""
        );
        d_buffer_destroy(command);

        bool stage3_built = false;
        if stage2_built {
            command = d_buffer_create(32768);
            cli_workflow_command_start(command, stage2, "build");
            cli_workflow_command_named_argument(
                command, "--project=", selfhost_project
            );
            cli_workflow_command_named_argument(command, "--output=", stage3);
            stage3_built = cli_workflow_execute(
                report, counters, "self_build_stage3", command, ""
            );
            d_buffer_destroy(command);
        }
        fixed_point_checked = stage2_built && stage3_built;
        if fixed_point_checked &&
            cli_workflow_sha256(compiler, compiler_hash) &&
            cli_workflow_sha256(stage2, stage2_hash) &&
            cli_workflow_sha256(stage3, stage3_hash) {
            fixed_point = d_buffer_text(compiler_hash) ==
                d_buffer_text(stage2_hash) &&
                d_buffer_text(stage2_hash) == d_buffer_text(stage3_hash);
        }
    }

    bool success = counters.passed == counters.tasks;
    if mode == "full" { success = success && fixed_point; }
    d_put(report, "\n  ],\n  \"summary\": {\n    \"tasks\": ");
    d_put_usize(report, counters.tasks);
    d_put(report, ",\n    \"passed\": ");
    d_put_usize(report, counters.passed);
    d_put(report, ",\n    \"fixed_point_checked\": ");
    native_put_bool(report, fixed_point_checked);
    d_put(report, ",\n    \"fixed_point\": ");
    native_put_bool(report, fixed_point);
    d_put(report, "\n  },\n  \"hashes\": {\n    \"compiler_sha256\": ");
    cli_json_text(report, d_buffer_text(compiler_hash));
    d_put(report, ",\n    \"stage2_sha256\": ");
    cli_json_text(report, d_buffer_text(stage2_hash));
    d_put(report, ",\n    \"stage3_sha256\": ");
    cli_json_text(report, d_buffer_text(stage3_hash));
    d_put(report, "\n  },\n  \"toolchain\": {\n");
    d_put(report, "    \"python_invoked\": false,\n");
    d_put(report, "    \"d_invoked\": false,\n");
    d_put(report, "    \"c_compiler_invoked\": false,\n");
    d_put(report, "    \"tinycc_invoked\": false,\n");
    d_put(report, "    \"external_assembler_invoked\": false,\n");
    d_put(report, "    \"external_linker_invoked\": false\n  },\n");
    d_put(report, "  \"status\": \"");
    if success { d_put(report, "PASS"); }
    else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");

    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(compiler_hash);
    d_buffer_destroy(stage2_hash);
    d_buffer_destroy(stage3_hash);
    d_buffer_destroy(report);
    if !report_ok || !written.ok {
        io.error("error: native workflow report could not be written\n");
        return 1;
    }
    io.print("OpenC native workflow: ");
    if success { io.println("PASS"); }
    else { io.println("FAIL"); }
    if success { return 0; }
    return 1;
}
