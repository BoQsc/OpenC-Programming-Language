external(c, "oc_process_argument_count") usize runtime_argument_count();
external(c, "oc_process_argument") text runtime_argument(usize index, u32 span_id);
external(c, "oc_process_current_directory") text runtime_current_directory();
external(c, "oc_process_executable_directory") text runtime_executable_directory();
external(c, "oc_process_executable_path") text runtime_executable_path();
external(c, "oc_process_run") status runtime_run(text command, out i32 exit_code, out text output);

export usize argument_count() {
    return runtime_argument_count();
}

export text argument(usize index) {
    return runtime_argument(index, 0);
}

export text current_directory() {
    return runtime_current_directory();
}

export text executable_directory() {
    return runtime_executable_directory();
}

export text executable_path() {
    return runtime_executable_path();
}

export status run(text command, out i32 exit_code, out text output) {
    return runtime_run(command, out exit_code, out output);
}
