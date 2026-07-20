import system.memory;

external(c, "oc_path_join") status runtime_join(text left, text right, out memory.Bytes bytes);
external(c, "oc_path_is_absolute") bool runtime_is_absolute(text path);

export status join(text left, text right, out memory.Bytes bytes) {
    return runtime_join(left, right, out bytes);
}

export bool is_absolute(text value) {
    return runtime_is_absolute(value);
}
