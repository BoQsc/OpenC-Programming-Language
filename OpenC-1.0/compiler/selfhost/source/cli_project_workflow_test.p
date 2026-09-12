import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

usize cli_json_number(text source, ref JsonState state) {
    project_json_skip_space(source, state);
    usize result = 0;
    usize start = state.cursor;
    while state.cursor < text.byte_length(source) {
        u8 value = byte_at_or_zero(source, state.cursor);
        if value < 48 || value > 57 { break; }
        result = result * 10 + cast(usize, value - 48);
        state.cursor = state.cursor + 1;
    }
    if state.cursor == start { state.failed = true; }
    return result;
}

unsafe void cli_test_record(
    ptr byte test_data,
    ref PackedBuffer tests,
    TextSpan name,
    TextSpan project_value,
    usize expected_exit
) {
    usize record = tests.length;
    write_record_field(test_data, record, 0, name.start);
    write_record_field(test_data, record, 1, name.length);
    write_record_field(test_data, record, 2, project_value.start);
    write_record_field(test_data, record, 3, project_value.length);
    write_record_field(test_data, record, 4, expected_exit);
    tests.length = tests.length + 1;
}

unsafe void cli_test_parse_object(
    text source,
    ref JsonState state,
    ptr byte test_data,
    ref PackedBuffer tests
) {
    if !project_json_take(source, state, 123) { return; }
    TextSpan name = TextSpan{ start = 0, length = 0 };
    TextSpan project_value = TextSpan{ start = 0, length = 0 };
    usize expected_exit = 0;
    project_json_skip_space(source, state);
    while !state.failed &&
        byte_at_or_zero(source, state.cursor) != 125 {
        TextSpan key = project_json_string(source, state);
        if !project_json_take(source, state, 58) { return; }
        if span_equals_ascii(
            source, key.start, key.length, "name"
        ) {
            name = project_json_string(source, state);
        } else if span_equals_ascii(
            source, key.start, key.length, "project"
        ) {
            project_value = project_json_string(source, state);
        } else if span_equals_ascii(
            source, key.start, key.length, "expected_exit"
        ) {
            expected_exit = cli_json_number(source, state);
        } else {
            project_json_skip_value(source, state);
        }
        if state.failed { return; }
        project_json_skip_space(source, state);
        if byte_at_or_zero(source, state.cursor) == 44 {
            state.cursor = state.cursor + 1;
        } else if byte_at_or_zero(source, state.cursor) != 125 {
            state.failed = true;
        }
        project_json_skip_space(source, state);
    }
    if !project_json_take(source, state, 125) { return; }
    if name.length == 0 || project_value.length == 0 {
        state.failed = true;
        return;
    }
    cli_test_record(
        test_data, tests, name, project_value, expected_exit
    );
}

unsafe void cli_test_parse_array(
    text source,
    ref JsonState state,
    ptr byte test_data,
    ref PackedBuffer tests
) {
    if !project_json_take(source, state, 91) { return; }
    project_json_skip_space(source, state);
    while !state.failed &&
        byte_at_or_zero(source, state.cursor) != 93 {
        cli_test_parse_object(source, state, test_data, tests);
        if state.failed { return; }
        project_json_skip_space(source, state);
        if byte_at_or_zero(source, state.cursor) == 44 {
            state.cursor = state.cursor + 1;
        } else if byte_at_or_zero(source, state.cursor) != 93 {
            state.failed = true;
        }
        project_json_skip_space(source, state);
    }
    project_json_take(source, state, 93);
}

unsafe bool cli_test_parse_manifest(
    text source,
    ptr byte test_data,
    ref PackedBuffer tests
) {
    JsonState state = JsonState{ cursor = 0, failed = false };
    if !project_json_take(source, state, 123) { return false; }
    project_json_skip_space(source, state);
    while !state.failed &&
        byte_at_or_zero(source, state.cursor) != 125 {
        TextSpan key = project_json_string(source, state);
        if !project_json_take(source, state, 58) { return false; }
        if span_equals_ascii(
            source, key.start, key.length, "tests"
        ) {
            cli_test_parse_array(source, state, test_data, tests);
        } else {
            project_json_skip_value(source, state);
        }
        if state.failed { return false; }
        project_json_skip_space(source, state);
        if byte_at_or_zero(source, state.cursor) == 44 {
            state.cursor = state.cursor + 1;
        } else if byte_at_or_zero(source, state.cursor) != 125 {
            return false;
        }
        project_json_skip_space(source, state);
    }
    if !project_json_take(source, state, 125) { return false; }
    project_json_skip_space(source, state);
    return !state.failed &&
        state.cursor == text.byte_length(source) &&
        tests.length != 0;
}

unsafe NativeRunResult cli_run_project_action(
    text action,
    text project_path
) {
    text compiler = cli_self_executable();
    DBuffer command = d_buffer_create(
        text.byte_length(compiler) + text.byte_length(action) +
        text.byte_length(project_path) + 64
    );
    native_put_quoted(command, compiler);
    d_put(command, " ");
    d_put(command, action);
    d_put(command, " \"--project=");
    d_put(command, project_path);
    d_put(command, "\"");
    i32 exit_code;
    text output;
    status ran = process.run(
        d_buffer_text(command), out exit_code, out output
    );
    d_buffer_destroy(command);
    if !ran.ok {
        return NativeRunResult{
            launched = false, exit_code = 0, output = ""
        };
    }
    return NativeRunResult{
        launched = true, exit_code = exit_code, output = output
    };
}

unsafe CliTestOutcome cli_test_execute(
    text project_path,
    usize expected_exit,
    bool no_run,
    usize execution_index
) {
    usize source_hash = cli_project_source_hash(project_path);
    if source_hash == 0 {
        return CliTestOutcome{
            kind = 3, exit_code = 0, source_hash = 0,
            output = "",
            diagnostics = "project or source hashing failed"
        };
    }
    NativeRunResult checked = cli_run_project_action(
        "check", project_path
    );
    if !checked.launched {
        return CliTestOutcome{
            kind = 3, exit_code = 0, source_hash = source_hash,
            output = "",
            diagnostics = "native check could not be launched"
        };
    }
    if checked.exit_code != 0 {
        return CliTestOutcome{
            kind = 1, exit_code = checked.exit_code,
            source_hash = source_hash,
            output = "", diagnostics = checked.output
        };
    }
    if no_run {
        return CliTestOutcome{
            kind = 0, exit_code = 0, source_hash = source_hash,
            output = "", diagnostics = ""
        };
    }

    DBuffer executable_name = d_buffer_create(64);
    d_put(executable_name, "openc-test-");
    d_put_usize(executable_name, execution_index);
    d_put(executable_name, ".exe");
    text executable = path.join(
        process.executable_directory(),
        d_buffer_text(executable_name)
    );
    NativeRunResult built = native_run_build(
        cli_self_executable(),
        project_path,
        executable
    );
    if !built.launched || built.exit_code != 0 {
        d_buffer_destroy(executable_name);
        return CliTestOutcome{
            kind = 3,
            exit_code = built.exit_code,
            source_hash = source_hash,
            output = "",
            diagnostics = built.output
        };
    }
    NativeRunResult executed = native_run_program(executable);
    d_buffer_destroy(executable_name);
    if !executed.launched {
        return CliTestOutcome{
            kind = 3, exit_code = 0, source_hash = source_hash,
            output = "",
            diagnostics = "built test could not be launched"
        };
    }
    if executed.exit_code != cast(i32, expected_exit) {
        return CliTestOutcome{
            kind = 2, exit_code = executed.exit_code,
            source_hash = source_hash,
            output = executed.output,
            diagnostics = "runtime exit assertion failed"
        };
    }
    return CliTestOutcome{
        kind = 0, exit_code = executed.exit_code,
        source_hash = source_hash,
        output = executed.output, diagnostics = ""
    };
}
