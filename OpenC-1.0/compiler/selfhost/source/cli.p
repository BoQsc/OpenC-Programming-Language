import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliWordCursor {
    usize value;
}

TextSpan cli_next_word(text line, ref CliWordCursor cursor) {
    usize length = text.byte_length(line);
    while cursor.value < length && (
        byte_at_or_zero(line, cursor.value) == 32 ||
        byte_at_or_zero(line, cursor.value) == 9
    ) {
        cursor.value = cursor.value + 1;
    }
    TextSpan result = TextSpan{ start = cursor.value, length = 0 };
    while cursor.value < length &&
        byte_at_or_zero(line, cursor.value) != 32 &&
        byte_at_or_zero(line, cursor.value) != 9 {
        cursor.value = cursor.value + 1;
    }
    result.length = cursor.value - result.start;
    return result;
}

text cli_word_text(text line, TextSpan span) {
    return project_slice(line, span.start, span.length);
}

bool cli_contains_byte(text value, u8 expected) {
    usize cursor = 0;
    while cursor < text.byte_length(value) {
        if byte_at_or_zero(value, cursor) == expected { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe void cli_json_text(ref DBuffer output, text value) {
    d_put(output, "\"");
    usize cursor = 0;
    while cursor < text.byte_length(value) {
        u8 octet = byte_at_or_zero(value, cursor);
        if octet == 34 {
            d_put(output, "\\\"");
        } else if octet == 92 {
            d_put(output, "\\\\");
        } else if octet == 10 {
            d_put(output, "\\n");
        } else if octet == 13 {
            d_put(output, "\\r");
        } else if octet == 9 {
            d_put(output, "\\t");
        } else if octet < 32 {
            d_put(output, "?");
        } else {
            d_put(
                output, project_slice(value, cursor, cast(usize, 1))
            );
        }
        cursor = cursor + 1;
    }
    d_put(output, "\"");
}

text cli_version() {
    text version;
    status loaded = file.read_text(
        path.join(process.executable_directory(), "VERSION"),
        out version
    );
    if loaded.ok {
        usize length = text.byte_length(version);
        while length != 0 && (
            byte_at_or_zero(version, length - 1) == 10 ||
            byte_at_or_zero(version, length - 1) == 13 ||
            byte_at_or_zero(version, length - 1) == 32 ||
            byte_at_or_zero(version, length - 1) == 9
        ) {
            length = length - 1;
        }
        return project_slice(version, 0, length);
    }
    return "1.0.0-rc.9";
}

void cli_print_help() {
    io.println("OpenC native compiler");
    io.println("");
    io.println("usage:");
    io.println("  openc check --project=PROJECT [--output=CHECK-RECORD.json]");
    io.println("  openc build --project=PROJECT --output=OUTPUT.exe [--timings=TIMINGS.json]");
    io.println("  openc run --project=PROJECT [-- PROGRAM-ARGUMENTS...]");
    io.println("  openc fmt (--check|--write) (--project=PROJECT|SOURCE.p) [--output=FORMAT-RECORD.json]");
    io.println("  openc info --project=PROJECT [--context|--sources|--modules|--limits|--dependencies|--target|--types] [--json] [--output=CONTEXT.json]");
    io.println("  openc test (--manifest=TESTS.json|--project=PROJECT) [--list] [--filter=TEXT] [--jobs=N] [--target=TARGET] [--report=RESULT.json] [--no-run]");
    io.println("  openc lsp --stdio");
    io.println("  openc validate --manifest=MANIFEST --output=REPORT.json");
    io.println("  openc version");
    io.println("  openc target");
    io.println("  openc explain RULE-ID");
    io.println("  openc help");
}

void cli_print_version() {
    io.print("OpenC ");
    io.println(cli_version());
    io.println("compiler: OpenC self-hosted native");
}

void cli_print_target() {
    io.println("target: windows-x86_64-hosted");
    io.println("pointer-width: 64");
    io.println("profile: standard");
    io.println("backend: c11-tinycc-win64");
}

TextSpan cli_json_field(text object, text field) {
    DBuffer needle = d_buffer_create(text.byte_length(field) + 8);
    d_put(needle, "\"");
    d_put(needle, field);
    d_put(needle, "\": \"");
    if !needle.ok {
        d_buffer_destroy(needle);
        return TextSpan{ start = 0, length = 0 };
    }
    usize at = native_find(object, d_buffer_text(needle));
    usize prefix_length = text.byte_length(d_buffer_text(needle));
    d_buffer_destroy(needle);
    if at > text.byte_length(object) {
        return TextSpan{ start = 0, length = 0 };
    }
    usize start = at + prefix_length;
    usize end = start;
    while end < text.byte_length(object) &&
        byte_at_or_zero(object, end) != 34 {
        end = end + 1;
    }
    return TextSpan{ start = start, length = end - start };
}

unsafe i32 cli_explain(text requested_rule) {
    text index_path = path.join(
        process.executable_directory(),
        "standard/core/metadata/OpenC_Core_Rule_Index.json"
    );
    text index;
    status loaded = file.read_text(index_path, out index);
    if !loaded.ok {
        io.error("error: canonical rule index is not available beside openc.exe\n");
        return 1;
    }
    DBuffer needle = d_buffer_create(
        text.byte_length(requested_rule) + 16
    );
    d_put(needle, "\"id\": \"");
    d_put(needle, requested_rule);
    d_put(needle, "\"");
    usize found = native_find(index, d_buffer_text(needle));
    d_buffer_destroy(needle);
    if found > text.byte_length(index) {
        text plan;
        status plan_loaded = file.read_text(
            path.join(
                process.executable_directory(),
                "conformance/fixtures/NATIVE_PLAN.tsv"
            ),
            out plan
        );
        if plan_loaded.ok && native_contains(plan, requested_rule) {
            io.print("rule: ");
            io.println(requested_rule);
            io.println(
                "title: retained diagnostic compatibility identity"
            );
            io.println("phase: compiler-diagnostic");
            io.println("chapter: compatibility evidence");
            io.println("status: historical_compatibility_disclosed");
            return 0;
        }
        io.error("unknown OpenC rule: ");
        io.error(requested_rule);
        io.error("\n");
        return 2;
    }
    usize object_start = found;
    while object_start != 0 &&
        byte_at_or_zero(index, object_start) != 123 {
        object_start = object_start - 1;
    }
    usize object_end = found;
    while object_end < text.byte_length(index) &&
        byte_at_or_zero(index, object_end) != 125 {
        object_end = object_end + 1;
    }
    text object = project_slice(
        index, object_start, object_end - object_start + 1
    );
    TextSpan title = cli_json_field(object, "title");
    TextSpan phase = cli_json_field(object, "phase");
    TextSpan chapter = cli_json_field(object, "chapter");
    TextSpan status_value = cli_json_field(object, "status");
    io.print("rule: ");
    io.println(requested_rule);
    io.print("title: ");
    io.println(project_slice(object, title.start, title.length));
    io.print("phase: ");
    io.println(project_slice(object, phase.start, phase.length));
    io.print("chapter: ");
    io.println(project_slice(object, chapter.start, chapter.length));
    io.print("status: ");
    io.println(project_slice(
        object, status_value.start, status_value.length
    ));
    return 0;
}

void cli_render_project_error(text line) {
    CliWordCursor cursor = CliWordCursor{ value = 0 };
    cli_next_word(line, cursor);
    text rule = cli_word_text(line, cli_next_word(line, cursor));
    text module_index = cli_word_text(
        line, cli_next_word(line, cursor)
    );
    text source_index = cli_word_text(
        line, cli_next_word(line, cursor)
    );
    cli_next_word(line, cursor);
    cli_next_word(line, cursor);
    text line_number = cli_word_text(
        line, cli_next_word(line, cursor)
    );
    text column = cli_word_text(line, cli_next_word(line, cursor));
    io.error("error[");
    io.error(rule);
    io.error("]: source rejected at module ");
    io.error(module_index);
    io.error(", source ");
    io.error(source_index);
    io.error(", line ");
    io.error(line_number);
    io.error(", column ");
    io.error(column);
    io.error("\n");
}

void cli_render_flow_error(text line) {
    CliWordCursor cursor = CliWordCursor{ value = 0 };
    cli_next_word(line, cursor);
    cli_next_word(line, cursor);
    text phase = cli_word_text(line, cli_next_word(line, cursor));
    text rule = cli_word_text(line, cli_next_word(line, cursor));
    text module_index = cli_word_text(
        line, cli_next_word(line, cursor)
    );
    text source_index = cli_word_text(
        line, cli_next_word(line, cursor)
    );
    text byte_start = cli_word_text(
        line, cli_next_word(line, cursor)
    );
    io.error("error[");
    io.error(rule);
    io.error("]: ");
    io.error(phase);
    io.error(" check failed at module ");
    io.error(module_index);
    io.error(", source ");
    io.error(source_index);
    io.error(", byte ");
    io.error(byte_start);
    io.error("\n");
}

void cli_render_failed_output(text output) {
    NativeCursor cursor = NativeCursor{ value = 0 };
    while cursor.value < text.byte_length(output) {
        TextSpan line_span = native_next_line(output, cursor);
        text line = project_slice(
            output, line_span.start, line_span.length
        );
        if starts_with_ascii(line, 0, "ERROR ") {
            CliWordCursor words = CliWordCursor{ value = 0 };
            cli_next_word(line, words);
            text second = cli_word_text(
                line, cli_next_word(line, words)
            );
            if cli_has_prefix(second, "OPENC-") {
                cli_render_project_error(line);
            } else {
                cli_render_flow_error(line);
            }
        } else if starts_with_ascii(line, 0, "PROJECT_ERROR ") {
            CliWordCursor words = CliWordCursor{ value = 0 };
            cli_next_word(line, words);
            text rule = cli_word_text(
                line, cli_next_word(line, words)
            );
            io.error("error[");
            io.error(rule);
            io.error("]: project input could not be checked\n");
        } else if starts_with_ascii(line, 0, "SEMANTIC_ERROR ") {
            CliWordCursor words = CliWordCursor{ value = 0 };
            cli_next_word(line, words);
            text count = cli_word_text(
                line, cli_next_word(line, words)
            );
            io.error("error: semantic acceptance rejected the project (");
            io.error(count);
            io.error(" recorded violation(s))\n");
        } else if starts_with_ascii(line, 0, "FRONTEND_ERROR ") {
            CliWordCursor words = CliWordCursor{ value = 0 };
            cli_next_word(line, words);
            text count = cli_word_text(
                line, cli_next_word(line, words)
            );
            io.error("error: source front end rejected the project (");
            io.error(count);
            io.error(" recorded violation(s))\n");
        }
    }
}

unsafe bool cli_write_check_record(
    text output_path,
    text project_path,
    bool passed,
    ref NativeRunResult project_result,
    ref NativeRunResult flow_result,
    ref NativeRunResult semantic_result
) {
    if text.byte_length(output_path) == 0 { return true; }
    DBuffer record = d_buffer_create(4194304);
    d_put(record, "{\n  \"schema\": \"openc.check.v1\",\n");
    d_put(record, "  \"status\": \"");
    if passed { d_put(record, "PASS"); }
    else { d_put(record, "FAIL"); }
    d_put(record, "\",\n  \"version\": ");
    cli_json_text(record, cli_version());
    d_put(record, ",\n  \"target\": \"windows-x86_64-hosted\",\n");
    d_put(record, "  \"project\": ");
    cli_json_text(record, project_path);
    d_put(record, ",\n  \"stages\": {\n");
    d_put(record, "    \"project\": ");
    d_put_usize(record, cast(usize, project_result.exit_code));
    d_put(record, ",\n    \"flow\": ");
    d_put_usize(record, cast(usize, flow_result.exit_code));
    d_put(record, ",\n    \"semantic_ir\": ");
    d_put_usize(record, cast(usize, semantic_result.exit_code));
    d_put(record, "\n  },\n  \"machine_diagnostics\": {\n");
    d_put(record, "    \"schema\": \"openc.native_cli.diagnostic_streams.v1\",\n");
    d_put(record, "    \"project\": ");
    if project_result.exit_code == 0 { cli_json_text(record, ""); }
    else { cli_json_text(record, project_result.output); }
    d_put(record, ",\n    \"flow\": ");
    if flow_result.exit_code == 0 { cli_json_text(record, ""); }
    else { cli_json_text(record, flow_result.output); }
    d_put(record, ",\n    \"semantic_ir\": ");
    if semantic_result.exit_code == 0 { cli_json_text(record, ""); }
    else { cli_json_text(record, semantic_result.output); }
    d_put(record, "\n  }\n}\n");
    bool ok = record.ok;
    status written = file.write_text(
        output_path, d_buffer_text(record)
    );
    d_buffer_destroy(record);
    return ok && written.ok;
}

NativeRunResult cli_unexecuted_stage() {
    return NativeRunResult{
        launched = true, exit_code = 0, output = ""
    };
}

unsafe i32 cli_check_project(
    text project_path,
    text output_path,
    bool announce
) {
    text compiler = path.join(
        process.executable_directory(), "openc.exe"
    );
    NativeRunResult project_result = native_run_mode(
        compiler, "--project", project_path
    );
    NativeRunResult flow_result = cli_unexecuted_stage();
    NativeRunResult semantic_result = cli_unexecuted_stage();
    if !project_result.launched {
        io.error("error: native project check could not be launched\n");
        return 1;
    }
    if project_result.exit_code == 0 {
        flow_result = native_run_mode(
            compiler, "--semantic-flow-safety", project_path
        );
    }
    if project_result.exit_code == 0 &&
        flow_result.launched && flow_result.exit_code == 0 {
        semantic_result = native_run_mode(
            compiler, "--semantic-ir", project_path
        );
    }
    bool passed = project_result.launched &&
        flow_result.launched && semantic_result.launched &&
        project_result.exit_code == 0 &&
        flow_result.exit_code == 0 &&
        semantic_result.exit_code == 0;
    if !passed {
        if project_result.exit_code != 0 {
            cli_render_failed_output(project_result.output);
        } else if !flow_result.launched {
            io.error("error: native flow check could not be launched\n");
        } else if flow_result.exit_code != 0 {
            cli_render_failed_output(flow_result.output);
        } else if !semantic_result.launched {
            io.error("error: native semantic check could not be launched\n");
        } else {
            cli_render_failed_output(semantic_result.output);
        }
    }
    if !cli_write_check_record(
        output_path, project_path, passed,
        project_result, flow_result, semantic_result
    ) {
        io.error("error: check record could not be written\n");
        return 1;
    }
    if passed {
        if announce { io.println("OpenC check: PASS"); }
        return 0;
    }
    if announce { io.println("OpenC check: FAIL"); }
    return 1;
}

unsafe bool cli_put_program_argument(
    ref DBuffer command,
    text argument
) {
    if cli_contains_byte(argument, 34) {
        return false;
    }
    d_put(command, " \"");
    d_put(command, argument);
    d_put(command, "\"");
    return command.ok;
}

unsafe i32 cli_run_project(text project_path, usize argument_start) {
    if cli_check_project(project_path, "", false) != 0 { return 1; }
    text executable = path.join(
        process.executable_directory(), "openc-run.exe"
    );
    if build_default_windows(project_path, executable, "") != 0 {
        io.error("error: native build failed before run\n");
        return 1;
    }
    DBuffer command = d_buffer_create(65536);
    native_put_quoted(command, executable);
    usize argument = argument_start;
    while argument < process.argument_count() {
        if !cli_put_program_argument(
            command, process.argument(argument)
        ) {
            d_buffer_destroy(command);
            io.error("error: program arguments containing quotes are not supported\n");
            return 64;
        }
        argument = argument + 1;
    }
    d_put(command, " 2>&1");
    i32 exit_code;
    text output;
    status ran = process.run(
        d_buffer_text(command), out exit_code, out output
    );
    d_buffer_destroy(command);
    if !ran.ok {
        io.error("error: compiled OpenC program could not be launched\n");
        return 1;
    }
    io.print(output);
    return exit_code;
}
