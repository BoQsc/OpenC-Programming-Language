import system.file;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe i32 emit_bootstrap_d(text project_path, text output_directory) {
    return emit_bootstrap_d_mode(project_path, output_directory, true);
}

unsafe i32 emit_trusted_bootstrap_d(
    text project_path,
    text output_directory
) {
    return emit_bootstrap_d_mode(project_path, output_directory, false);
}

unsafe void d_put_response_path(
    ref DBuffer response,
    text directory,
    text name
) {
    d_put(response, "\"");
    d_put(response, path.join(directory, name));
    d_put(response, "\"\n");
}

unsafe i32 build_bootstrap_compiler(
    text project_path,
    text output_executable,
    text generated_directory,
    text runtime_directory,
    text library_directory,
    text record_path,
    text d_compiler
) {
    if emit_trusted_bootstrap_d(project_path, generated_directory) != 0 {
        return 1;
    }

    DBuffer response = d_buffer_create(32768);
    d_put(response, "-O\n-release\n");
    d_put(response, "-of=\"");
    d_put(response, output_executable);
    d_put(response, "\"\n");
    d_put_response_path(response, generated_directory, "openc_selfhost_main.d");
    d_put_response_path(response, generated_directory, "system_file.d");
    d_put_response_path(response, generated_directory, "system_io.d");
    d_put_response_path(response, generated_directory, "system_memory.d");
    d_put_response_path(response, generated_directory, "system_path.d");
    d_put_response_path(response, generated_directory, "system_process.d");
    d_put_response_path(response, generated_directory, "system_text.d");
    d_put_response_path(response, runtime_directory, "checked.d");
    d_put_response_path(response, runtime_directory, "console.d");
    d_put_response_path(response, runtime_directory, "file.d");
    d_put_response_path(response, runtime_directory, "freestanding.d");
    d_put_response_path(response, runtime_directory, "memory.d");
    d_put_response_path(response, runtime_directory, "platform.d");
    d_put_response_path(response, runtime_directory, "process.d");
    d_put_response_path(response, runtime_directory, "types.d");
    d_put_response_path(response, library_directory, "system_file.d");
    d_put_response_path(response, library_directory, "system_io.d");
    d_put_response_path(response, library_directory, "system_memory.d");
    d_put_response_path(response, library_directory, "system_path.d");
    d_put_response_path(response, library_directory, "system_process.d");
    d_put_response_path(response, library_directory, "system_text.d");
    if !response.ok {
        d_buffer_destroy(response);
        return 1;
    }
    text response_path = path.join(generated_directory, "bootstrap-dmd.rsp");
    status response_written = file.write_text(response_path, d_buffer_text(response));
    d_buffer_destroy(response);
    if !response_written.ok { return 1; }

    DBuffer command = d_buffer_create(
        text.byte_length(d_compiler) + text.byte_length(response_path) + 16
    );
    d_put(command, "\"");
    d_put(command, d_compiler);
    d_put(command, "\" @\"");
    d_put(command, response_path);
    d_put(command, "\"");
    if !command.ok {
        d_buffer_destroy(command);
        return 1;
    }
    i32 exit_code;
    text process_output;
    status ran = process.run(
        d_buffer_text(command), out exit_code, out process_output
    );
    d_buffer_destroy(command);

    text result = "{\n  \"schema\": \"openc-bootstrap-build-v1\",\n  \"status\": \"FAILED\",\n  \"stage_compiler_invoked\": true,\n  \"generated_sources\": 7,\n  \"runtime_sources\": 8,\n  \"library_sources\": 6\n}\n";
    if !ran.ok {
        file.write_text(record_path, result);
        return 1;
    }
    if exit_code == 0 {
        result = "{\n  \"schema\": \"openc-bootstrap-build-v1\",\n  \"status\": \"PASS\",\n  \"stage_compiler_invoked\": true,\n  \"generated_sources\": 7,\n  \"runtime_sources\": 8,\n  \"library_sources\": 6\n}\n";
    }
    status record_written = file.write_text(record_path, result);
    if !record_written.ok || exit_code != 0 { return 1; }
    return 0;
}
