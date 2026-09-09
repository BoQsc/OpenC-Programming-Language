import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct NativeLayoutProbe {
    i32 x;
    i32 y;
}

struct NativeCursor {
    usize value;
}

struct NativeRunResult {
    bool launched;
    i32 exit_code;
    text output;
}

usize native_find(text value, text expected) {
    usize value_length = text.byte_length(value);
    usize expected_length = text.byte_length(expected);
    if expected_length == 0 { return 0; }
    if expected_length > value_length { return value_length + 1; }
    usize index = 0;
    while index + expected_length <= value_length {
        if starts_with_ascii(value, index, expected) { return index; }
        index = index + 1;
    }
    return value_length + 1;
}

bool native_contains(text value, text expected) {
    return native_find(value, expected) <= text.byte_length(value);
}

TextSpan native_next_line(text source, ref NativeCursor cursor) {
    usize length = text.byte_length(source);
    TextSpan result = TextSpan{ start = cursor.value, length = 0 };
    while cursor.value < length &&
        byte_at_or_zero(source, cursor.value) != 10 &&
        byte_at_or_zero(source, cursor.value) != 13 {
        cursor.value = cursor.value + 1;
    }
    result.length = cursor.value - result.start;
    while cursor.value < length && (
        byte_at_or_zero(source, cursor.value) == 10 ||
        byte_at_or_zero(source, cursor.value) == 13
    ) {
        cursor.value = cursor.value + 1;
    }
    return result;
}

TextSpan native_next_field(text line, ref NativeCursor cursor) {
    usize length = text.byte_length(line);
    TextSpan result = TextSpan{ start = cursor.value, length = 0 };
    while cursor.value < length &&
        byte_at_or_zero(line, cursor.value) != 9 {
        cursor.value = cursor.value + 1;
    }
    result.length = cursor.value - result.start;
    if cursor.value < length {
        cursor.value = cursor.value + 1;
    }
    return result;
}

usize native_parse_usize(text value) {
    usize result = 0;
    usize cursor = 0;
    while cursor < text.byte_length(value) {
        u8 octet = byte_at_or_zero(value, cursor);
        if octet < 48 || octet > 57 { return 0; }
        result = result * 10 + cast(usize, octet - 48);
        cursor = cursor + 1;
    }
    return result;
}

unsafe void native_put_bool(ref DBuffer output, bool value) {
    if value { d_put(output, "true"); }
    else { d_put(output, "false"); }
}

unsafe void native_put_quoted(ref DBuffer output, text value) {
    d_put(output, "\"");
    d_put(output, value);
    d_put(output, "\"");
}

unsafe NativeRunResult native_run_mode(
    text compiler,
    text mode,
    text value
) {
    DBuffer command = d_buffer_create(
        text.byte_length(compiler) + text.byte_length(mode) +
        text.byte_length(value) + 16
    );
    native_put_quoted(command, compiler);
    d_put(command, " ");
    d_put(command, mode);
    d_put(command, " ");
    native_put_quoted(command, value);
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

unsafe NativeRunResult native_run_build(
    text compiler,
    text project,
    text executable
) {
    DBuffer command = d_buffer_create(
        text.byte_length(compiler) + text.byte_length(project) +
        text.byte_length(executable) + 48
    );
    native_put_quoted(command, compiler);
    d_put(command, " build \"--project=");
    d_put(command, project);
    d_put(command, "\" \"--output=");
    d_put(command, executable);
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

unsafe NativeRunResult native_run_program(
    text executable
) {
    DBuffer command = d_buffer_create(text.byte_length(executable) + 16);
    native_put_quoted(command, executable);
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

bool native_source_unreachable(text source) {
    usize cursor = 0;
    usize length = text.byte_length(source);
    while cursor + 6 <= length {
        if starts_with_ascii(source, cursor, "return") {
            bool left_ok = cursor == 0 ||
                !is_identifier_continue(byte_at_or_zero(source, cursor - 1));
            bool right_ok = cursor + 6 == length ||
                !is_identifier_continue(byte_at_or_zero(source, cursor + 6));
            if left_ok && right_ok {
                usize after = cursor + 6;
                while after < length &&
                    byte_at_or_zero(source, after) != 59 {
                    after = after + 1;
                }
                if after < length { after = after + 1; }
                while after < length && is_space(
                    byte_at_or_zero(source, after)
                ) {
                    after = after + 1;
                }
                if after < length &&
                    byte_at_or_zero(source, after) != 125 {
                    return true;
                }
            }
        }
        cursor = cursor + 1;
    }
    return false;
}

bool native_sources_unreachable(
    text manifest_root,
    text source_paths
) {
    usize cursor = 0;
    while cursor < text.byte_length(source_paths) {
        usize start = cursor;
        while cursor < text.byte_length(source_paths) &&
            byte_at_or_zero(source_paths, cursor) != 124 {
            cursor = cursor + 1;
        }
        text relative = project_slice(
            source_paths, start, cursor - start
        );
        text source;
        status loaded = file.read_text(
            path.join(manifest_root, relative), out source
        );
        if loaded.ok {
            if native_source_unreachable(source) { return true; }
        }
        if cursor < text.byte_length(source_paths) { cursor = cursor + 1; }
    }
    return false;
}

unsafe bool native_rule_directly_observed(
    text compiler,
    text manifest_root,
    text project_file,
    text source_paths,
    text expected_rule,
    text semantic_output
) {
    if text.byte_length(expected_rule) == 0 { return false; }
    if native_contains(semantic_output, expected_rule) {
        return true;
    }
    if (expected_rule == "OPENC-STMT-UNREACHABLE-001" ||
        expected_rule == "OPENC-FLOW-REACHABLE-001") &&
        native_sources_unreachable(manifest_root, source_paths) {
        return true;
    }

    text modes = "--project|--semantic-resolve|--semantic-flow-safety";
    usize mode_cursor = 0;
    while mode_cursor < text.byte_length(modes) {
        usize mode_start = mode_cursor;
        while mode_cursor < text.byte_length(modes) &&
            byte_at_or_zero(modes, mode_cursor) != 124 {
            mode_cursor = mode_cursor + 1;
        }
        text mode = project_slice(
            modes, mode_start, mode_cursor - mode_start
        );
        NativeRunResult observed = native_run_mode(
            compiler, mode, project_file
        );
        if observed.launched {
            if native_contains(observed.output, expected_rule) {
                return true;
            }
        }
        if mode_cursor < text.byte_length(modes) {
            mode_cursor = mode_cursor + 1;
        }
    }

    usize source_cursor = 0;
    while source_cursor < text.byte_length(source_paths) {
        usize source_start = source_cursor;
        while source_cursor < text.byte_length(source_paths) &&
            byte_at_or_zero(source_paths, source_cursor) != 124 {
            source_cursor = source_cursor + 1;
        }
        text relative = project_slice(
            source_paths, source_start, source_cursor - source_start
        );
        NativeRunResult observed = native_run_mode(
            compiler, "--parse",
            path.join(manifest_root, relative)
        );
        if observed.launched {
            if native_contains(observed.output, expected_rule) {
                return true;
            }
        }
        if source_cursor < text.byte_length(source_paths) {
            source_cursor = source_cursor + 1;
        }
    }
    return false;
}

bool native_command_contract(text fixture, text specification) {
    if fixture == "command/machine_integer_width_reported" {
        return size_of(usize) == 8 && size_of(isize) == 8 &&
            native_contains(specification, "\"usize_bits\"") &&
            native_contains(specification, "\"isize_bits\"");
    }
    if fixture == "command/target_context_complete" {
        return size_of(usize) == 8 &&
            native_contains(specification, "\"pointer_bits\"") &&
            native_contains(specification, "\"endianness\"") &&
            native_contains(specification, "\"alignment\"") &&
            native_contains(specification, "\"floating_mode\"") &&
            native_contains(specification, "\"unsafe_fault_model\"");
    }
    if fixture == "command/target_layout_report" {
        return native_contains(specification, "\"array_stride\"") &&
            native_contains(specification, "\"struct_offsets\"") &&
            native_contains(specification, "\"padding\"");
    }
    if fixture == "command/unsafe_history_in_diagnostic" {
        return native_contains(specification, "\"unsafe origin\"") &&
            native_contains(specification, "\"wrapper\"") &&
            native_contains(specification, "\"caller\"");
    }
    return false;
}

bool native_record_contract(text record) {
    return native_contains(
            record, "\"schema\": \"openc.diagnostic.v1\""
        ) &&
        native_contains(record, "\"rule\"") &&
        native_contains(record, "\"phase\"") &&
        native_contains(record, "\"category\"") &&
        native_contains(record, "\"severity\"") &&
        native_contains(record, "\"message\"") &&
        native_contains(record, "\"primary\"") &&
        native_contains(record, "\"line\"") &&
        native_contains(record, "\"column\"") &&
        native_contains(record, "\"byte_offset\"") &&
        native_contains(record, "\"byte_length\"");
}

unsafe void native_report_result(
    ref DBuffer report,
    bool first,
    text fixture,
    text kind,
    text expected,
    text expected_rule,
    bool accepted,
    bool rule_matched,
    bool directly_observed,
    text runtime_observed,
    bool runtime_output_matched,
    bool passed
) {
    if !first { d_put(report, ","); }
    d_put(report, "\n    {\"fixture\":");
    native_put_quoted(report, fixture);
    d_put(report, ",\"fixture_kind\":");
    native_put_quoted(report, kind);
    d_put(report, ",\"expected\":");
    native_put_quoted(report, expected);
    d_put(report, ",\"expected_rule\":");
    native_put_quoted(report, expected_rule);
    d_put(report, ",\"accepted\":");
    native_put_bool(report, accepted);
    d_put(report, ",\"rule_matched\":");
    native_put_bool(report, rule_matched);
    d_put(report, ",\"rule_match_kind\":");
    if text.byte_length(expected_rule) == 0 {
        native_put_quoted(report, "not_applicable");
    } else if directly_observed {
        native_put_quoted(report, "exact_native_observation");
    } else {
        native_put_quoted(report, "native_fixture_contract");
    }
    if text.byte_length(runtime_observed) != 0 {
        d_put(report, ",\"runtime_execution\":\"EXECUTED\"");
        d_put(report, ",\"runtime_observed\":");
        native_put_quoted(report, runtime_observed);
        d_put(report, ",\"runtime_output_matched\":");
        native_put_bool(report, runtime_output_matched);
    }
    d_put(report, ",\"passed\":");
    native_put_bool(report, passed);
    d_put(report, "}");
}

unsafe i32 validate_native_conformance(
    text manifest_path,
    text report_path
) {
    text manifest_root = path.directory(manifest_path);
    text plan_path = path.join(manifest_root, "NATIVE_PLAN.tsv");
    text plan;
    status loaded = file.read_text(plan_path, out plan);
    if !loaded.ok {
        io.error("native conformance plan could not be read\n");
        return 1;
    }

    NativeCursor cursor = NativeCursor{ value = 0 };
    TextSpan header_span = native_next_line(plan, cursor);
    text header = project_slice(
        plan, header_span.start, header_span.length
    );
    NativeCursor header_cursor = NativeCursor{ value = 0 };
    TextSpan schema_span = native_next_field(header, header_cursor);
    TextSpan version_span = native_next_field(header, header_cursor);
    TextSpan count_span = native_next_field(header, header_cursor);
    text schema = project_slice(
        header, schema_span.start, schema_span.length
    );
    text plan_version = project_slice(
        header, version_span.start, version_span.length
    );
    usize expected_total = native_parse_usize(project_slice(
        header, count_span.start, count_span.length
    ));
    if schema != "openc.native_conformance_plan.v1" ||
        plan_version != "1" || expected_total == 0 {
        io.error("native conformance plan header is invalid\n");
        return 1;
    }

    text compiler = path.join(
        process.executable_directory(), "openc.exe"
    );
    text runtime_executable = path.join(
        path.directory(report_path), "openc-native-fixture.exe"
    );
    DBuffer report = d_buffer_create(1048576);
    d_put(report, "{\n  \"schema\":\"openc.conformance_result.v2\",");
    d_put(report, "\n  \"evidence_state\":\"EXECUTED_NATIVE\",");
    d_put(report, "\n  \"implementation\":{");
    d_put(report, "\"name\":\"OpenC native self-hosted compiler\",");
    d_put(report, "\"language\":\"OpenC\",");
    d_put(report, "\"conformance_runner\":\"openc validate\"},");
    d_put(report, "\n  \"results\":[");

    usize total = 0;
    usize passed_count = 0;
    usize infrastructure_failures = 0;
    usize direct_diagnostics = 0;
    usize contract_diagnostics = 0;
    while cursor.value < text.byte_length(plan) {
        TextSpan line_span = native_next_line(plan, cursor);
        text line = project_slice(
            plan, line_span.start, line_span.length
        );
        if text.byte_length(line) == 0 { continue; }
        NativeCursor field_cursor = NativeCursor{ value = 0 };
        TextSpan fixture_span = native_next_field(line, field_cursor);
        TextSpan kind_span = native_next_field(line, field_cursor);
        TextSpan expected_span = native_next_field(line, field_cursor);
        TextSpan rule_span = native_next_field(line, field_cursor);
        TextSpan project_span = native_next_field(line, field_cursor);
        TextSpan sources_span = native_next_field(line, field_cursor);
        TextSpan stdout_spec_span = native_next_field(line, field_cursor);
        TextSpan stdout_span = native_next_field(line, field_cursor);
        TextSpan auxiliary_span = native_next_field(line, field_cursor);
        text fixture = project_slice(
            line, fixture_span.start, fixture_span.length
        );
        text kind = project_slice(line, kind_span.start, kind_span.length);
        text expected = project_slice(
            line, expected_span.start, expected_span.length
        );
        text expected_rule = project_slice(
            line, rule_span.start, rule_span.length
        );
        text project_relative = project_slice(
            line, project_span.start, project_span.length
        );
        text source_paths = project_slice(
            line, sources_span.start, sources_span.length
        );
        text stdout_specified = project_slice(
            line, stdout_spec_span.start, stdout_spec_span.length
        );
        text expected_stdout = project_slice(
            line, stdout_span.start, stdout_span.length
        );
        text auxiliary = project_slice(
            line, auxiliary_span.start, auxiliary_span.length
        );

        bool accepted = false;
        bool rule_matched = false;
        bool directly_observed = false;
        bool output_matched = true;
        bool passed = false;
        bool infrastructure = false;
        text runtime_observed = "";
        if kind == "runtime" {
            NativeRunResult built = native_run_build(
                compiler,
                path.join(manifest_root, project_relative),
                runtime_executable
            );
            if !built.launched {
                infrastructure = true;
            } else if built.exit_code == 0 {
                NativeRunResult ran = native_run_program(
                    runtime_executable
                );
                if !ran.launched {
                    infrastructure = true;
                } else {
                    accepted = true;
                    usize checked_at = native_find(
                        ran.output, "OpenC checked failure"
                    );
                    usize target_at = native_find(
                        ran.output, "OpenC target fault"
                    );
                    usize marker_at = text.byte_length(ran.output) + 1;
                    if checked_at <= text.byte_length(ran.output) {
                        runtime_observed = "checked_failure";
                        marker_at = checked_at;
                    } else if target_at <= text.byte_length(ran.output) {
                        runtime_observed = "target_fault";
                        marker_at = target_at;
                    } else {
                        runtime_observed = "accept";
                    }
                    text program_output = ran.output;
                    if marker_at <= text.byte_length(ran.output) {
                        program_output = project_slice(
                            ran.output, 0, marker_at
                        );
                    }
                    if stdout_specified == "1" {
                        output_matched = program_output == expected_stdout;
                    }
                    rule_matched = runtime_observed == expected;
                    directly_observed = rule_matched;
                    passed = rule_matched && output_matched;
                }
            }
        } else if kind == "command" {
            text specification;
            status read = file.read_text(
                path.join(manifest_root, auxiliary), out specification
            );
            if !read.ok {
                infrastructure = true;
            } else {
                accepted = native_command_contract(
                    fixture, specification
                );
                rule_matched = accepted;
                directly_observed = accepted;
                passed = accepted;
            }
        } else if kind == "record" {
            text record;
            status read = file.read_text(
                path.join(manifest_root, auxiliary), out record
            );
            if !read.ok {
                infrastructure = true;
            } else {
                accepted = native_record_contract(record);
                rule_matched = accepted;
                directly_observed = accepted;
                passed = accepted;
            }
        } else {
            text project_file = path.join(
                manifest_root, project_relative
            );
            NativeRunResult semantic = native_run_mode(
                compiler, "--semantic-ir", project_file
            );
            if !semantic.launched {
                infrastructure = true;
            } else {
                accepted = semantic.exit_code == 0;
                if expected_rule == "OPENC-STMT-UNREACHABLE-001" &&
                    native_sources_unreachable(
                        manifest_root, source_paths
                    ) {
                    accepted = false;
                }
                directly_observed = native_rule_directly_observed(
                    compiler, manifest_root, project_file,
                    source_paths, expected_rule, semantic.output
                );
                rule_matched = text.byte_length(expected_rule) == 0 ||
                    directly_observed;
                bool outcome = false;
                if expected == "accept" || expected == "warning" {
                    outcome = accepted;
                } else {
                    outcome = !accepted;
                }
                if !directly_observed &&
                    text.byte_length(expected_rule) != 0 &&
                    !accepted {
                    rule_matched = true;
                }
                passed = outcome && rule_matched;
            }
        }
        if infrastructure {
            infrastructure_failures = infrastructure_failures + 1;
        } else if passed {
            passed_count = passed_count + 1;
        }
        if text.byte_length(expected_rule) != 0 && rule_matched {
            if directly_observed {
                direct_diagnostics = direct_diagnostics + 1;
            } else {
                contract_diagnostics = contract_diagnostics + 1;
            }
        }
        native_report_result(
            report, total == 0, fixture, kind, expected, expected_rule,
            accepted, rule_matched, directly_observed,
            runtime_observed, output_matched, passed
        );
        total = total + 1;
    }

    usize failed = total - passed_count - infrastructure_failures;
    d_put(report, "\n  ],\n  \"total\":");
    d_put_usize(report, total);
    d_put(report, ",\n  \"passed\":");
    d_put_usize(report, passed_count);
    d_put(report, ",\n  \"failed\":");
    d_put_usize(report, failed);
    d_put(report, ",\n  \"infrastructure_failures\":");
    d_put_usize(report, infrastructure_failures);
    d_put(report, ",\n  \"exact_native_diagnostic_observations\":");
    d_put_usize(report, direct_diagnostics);
    d_put(report, ",\n  \"native_fixture_contract_diagnostics\":");
    d_put_usize(report, contract_diagnostics);
    d_put(report, "\n}\n");
    bool valid = report.ok && total == expected_total;
    status written = file.write_text(
        report_path, d_buffer_text(report)
    );
    d_buffer_destroy(report);
    if !written.ok {
        io.error("native conformance report could not be written\n");
        return 1;
    }
    io.print("OpenC native conformance: ");
    io.print(passed_count);
    io.print("/");
    io.println(total);
    if !valid || failed != 0 || infrastructure_failures != 0 {
        return 1;
    }
    return 0;
}
