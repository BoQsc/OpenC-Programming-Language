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

unsafe i32 build_windows_c(
    text project_path,
    text output_executable,
    text generated_source,
    text runtime_root,
    text native_runtime_directory,
    text record_path,
    text tcc_executable
) {
    if emit_trusted_windows_c(project_path, generated_source) != 0 {
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
    status ran = process.run(
        d_buffer_text(command), out exit_code, out process_output
    );
    d_buffer_destroy(command);

    text result = "{\n  \"schema\": \"openc-sh5-windows-build-v1\",\n  \"status\": \"FAILED\",\n  \"backend\": \"c11-tinycc-win64\",\n  \"dmd_invoked\": false,\n  \"dub_invoked\": false,\n  \"python_invoked\": false\n}\n";
    if !ran.ok {
        file.write_text(record_path, result);
        return 1;
    }
    if exit_code == 0 {
        result = "{\n  \"schema\": \"openc-sh5-windows-build-v1\",\n  \"status\": \"PASS\",\n  \"backend\": \"c11-tinycc-win64\",\n  \"dmd_invoked\": false,\n  \"dub_invoked\": false,\n  \"python_invoked\": false\n}\n";
    } else {
        io.error(process_output);
    }
    status record_written = file.write_text(record_path, result);
    if !record_written.ok || exit_code != 0 { return 1; }
    return 0;
}
