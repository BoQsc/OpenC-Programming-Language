import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool cli_has_prefix(text value, text prefix) {
    usize value_length = text.byte_length(value);
    usize prefix_length = text.byte_length(prefix);
    if value_length < prefix_length { return false; }
    return text.equal(
        project_slice(value, 0, prefix_length), prefix
    );
}

unsafe text cli_remove_prefix(text value, text prefix) {
    usize prefix_length = text.byte_length(prefix);
    return project_slice(
        value, prefix_length, text.byte_length(value) - prefix_length
    );
}

unsafe i32 build_default_windows(
    text project_path,
    text output_executable,
    text timing_path
) {
    DBuffer record = d_buffer_create(
        text.byte_length(output_executable) + 32
    );
    d_put(record, output_executable);
    d_put(record, ".build.json");
    if !record.ok {
        d_buffer_destroy(record);
        return 1;
    }
    BuildTimings timings = build_timings_empty();
    timings.emission_mode = 2;
    i32 result = emit_bootstrap_d_mode(
        project_path, output_executable, true, true, timings
    );
    text build_record = "{\n  \"schema\": \"openc-sh5-windows-build-v1\",\n  \"status\": \"FAILED\",\n  \"backend\": \"openc-x64-pe32\",\n  \"dmd_invoked\": false,\n  \"dub_invoked\": false,\n  \"python_invoked\": false,\n  \"tinycc_invoked\": false,\n  \"external_assembler_invoked\": false,\n  \"external_linker_invoked\": false\n}\n";
    if result == 0 {
        build_record = "{\n  \"schema\": \"openc-sh5-windows-build-v1\",\n  \"status\": \"PASS\",\n  \"backend\": \"openc-x64-pe32\",\n  \"dmd_invoked\": false,\n  \"dub_invoked\": false,\n  \"python_invoked\": false,\n  \"tinycc_invoked\": false,\n  \"external_assembler_invoked\": false,\n  \"external_linker_invoked\": false\n}\n";
    }
    status record_written = file.write_text(
        d_buffer_text(record), build_record
    );
    bool timing_written = true;
    if text.byte_length(timing_path) != 0 {
        timing_written = write_build_timings(
            timing_path, timings, result == 0
        );
    }
    d_buffer_destroy(record);
    if !record_written.ok || !timing_written { return 1; }
    return result;
}

unsafe i32 cli_eight_argument_command() {
    if process.argument(0) == "--bootstrap-build" {
        return build_bootstrap_compiler(
            process.argument(1), process.argument(2), process.argument(3),
            process.argument(4), process.argument(5), process.argument(6),
            process.argument(7)
        );
    }
    if process.argument(0) == "--windows-build" {
        return build_windows_c(
            process.argument(1), process.argument(2), process.argument(3),
            process.argument(4), process.argument(5), process.argument(6),
            process.argument(7)
        );
    }
    io.error("usage: openc-selfhost-frontend [--bootstrap-build PROJECT OUTPUT-EXE GENERATED-DIR RUNTIME-DIR LIBRARY-DIR RECORD D-COMPILER | --windows-build PROJECT OUTPUT-EXE GENERATED-C RUNTIME-ROOT NATIVE-RUNTIME-DIR RECORD TCC-EXE]\n");
    return 64;
}

unsafe i32 cli_three_argument_command() {
    if process.argument(0) == "validate" {
        text manifest_path = process.argument(1);
        text report_path = process.argument(2);
        if cli_has_prefix(manifest_path, "--manifest=") {
            manifest_path = cli_remove_prefix(
                manifest_path, "--manifest="
            );
        }
        if cli_has_prefix(report_path, "--output=") {
            report_path = cli_remove_prefix(
                report_path, "--output="
            );
        }
        return validate_native_conformance(manifest_path, report_path);
    }
    if process.argument(0) == "build" {
        text project_path = process.argument(1);
        text output_executable = process.argument(2);
        if cli_has_prefix(project_path, "--project=") {
            project_path = cli_remove_prefix(
                project_path, "--project="
            );
        }
        if cli_has_prefix(output_executable, "--output=") {
            output_executable = cli_remove_prefix(
                output_executable, "--output="
            );
        }
        return build_default_windows(project_path, output_executable, "");
    }
    if process.argument(0) == "--emit-d" {
        return emit_bootstrap_d(process.argument(1), process.argument(2));
    }
    if process.argument(0) == "--bootstrap-emit-d" {
        return emit_trusted_bootstrap_d(
            process.argument(1), process.argument(2)
        );
    }
    if process.argument(0) == "--emit-c" {
        return emit_windows_c(process.argument(1), process.argument(2));
    }
    if process.argument(0) == "--bootstrap-emit-c" {
        return emit_trusted_windows_c(
            process.argument(1), process.argument(2)
        );
    }
    io.error("usage: openc [build --project=PROJECT --output=OUTPUT-EXE | validate --manifest=MANIFEST --output=REPORT | --emit-d | --bootstrap-emit-d | --emit-c | --bootstrap-emit-c] INPUT OUTPUT\n");
    return 64;
}

unsafe i32 cli_observe_source_command(usize arguments) {
    bool parse_mode = false;
    bool project_mode = false;
    bool semantic_declaration_mode = false;
    bool semantic_resolution_mode = false;
    bool semantic_flow_safety_mode = false;
    bool semantic_ir_mode = false;
    text source_path = process.argument(0);
    if arguments == 2 {
        if process.argument(0) == "--parse" {
            parse_mode = true;
        } else if process.argument(0) == "--project" {
            project_mode = true;
        } else if process.argument(0) == "--semantic-decl" {
            semantic_declaration_mode = true;
        } else if process.argument(0) == "--semantic-resolve" {
            semantic_resolution_mode = true;
        } else if process.argument(0) == "--semantic-flow-safety" {
            semantic_flow_safety_mode = true;
        } else if process.argument(0) == "--semantic-ir" {
            semantic_ir_mode = true;
        } else {
            io.error("usage: openc-selfhost-frontend [--parse SOURCE.p | --project openc.project.json | --semantic-decl openc.project.json | --semantic-resolve openc.project.json | --semantic-flow-safety openc.project.json | --semantic-ir openc.project.json | --emit-d openc.project.json OUTPUT-DIRECTORY]\n");
            return 64;
        }
        source_path = process.argument(1);
    }
    if project_mode { return observe_project(source_path); }
    if semantic_declaration_mode {
        return observe_semantic_declarations(source_path);
    }
    if semantic_resolution_mode {
        return observe_semantic_resolution(source_path);
    }
    if semantic_flow_safety_mode {
        return observe_semantic_flow_safety(source_path);
    }
    if semantic_ir_mode { return observe_semantic_ir(source_path); }
    text source;
    status loaded = file.read_text(source_path, out source);
    if !loaded.ok {
        if parse_mode {
            io.println("OPENC-PARSE-OBSERVATION 1");
        } else {
            io.println("OPENC-LEX-OBSERVATION 2");
        }
        io.println("SOURCE_ERROR OPENC-SOURCE-INVALID-001 0 0 1 1");
        io.println("SUMMARY 0 1");
        return 1;
    }
    source = source_without_initial_bom(source);
    usize source_length = text.byte_length(source);
    PackedBuffer tokens = PackedBuffer{
        length = 0, capacity = source_length + 1
    };
    PackedBuffer diagnostics = PackedBuffer{
        length = 0, capacity = source_length * 4 + 8
    };
    ptr byte token_data = memory.alloc(tokens.capacity * record_stride());
    scope memory.free(token_data);
    ptr byte diagnostic_data = memory.alloc(
        diagnostics.capacity * record_stride()
    );
    scope memory.free(diagnostic_data);
    lex_source(
        source, token_data, tokens, diagnostic_data, diagnostics
    );
    assign_token_positions(source, token_data, tokens);
    if parse_mode {
        PackedBuffer syntax = PackedBuffer{
            length = 0, capacity = tokens.length * 6 + 8
        };
        ptr byte syntax_data = memory.alloc(
            syntax.capacity * record_stride()
        );
        scope memory.free(syntax_data);
        parse_source_syntax(
            source, token_data, tokens, syntax_data, syntax,
            diagnostic_data, diagnostics
        );
        assign_diagnostic_positions(source, diagnostic_data, diagnostics);
        io.println("OPENC-PARSE-OBSERVATION 1");
        emit_syntax_records(syntax_data, syntax);
        emit_observation_records(diagnostic_data, diagnostics, true);
        io.print("SUMMARY ");
        io.print(syntax.length);
        io.print(" ");
        io.println(diagnostics.length);
        if diagnostics.length != 0 { return 1; }
        return 0;
    }
    assign_diagnostic_positions(source, diagnostic_data, diagnostics);
    io.println("OPENC-LEX-OBSERVATION 2");
    emit_observation_records(token_data, tokens, false);
    emit_observation_records(diagnostic_data, diagnostics, true);
    io.print("SUMMARY ");
    io.print(tokens.length);
    io.print(" ");
    io.println(diagnostics.length);
    if diagnostics.length != 0 { return 1; }
    return 0;
}

unsafe i32 main() {
    usize arguments = process.argument_count();
    if arguments == 4 && process.argument(0) == "--native-build-trusted" {
        BuildTimings native_timings = build_timings_empty();
        native_timings.emission_mode = 2;
        i32 result = emit_bootstrap_d_mode(
            process.argument(1), process.argument(2), false, true, native_timings
        );
        if !write_build_timings(
            process.argument(3), native_timings, result == 0
        ) { return 1; }
        return result;
    }
    if arguments == 4 && process.argument(0) == "--native-build" {
        BuildTimings native_timings = build_timings_empty();
        native_timings.emission_mode = 2;
        i32 result = emit_bootstrap_d_mode(
            process.argument(1), process.argument(2), true, true, native_timings
        );
        if !write_build_timings(
            process.argument(3), native_timings, result == 0
        ) { return 1; }
        return result;
    }
    if arguments == 3 && process.argument(0) == "--native-build-trusted" {
        // Internal SH-19 iteration lane for already-validated canonical source.
        // It never replaces the validating --native-build public candidate.
        BuildTimings native_timings = build_timings_empty();
        native_timings.emission_mode = 2;
        return emit_bootstrap_d_mode(
            process.argument(1), process.argument(2), false, true, native_timings
        );
    }
    if arguments == 3 && process.argument(0) == "--native-build" {
        BuildTimings native_timings = build_timings_empty();
        native_timings.emission_mode = 2;
        return emit_bootstrap_d_mode(
            process.argument(1), process.argument(2), true, true, native_timings
        );
    }
    if arguments == 3 && process.argument(0) == "--native-audit" {
        BuildTimings audit_timings = build_timings_empty();
        audit_timings.emission_mode = 1;
        return emit_bootstrap_d_mode(
            process.argument(1), process.argument(2), false, true, audit_timings
        );
    }
    if arguments == 2 && process.argument(0) == "--native-check" {
        BuildTimings check_timings = build_timings_empty();
        check_timings.emission_mode = 3;
        return emit_bootstrap_d_mode(
            process.argument(1), "", true, true, check_timings
        );
    }
    if arguments == 4 &&
        process.argument(0) == "--windows-winmd-project" {
        return emit_windows_winmd_projection(
            process.argument(1), process.argument(2), process.argument(3)
        );
    }
    if arguments == 5 &&
        process.argument(0) == "--windows-pe32-runtime" {
        return emit_windows_pe32_runtime(
            process.argument(1), process.argument(2),
            process.argument(3), process.argument(4)
        );
    }
    if arguments == 0 {
        cli_print_help();
        return 0;
    }
    if arguments == 1 {
        if process.argument(0) == "--process-guard-output-probe" {
            return cli_process_guard_output_probe();
        }
        if process.argument(0) == "--process-guard-memory-probe" {
            return cli_process_guard_memory_probe();
        }
        if process.argument(0) == "--process-guard-working-set-probe" {
            return cli_process_guard_working_set_probe();
        }
        if process.argument(0) == "--process-guard-timeout-probe" {
            return cli_process_guard_timeout_probe();
        }
        if process.argument(0) == "help" ||
            process.argument(0) == "--help" ||
            process.argument(0) == "-h" {
            cli_print_help();
            return 0;
        }
        if process.argument(0) == "version" ||
            process.argument(0) == "--version" {
            cli_print_version();
            return 0;
        }
        if process.argument(0) == "target" {
            cli_print_target();
            return 0;
        }
    }
    if arguments == 2 && process.argument(0) == "explain" {
        return cli_explain(process.argument(1));
    }
    if arguments == 2 && process.argument(0) == "hash" {
        return cli_workflow_hash_command(process.argument(1));
    }
    if arguments == 2 && process.argument(0) == "process-guard" {
        text output_path = process.argument(1);
        if !cli_has_prefix(output_path, "--output=") {
            io.error("usage: openc process-guard --output=REPORT.json\n");
            return 64;
        }
        return cli_process_guard_command(
            cli_remove_prefix(output_path, "--output=")
        );
    }
    if arguments == 2 &&
        process.argument(0) == "--windows-x64-substrate" {
        return emit_windows_x64_substrate_report(process.argument(1));
    }
    if arguments >= 2 && process.argument(0) == "fmt" {
        return cli_format_command();
    }
    if arguments >= 2 && process.argument(0) == "info" {
        return cli_info_command();
    }
    if arguments >= 2 && process.argument(0) == "test" {
        return cli_test_command();
    }
    if arguments >= 2 && process.argument(0) == "audit" {
        return cli_repository_audit_command();
    }
    if arguments >= 2 && process.argument(0) == "workflow" {
        return cli_workflow_command();
    }
    if arguments == 2 &&
        process.argument(0) == "lsp" &&
        process.argument(1) == "--stdio" {
        return cli_lsp_stdio();
    }
    if (arguments == 2 || arguments == 3) &&
        process.argument(0) == "check" {
        text project_path = process.argument(1);
        if cli_has_prefix(project_path, "--project=") {
            project_path = cli_remove_prefix(
                project_path, "--project="
            );
        }
        text output_path = "";
        if arguments == 3 {
            output_path = process.argument(2);
            if cli_has_prefix(output_path, "--output=") {
                output_path = cli_remove_prefix(
                    output_path, "--output="
                );
            } else {
                io.error("usage: openc check --project=PROJECT [--output=CHECK-RECORD.json]\n");
                return 64;
            }
        }
        return cli_check_project(project_path, output_path, true);
    }
    if arguments >= 2 && process.argument(0) == "run" {
        text project_path = process.argument(1);
        if cli_has_prefix(project_path, "--project=") {
            project_path = cli_remove_prefix(
                project_path, "--project="
            );
        }
        usize argument_start = 2;
        if arguments > 2 && process.argument(2) == "--" {
            argument_start = 3;
        } else if arguments > 2 {
            io.error("usage: openc run --project=PROJECT [-- PROGRAM-ARGUMENTS...]\n");
            return 64;
        }
        return cli_run_project(project_path, argument_start);
    }
    if arguments == 4 && process.argument(0) == "build" {
        text project_path = process.argument(1);
        text output_executable = process.argument(2);
        text timing_path = process.argument(3);
        if cli_has_prefix(project_path, "--project=") {
            project_path = cli_remove_prefix(
                project_path, "--project="
            );
        }
        if cli_has_prefix(output_executable, "--output=") {
            output_executable = cli_remove_prefix(
                output_executable, "--output="
            );
        }
        if cli_has_prefix(timing_path, "--timings=") {
            timing_path = cli_remove_prefix(
                timing_path, "--timings="
            );
        } else {
            io.error("usage: openc build --project=PROJECT --output=OUTPUT-EXE --timings=TIMINGS.json\n");
            return 64;
        }
        return build_default_windows(
            project_path, output_executable, timing_path
        );
    }
    if arguments != 1 && arguments != 2 && arguments != 3 && arguments != 8 {
        io.error("usage: openc help\n");
        return 64;
    }
    if arguments == 8 {
        return cli_eight_argument_command();
    }

    if arguments == 3 {
        return cli_three_argument_command();
    }
    return cli_observe_source_command(arguments);
}
