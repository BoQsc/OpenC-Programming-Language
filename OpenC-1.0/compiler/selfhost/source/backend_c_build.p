import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void c_put_response_path(
    ref DBuffer response,
    text value
) {
    d_put(response, "\""); d_put(response, value);
    d_put(response, "\"\n");
}

unsafe bool write_build_timings(
    text timing_path,
    ref BuildTimings timings,
    bool passed
) {
    if text.byte_length(timing_path) == 0 { return true; }
    DBuffer output = d_buffer_create(2048);
    d_put(output, "{\n  \"schema\": \"openc.native_build_timings.v1\",\n");
    d_put(output, "  \"status\": \"");
    if passed { d_put(output, "PASS"); } else { d_put(output, "FAIL"); }
    d_put(output, "\",\n  \"clock\": \"windows-monotonic-milliseconds\",\n");
    d_put(output, "  \"throughput_trace_schema\": \"openc.throughput_trace.v1\",\n");
    d_put(output, "  \"source_files\": ");
    d_put_usize(output, timings.source_files);
    d_put(output, ",\n  \"source_bytes\": ");
    d_put_usize(output, timings.source_bytes);
    d_put(output, ",\n  \"phases_ms\": {\n");
    d_put(output, "    \"project_load\": ");
    d_put_usize(output, timings.project_load_ms);
    d_put(output, ",\n    \"declarations\": ");
    d_put_usize(output, timings.declarations_ms);
    d_put(output, ",\n    \"resolution\": ");
    d_put_usize(output, timings.resolution_ms);
    d_put(output, ",\n    \"validation\": ");
    d_put_usize(output, timings.validation_ms);
    d_put(output, ",\n    \"lowering_and_c_emission\": ");
    d_put_usize(output, timings.lowering_emit_ms);
    d_put(output, ",\n    \"tinycc\": ");
    d_put_usize(output, timings.backend_ms);
    d_put(output, "\n  },\n  \"native_memory\": {\n");
    d_put(output, "    \"validation_initial_live_bytes\": ");
    d_put_usize(output, timings.validation_initial_live_bytes);
    d_put(output, ",\n    \"validation_peak_live_bytes\": ");
    d_put_usize(output, timings.validation_peak_live_bytes);
    d_put(output, ",\n    \"validation_peak_source_record\": ");
    d_put_usize(output, timings.validation_peak_source_record);
    d_put(output, ",\n    \"file_cache_hits\": ");
    d_put_usize(output, timings.validation_file_cache_hits);
    d_put(output, ",\n    \"file_cache_misses\": ");
    d_put_usize(output, timings.validation_file_cache_misses);
    d_put(output, ",\n    \"path_cache_hits\": ");
    d_put_usize(output, timings.validation_path_cache_hits);
    d_put(output, ",\n    \"path_cache_misses\": ");
    d_put_usize(output, timings.validation_path_cache_misses);
    d_put(output, "\n  },\n  \"total_ms\": ");
    d_put_usize(output, timings.total_ms);
    d_put(output, ",\n  \"compiler_owned\": {\n");
    d_put(output, "    \"lex_parse_ms\": ");
    d_put_usize(output, timings.lex_parse_ms);
    d_put(output, ",\n    \"index_ms\": ");
    d_put_usize(output, timings.index_ms);
    d_put(output, ",\n    \"ir_lower_ms\": ");
    d_put_usize(output, timings.ir_lower_ms);
    d_put(output, ",\n    \"c_emit_ms\": ");
    d_put_usize(output, timings.c_emit_ms);
    d_put(output, "\n  },\n  \"work\": {\n");
    d_put(output, "    \"syntax_nodes\": ");
    d_put_usize(output, timings.syntax_nodes);
    d_put(output, ",\n    \"functions\": ");
    d_put_usize(output, timings.functions);
    d_put(output, ",\n    \"instructions\": ");
    d_put_usize(output, timings.instructions);
    d_put(output, ",\n    \"output_bytes\": ");
    d_put_usize(output, timings.output_bytes);
    d_put(output, "\n  },\n  \"candidate_totals\": {\n");
    d_put(output, "    \"statement_candidates\": ");
    d_put_usize(output, timings.total_statement_candidates);
    d_put(output, ",\n    \"parent_candidates\": ");
    d_put_usize(output, timings.total_parent_candidates);
    d_put(output, ",\n    \"expression_positions\": ");
    d_put_usize(output, timings.total_expression_positions);
    d_put(output, ",\n    \"syntax_candidates\": ");
    d_put_usize(output, timings.total_syntax_candidates);
    d_put(output, ",\n    \"symbol_candidates\": ");
    d_put_usize(output, timings.total_symbol_candidates);
    d_put(output, "\n  },\n  \"slowest_function\": {\n");
    d_put(output, "    \"milliseconds\": ");
    d_put_usize(output, timings.slow_function_ms);
    d_put(output, ",\n    \"source_record\": ");
    d_put_usize(output, timings.slow_function_source);
    d_put(output, ",\n    \"syntax_node\": ");
    d_put_usize(output, timings.slow_function_node);
    d_put(output, ",\n    \"symbol\": ");
    d_put_usize(output, timings.slow_function_symbol);
    d_put(output, ",\n    \"name_start\": ");
    d_put_usize(output, timings.slow_function_name_start);
    d_put(output, ",\n    \"name_length\": ");
    d_put_usize(output, timings.slow_function_name_length);
    d_put(output, ",\n    \"statement_candidates\": ");
    d_put_usize(output, timings.slow_statement_candidates);
    d_put(output, ",\n    \"parent_candidates\": ");
    d_put_usize(output, timings.slow_parent_candidates);
    d_put(output, ",\n    \"expression_positions\": ");
    d_put_usize(output, timings.slow_expression_positions);
    d_put(output, ",\n    \"syntax_candidates\": ");
    d_put_usize(output, timings.slow_syntax_candidates);
    d_put(output, ",\n    \"symbol_candidates\": ");
    d_put_usize(output, timings.slow_symbol_candidates);
    d_put(output, "\n  },\n  \"next_slowest_functions\": [\n");
    d_put(output, "    {\"milliseconds\": ");
    d_put_usize(output, timings.second_function_ms);
    d_put(output, ", \"source_record\": ");
    d_put_usize(output, timings.second_function_source);
    d_put(output, ", \"syntax_node\": ");
    d_put_usize(output, timings.second_function_node);
    d_put(output, ", \"symbol\": ");
    d_put_usize(output, timings.second_function_symbol);
    d_put(output, ", \"name_start\": ");
    d_put_usize(output, timings.second_function_name_start);
    d_put(output, ", \"name_length\": ");
    d_put_usize(output, timings.second_function_name_length);
    d_put(output, "},\n    {\"milliseconds\": ");
    d_put_usize(output, timings.third_function_ms);
    d_put(output, ", \"source_record\": ");
    d_put_usize(output, timings.third_function_source);
    d_put(output, ", \"syntax_node\": ");
    d_put_usize(output, timings.third_function_node);
    d_put(output, ", \"symbol\": ");
    d_put_usize(output, timings.third_function_symbol);
    d_put(output, ", \"name_start\": ");
    d_put_usize(output, timings.third_function_name_start);
    d_put(output, ", \"name_length\": ");
    d_put_usize(output, timings.third_function_name_length);
    d_put(output, "}\n  ]\n}\n");
    if !output.ok {
        d_buffer_destroy(output);
        return false;
    }
    status written = file.write_text(
        timing_path, d_buffer_text(output)
    );
    d_buffer_destroy(output);
    return written.ok;
}

unsafe i32 build_windows_c_timed(
    text project_path,
    text output_executable,
    text generated_source,
    text runtime_root,
    text native_runtime_directory,
    text record_path,
    text tcc_executable,
    text timing_path
) {
    BuildTimings timings = build_timings_empty();
    usize total_started = process.monotonic_milliseconds();
    if emit_trusted_windows_c_timed(
        project_path, generated_source, timings
    ) != 0 {
        timings.total_ms =
            process.monotonic_milliseconds() - total_started;
        write_build_timings(timing_path, timings, false);
        return 1;
    }

    text common_source = path.join(
        path.join(runtime_root, "common/source"), "openc_runtime.c"
    );
    text windows_source = path.join(
        path.join(runtime_root, "windows/source"),
        "openc_platform_windows.c"
    );
    text native_source = path.join(
        native_runtime_directory, "openc_sh5_runtime.c"
    );
    text common_include = path.join(runtime_root, "common/source");
    DBuffer response = d_buffer_create(32768);
    d_put(response, "-m64\n-O2\n-o\n");
    c_put_response_path(response, output_executable);
    c_put_response_path(response, generated_source);
    c_put_response_path(response, common_source);
    c_put_response_path(response, windows_source);
    c_put_response_path(response, native_source);
    d_put(response, "-I\n"); c_put_response_path(response, common_include);
    d_put(response, "-I\n");
    c_put_response_path(response, native_runtime_directory);
    if !response.ok {
        d_buffer_destroy(response);
        return 1;
    }
    text response_path = path.join(
        path.directory(generated_source), "openc-tcc.rsp"
    );
    status response_written = file.write_text(
        response_path, d_buffer_text(response)
    );
    d_buffer_destroy(response);
    if !response_written.ok { return 1; }

    DBuffer command = d_buffer_create(
        text.byte_length(tcc_executable) +
        text.byte_length(response_path) + 16
    );
    d_put(command, "\""); d_put(command, tcc_executable);
    d_put(command, "\" @\""); d_put(command, response_path);
    d_put(command, "\"");
    if !command.ok {
        d_buffer_destroy(command);
        return 1;
    }
    i32 exit_code;
    text process_output;
    usize backend_started = process.monotonic_milliseconds();
    status ran = process.run(
        d_buffer_text(command), out exit_code, out process_output
    );
    timings.backend_ms =
        process.monotonic_milliseconds() - backend_started;
    timings.total_ms =
        process.monotonic_milliseconds() - total_started;
    d_buffer_destroy(command);

    text result = "{\n  \"schema\": \"openc-sh5-windows-build-v1\",\n  \"status\": \"FAILED\",\n  \"backend\": \"c11-tinycc-win64\",\n  \"dmd_invoked\": false,\n  \"dub_invoked\": false,\n  \"python_invoked\": false\n}\n";
    if !ran.ok {
        file.write_text(record_path, result);
        write_build_timings(timing_path, timings, false);
        return 1;
    }
    if exit_code == 0 {
        result = "{\n  \"schema\": \"openc-sh5-windows-build-v1\",\n  \"status\": \"PASS\",\n  \"backend\": \"c11-tinycc-win64\",\n  \"dmd_invoked\": false,\n  \"dub_invoked\": false,\n  \"python_invoked\": false\n}\n";
    } else {
        io.error(process_output);
    }
    status record_written = file.write_text(record_path, result);
    bool passed = record_written.ok && exit_code == 0;
    if !write_build_timings(timing_path, timings, passed) {
        return 1;
    }
    if !passed { return 1; }
    return 0;
}

unsafe i32 build_windows_c(
    text project_path,
    text output_executable,
    text generated_source,
    text runtime_root,
    text native_runtime_directory,
    text record_path,
    text tcc_executable
) {
    text timing_path = path.join(
        path.directory(record_path), "openc-build.timings.json"
    );
    return build_windows_c_timed(
        project_path, output_executable, generated_source,
        runtime_root, native_runtime_directory, record_path,
        tcc_executable, timing_path
    );
}
