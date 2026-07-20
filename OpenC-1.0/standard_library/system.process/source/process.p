external(c, "oc_process_argument_count") usize runtime_argument_count();
external(c, "oc_process_argument") text runtime_argument(usize index, u32 span_id);
external(c, "oc_process_current_directory") text runtime_current_directory();

export usize argument_count() {
    return runtime_argument_count();
}

export text argument(usize index) {
    return runtime_argument(index, 0);
}

export text current_directory() {
    return runtime_current_directory();
}
