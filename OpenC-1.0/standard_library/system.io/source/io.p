external(c, "oc_io_print_text") void runtime_print_text(text value);
external(c, "oc_io_println_text") void runtime_println_text(text value);
external(c, "oc_io_print_i64") void runtime_print_i64(i64 value);
external(c, "oc_io_print_u64") void runtime_print_u64(u64 value);
external(c, "oc_io_print_bool") void runtime_print_bool(bool value);
external(c, "oc_io_error_text") void runtime_error_text(text value);

export void print(text value) {
    runtime_print_text(value);
}

export void println(text value) {
    runtime_println_text(value);
}

export void print(i8 value) { runtime_print_i64(value); }
export void print(i16 value) { runtime_print_i64(value); }
export void print(i32 value) { runtime_print_i64(value); }
export void print(i64 value) { runtime_print_i64(value); }
export void print(u8 value) { runtime_print_u64(value); }
export void print(u16 value) { runtime_print_u64(value); }
export void print(u32 value) { runtime_print_u64(value); }
export void print(u64 value) { runtime_print_u64(value); }
export void print(isize value) { runtime_print_i64(value); }
export void print(usize value) { runtime_print_u64(value); }
export void print(bool value) { runtime_print_bool(value); }

export void error(text value) {
    runtime_error_text(value);
}
