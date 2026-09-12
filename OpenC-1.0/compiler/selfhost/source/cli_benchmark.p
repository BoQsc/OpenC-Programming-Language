import system.file;
import system.io;
import system.path;
import system.process;
import system.text;
struct CliBenchmarkCounts {
    usize requested;
    usize executed;
    usize passed;
    usize exact_closures;
    usize public_records;
    usize peak_private_bytes;
    usize peak_working_set_bytes;
    usize elapsed_1;
    usize elapsed_2;
    usize elapsed_3;
    usize elapsed_4;
    usize elapsed_5;
    usize validation_1;
    usize validation_2;
    usize validation_3;
    usize validation_4;
    usize validation_5;
}
unsafe usize cli_benchmark_median_five(usize one, usize two, usize three, usize four, usize five) {
    usize temporary = 0;
    usize pass = 0;
    while pass < 5 {
        if one > two {
            temporary = one;
            one = two;
            two = temporary;
        }
        if two > three {
            temporary = two;
            two = three;
            three = temporary;
        }
        if three > four {
            temporary = three;
            three = four;
            four = temporary;
        }
        if four > five {
            temporary = four;
            four = five;
            five = temporary;
        }
        pass = pass + 1;
    }
    return three;
}
unsafe void cli_benchmark_record_public_sample(ref CliBenchmarkCounts counts, usize elapsed, usize validation) {
    if counts.executed == 1 {
        counts.elapsed_1 = elapsed;
        counts.validation_1 = validation;
    }
    else if counts.executed == 2 {
        counts.elapsed_2 = elapsed;
        counts.validation_2 = validation;
    }
    else if counts.executed == 3 {
        counts.elapsed_3 = elapsed;
        counts.validation_3 = validation;
    }
    else if counts.executed == 4 {
        counts.elapsed_4 = elapsed;
        counts.validation_4 = validation;
    }
    else if counts.executed == 5 {
        counts.elapsed_5 = elapsed;
        counts.validation_5 = validation;
    }
}
unsafe bool cli_benchmark_build_record_ok(text record) {
    return native_contains(record, "\"status\": \"PASS\"") && native_contains(record, "\"backend\": \"openc-x64-pe32\"") && native_contains(record, "\"dmd_invoked\": false") && native_contains(record, "\"dub_invoked\": false") && native_contains(record, "\"python_invoked\": false") && native_contains(record, "\"tinycc_invoked\": false") && native_contains(record, "\"external_assembler_invoked\": false") && native_contains(record, "\"external_linker_invoked\": false");
}
unsafe void cli_benchmark_put_sample(ref DBuffer samples, usize index, text command, bool launched, i32 exit_code, usize elapsed, usize validation, usize compiler_total, usize peak_private, usize peak_working_set, text input_hash, text output_hash, bool record_ok, bool closed, bool passed) {
    if index != 1 {
        d_put(samples, ",\n");
    }
    d_put(samples, "    {\"generation\":");
    d_put_usize(samples, index);
    d_put(samples, ",\"command\":");
    cli_json_text(samples, command);
    d_put(samples, ",\"launched\":");
    native_put_bool(samples, launched);
    d_put(samples, ",\"exit_code\":");
    d_put_usize(samples, cast(usize, exit_code));
    d_put(samples, ",\"elapsed_milliseconds\":");
    d_put_usize(samples, elapsed);
    d_put(samples, ",\"validation_milliseconds\":");
    d_put_usize(samples, validation);
    d_put(samples, ",\"compiler_total_milliseconds\":");
    d_put_usize(samples, compiler_total);
    d_put(samples, ",\"peak_private_bytes\":");
    d_put_usize(samples, peak_private);
    d_put(samples, ",\"peak_working_set_bytes\":");
    d_put_usize(samples, peak_working_set);
    d_put(samples, ",\"input_sha256\":");
    cli_json_text(samples, input_hash);
    d_put(samples, ",\"output_sha256\":");
    cli_json_text(samples, output_hash);
    d_put(samples, ",\"build_record_passed\":");
    native_put_bool(samples, record_ok);
    d_put(samples, ",\"closed_exactly\":");
    native_put_bool(samples, closed);
    d_put(samples, ",\"passed\":");
    native_put_bool(samples, passed);
    d_put(samples, "}");
}
unsafe bool cli_benchmark_run_sample(text compiler, text compiler_hash, text project, text output_directory, usize run, usize runs, ref CliBenchmarkCounts counts, ref DBuffer samples) {
    DBuffer input_path_buffer = d_buffer_create(text.byte_length(output_directory) + text.byte_length(compiler) + 64);
    if run == 1 {
        d_put(input_path_buffer, compiler);
    }
    else {
        d_put(input_path_buffer, output_directory);
        d_put(input_path_buffer, "/openc-benchmark-generation-");
        d_put_usize(input_path_buffer, run - 1);
        d_put(input_path_buffer, ".exe");
    }
    text input_path = d_buffer_text(input_path_buffer);
    DBuffer executable_buffer = d_buffer_create(text.byte_length(output_directory) + 64);
    d_put(executable_buffer, output_directory);
    d_put(executable_buffer, "/openc-benchmark-generation-");
    d_put_usize(executable_buffer, run);
    d_put(executable_buffer, ".exe");
    text executable = d_buffer_text(executable_buffer);
    DBuffer timing_buffer = d_buffer_create(text.byte_length(output_directory) + 64);
    d_put(timing_buffer, output_directory);
    d_put(timing_buffer, "/openc-benchmark-timings-");
    d_put_usize(timing_buffer, run);
    d_put(timing_buffer, ".json");
    text timing_path = d_buffer_text(timing_buffer);
    DBuffer record_buffer = d_buffer_create(text.byte_length(executable) + 16);
    d_put(record_buffer, executable);
    d_put(record_buffer, ".build.json");
    text record_path = d_buffer_text(record_buffer);
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, input_path, "build");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--output=", executable);
    cli_workflow_command_named_argument(command, "--timings=", timing_path);
    DBuffer input_hash = d_buffer_create(65);
    DBuffer output_hash = d_buffer_create(65);
    bool input_hashed = cli_workflow_sha256(input_path, input_hash);
    usize started = process.monotonic_milliseconds();
    i32 exit_code;
    text child_output;
    usize peak_private;
    usize peak_working_set;
    status ran = cli_process_run_measured(d_buffer_text(command), cast(usize, 300000), out exit_code, out child_output, out peak_private, out peak_working_set);
    usize elapsed = process.monotonic_milliseconds() - started;
    i32 exit_value = 0;
    usize peak_private_value = 0;
    usize peak_working_set_value = 0;
    if ran.ok {
        exit_value = exit_code;
        peak_private_value = peak_private;
        peak_working_set_value = peak_working_set;
    }
    bool output_hashed = false;
    if ran.ok && exit_value == 0 {
        output_hashed = cli_workflow_sha256(executable, output_hash);
    }
    text timings_output;
    text record_output;
    status timings_loaded = file.read_text(timing_path, out timings_output);
    status record_loaded = file.read_text(record_path, out record_output);
    text timings = "";
    text record = "";
    if timings_loaded.ok {
        timings = timings_output;
    }
    if record_loaded.ok {
        record = record_output;
    }
    bool timings_ok = timings_loaded.ok;
    usize validation = 999999999;
    usize compiler_total = 999999999;
    if timings_ok {
        validation = lsp_json_usize(timings, "validation", cast(usize, 999999999));
        compiler_total = lsp_json_usize(timings, "total_ms", cast(usize, 999999999));
    }
    bool record_ok = record_loaded.ok && cli_benchmark_build_record_ok(record);
    bool closed = input_hashed && output_hashed &&
        d_buffer_text(input_hash) == compiler_hash &&
        d_buffer_text(output_hash) == compiler_hash;
    bool passed = ran.ok && exit_value == 0 && output_hashed && timings_ok && validation != 999999999 && compiler_total != 999999999 && record_ok && closed && peak_private_value != 0 && peak_private_value <= 268435456 && peak_working_set_value != 0 && peak_working_set_value <= 67108864;
    counts.executed = counts.executed + 1;
    if passed {
        counts.passed = counts.passed + 1;
    }
    if closed {
        counts.exact_closures = counts.exact_closures + 1;
    }
    if record_ok {
        counts.public_records = counts.public_records + 1;
    }
    if peak_private_value > counts.peak_private_bytes {
        counts.peak_private_bytes = peak_private_value;
    }
    if peak_working_set_value > counts.peak_working_set_bytes {
        counts.peak_working_set_bytes = peak_working_set_value;
    }
    cli_benchmark_record_public_sample(counts, elapsed, validation);
    cli_benchmark_put_sample(samples, run, d_buffer_text(command), ran.ok, exit_value, elapsed, validation, compiler_total, peak_private_value, peak_working_set_value, d_buffer_text(input_hash), d_buffer_text(output_hash), record_ok, closed, passed);
    io.print("benchmark native chain: ");
    io.print(run);
    io.print("/");
    io.print(runs);
    io.print(" ");
    if passed {
        io.println("PASS");
    }
    else {
        io.println("FAIL");
    }
    d_buffer_destroy(input_hash);
    d_buffer_destroy(output_hash);
    d_buffer_destroy(command);
    d_buffer_destroy(record_buffer);
    d_buffer_destroy(timing_buffer);
    d_buffer_destroy(executable_buffer);
    d_buffer_destroy(input_path_buffer);
    return passed;
}
unsafe i32 cli_benchmark_command() {
    text project = "";
    text output_path = "";
    usize runs = 20;
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--project=") {
            project = cli_remove_prefix(value, "--project=");
        }
        else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        }
        else if cli_has_prefix(value, "--runs=") {
            runs = native_parse_usize(cli_remove_prefix(value, "--runs="));
        }
        else {
            io.error("usage: openc benchmark --project=PROJECT --output=REPORT.json [--runs=1..20]\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(project) == 0 || text.byte_length(output_path) == 0 || runs == 0 || runs > 20 {
        io.error("usage: openc benchmark --project=PROJECT --output=REPORT.json [--runs=1..20]\n");
        return 64;
    }
    text compiler = cli_self_executable();
    text output_directory = path.directory(output_path);
    DBuffer compiler_hash = d_buffer_create(65);
    DBuffer project_hash = d_buffer_create(65);
    bool inputs_ok = cli_workflow_sha256(compiler, compiler_hash) && cli_workflow_sha256(project, project_hash);
    CliBenchmarkCounts counts = CliBenchmarkCounts{
        requested = runs, executed = 0, passed = 0, exact_closures = 0, public_records = 0, peak_private_bytes = 0, peak_working_set_bytes = 0, elapsed_1 = 0, elapsed_2 = 0, elapsed_3 = 0, elapsed_4 = 0, elapsed_5 = 0, validation_1 = 0, validation_2 = 0, validation_3 = 0, validation_4 = 0, validation_5 = 0
    };
    DBuffer samples = d_buffer_create(262144);
    usize run = 1;
    while inputs_ok && run <= runs {
        bool sample_passed = cli_benchmark_run_sample(compiler, d_buffer_text(compiler_hash), project, output_directory, run, runs, counts, samples);
        if ! sample_passed {
            break;
        }
        run = run + 1;
    }
    usize build_median = 999999999;
    usize validation_median = 999999999;
    if counts.executed >= 5 {
        build_median = cli_benchmark_median_five(counts.elapsed_1, counts.elapsed_2, counts.elapsed_3, counts.elapsed_4, counts.elapsed_5);
        validation_median = cli_benchmark_median_five(counts.validation_1, counts.validation_2, counts.validation_3, counts.validation_4, counts.validation_5);
    }
    bool commands_passed = counts.executed == counts.requested && counts.passed == counts.requested;
    bool exact_twenty = counts.requested == 20 && counts.exact_closures == 20;
    bool records_passed = counts.public_records == counts.requested;
    bool build_gate = counts.executed >= 5 && build_median <= 25000;
    bool validation_gate = counts.executed >= 5 && validation_median < 15000;
    bool memory_gate = counts.peak_private_bytes != 0 && counts.peak_private_bytes <= 268435456 && counts.peak_working_set_bytes != 0 && counts.peak_working_set_bytes <= 67108864;
    bool passed = inputs_ok && commands_passed && exact_twenty && records_passed && build_gate && validation_gate && memory_gate;
    DBuffer report = d_buffer_create(524288);
    d_put(report, "{\n  \"schema\": \"openc.native_benchmark.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"compiler\": ");
    cli_json_text(report, compiler);
    d_put(report, ",\n  \"project\": ");
    cli_json_text(report, project);
    d_put(report, ",\n  \"inputs\": {\"compiler_sha256\":");
    cli_json_text(report, d_buffer_text(compiler_hash));
    d_put(report, ",\"project_sha256\":");
    cli_json_text(report, d_buffer_text(project_hash));
    d_put(report, "},\n  \"limits\": {\"public_build_median_milliseconds\":25000,\"validation_median_milliseconds_exclusive\":15000,\"peak_private_bytes\":268435456,\"peak_working_set_bytes\":67108864,\"captured_output_bytes\":4194304,\"child_timeout_milliseconds\":300000},\n");
    d_put(report, "  \"samples\": [\n");
    d_put(report, d_buffer_text(samples));
    d_put(report, "\n  ],\n  \"summary\": {\"requested\":");
    d_put_usize(report, counts.requested);
    d_put(report, ",\"executed\":");
    d_put_usize(report, counts.executed);
    d_put(report, ",\"passed\":");
    d_put_usize(report, counts.passed);
    d_put(report, ",\"exact_closures\":");
    d_put_usize(report, counts.exact_closures);
    d_put(report, ",\"public_records\":");
    d_put_usize(report, counts.public_records);
    d_put(report, ",\"public_build_median_milliseconds\":");
    d_put_usize(report, build_median);
    d_put(report, ",\"validation_median_milliseconds\":");
    d_put_usize(report, validation_median);
    d_put(report, ",\"peak_private_bytes\":");
    d_put_usize(report, counts.peak_private_bytes);
    d_put(report, ",\"peak_working_set_bytes\":");
    d_put_usize(report, counts.peak_working_set_bytes);
    d_put(report, "},\n  \"checks\": {\"commands_passed\":");
    native_put_bool(report, commands_passed);
    d_put(report, ",\"twenty_chained_outputs_close_exactly\":");
    native_put_bool(report, exact_twenty);
    d_put(report, ",\"public_records_passed\":");
    native_put_bool(report, records_passed);
    d_put(report, ",\"public_build_median_at_most_25s\":");
    native_put_bool(report, build_gate);
    d_put(report, ",\"validation_median_below_15s\":");
    native_put_bool(report, validation_gate);
    d_put(report, ",\"all_runs_within_memory_limits\":");
    native_put_bool(report, memory_gate);
    d_put(report, "},\n  \"toolchain\": {\"python_invoked\":false,\"d_invoked\":false,\"c_compiler_invoked\":false,\"tinycc_invoked\":false,\"external_assembler_invoked\":false,\"external_linker_invoked\":false},\n  \"status\": \"");
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
    d_buffer_destroy(samples);
    d_buffer_destroy(project_hash);
    d_buffer_destroy(compiler_hash);
    if ! report_ok || ! written.ok {
        io.error("error: native benchmark report could not be written\n");
        return 1;
    }
    io.print("OpenC native benchmark: ");
    if passed {
        io.print("PASS");
    }
    else {
        io.print("FAIL");
    }
    io.print(" (");
    io.print(counts.passed);
    io.print("/");
    io.print(counts.requested);
    io.println(")");
    if passed {
        return 0;
    }
    return 1;
}
