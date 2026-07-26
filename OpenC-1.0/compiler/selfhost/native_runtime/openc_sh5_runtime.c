#define WIN32_LEAN_AND_MEAN
#define OPENC_RUNTIME_BUILD 1
#include "openc_sh5_runtime.h"

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__TINYC__)
#  define CP_UTF8 65001u
#  define WC_ERR_INVALID_CHARS 0x00000080u
WINBASEAPI int WINAPI WideCharToMultiByte(
    UINT code_page,
    DWORD flags,
    const wchar_t *wide,
    int wide_length,
    char *bytes,
    int byte_length,
    const char *default_character,
    BOOL *used_default_character
);
#endif

typedef struct ocb_text_cache_entry {
    oc_text path;
    oc_text value;
} ocb_text_cache_entry;

static ocb_text_cache_entry *ocb_text_cache;
static uintptr_t ocb_text_cache_length;
static uintptr_t ocb_text_cache_capacity;
static oc_text ocb_executable_directory_value;

static oc_text ocb_copy_text(oc_text value) {
    uint8_t *data = (uint8_t *)oc_memory_allocate(
        value.length == 0u ? 1u : value.length,
        1u
    );
    if (value.length != 0u) {
        oc_memory_copy(data, value.data, value.length);
    }
    return (oc_text){data, value.length};
}

static char *ocb_c_string(oc_text value) {
    char *result = (char *)oc_memory_allocate(value.length + 1u, 1u);
    if (value.length != 0u) {
        oc_memory_copy(result, value.data, value.length);
    }
    result[value.length] = '\0';
    return result;
}

static oc_status ocb_failure(int32_t code, const char *message) {
    return (oc_status){code, {(const uint8_t *)message, strlen(message)}};
}

void ocb_process_initialize(int argc, char **argv) {
    if (argc > 0) {
        oc_process_initialize(argc - 1, argv + 1);
    } else {
        oc_process_initialize(0, argv);
    }
#ifdef _WIN32
    {
        wchar_t wide_path[32768];
        DWORD wide_length = GetModuleFileNameW(
            NULL, wide_path, (DWORD)(sizeof(wide_path) / sizeof(wide_path[0]))
        );
        if (wide_length != 0u &&
            wide_length < (DWORD)(sizeof(wide_path) / sizeof(wide_path[0]))) {
            while (wide_length != 0u &&
                wide_path[wide_length - 1u] != L'\\' &&
                wide_path[wide_length - 1u] != L'/') {
                --wide_length;
            }
            if (wide_length > 3u || wide_path[1] != L':') --wide_length;
            wide_path[wide_length] = L'\0';
            {
                int utf8_length = WideCharToMultiByte(
                    CP_UTF8, WC_ERR_INVALID_CHARS, wide_path, -1,
                    NULL, 0, NULL, NULL
                );
                if (utf8_length > 0) {
                    uint8_t *data = (uint8_t *)oc_memory_allocate(
                        (uintptr_t)utf8_length, 1u
                    );
                    if (WideCharToMultiByte(
                            CP_UTF8, WC_ERR_INVALID_CHARS, wide_path, -1,
                            (char *)data, utf8_length, NULL, NULL
                        ) > 0) {
                        ocb_executable_directory_value =
                            (oc_text){data, (uintptr_t)(utf8_length - 1)};
                    } else {
                        oc_memory_release(data);
                    }
                }
            }
        }
    }
#endif
    if (ocb_executable_directory_value.data == NULL) {
        ocb_executable_directory_value = ocb_copy_text(
            oc_process_current_directory()
        );
    }
}

void ocb_process_finalize(void) {
    if (ocb_executable_directory_value.data != NULL) {
        oc_memory_release((void *)ocb_executable_directory_value.data);
        ocb_executable_directory_value = OC_TEXT_EMPTY;
    }
    oc_process_finalize();
}

void *ocb_memory_alloc(uintptr_t size) {
    return oc_memory_allocate(size, 1u);
}

void ocb_memory_free(void *allocation) {
    oc_memory_release(allocation);
}

uintptr_t ocb_memory_load_usize(const void *address) {
    return *(const uintptr_t *)address;
}

void ocb_memory_store_usize(void *address, uintptr_t value) {
    *(uintptr_t *)address = value;
}

void ocb_io_print_text(oc_text value) { oc_io_print_text(value); }
void ocb_io_print_i64(int64_t value) { oc_io_print_i64(value); }
void ocb_io_print_u64(uint64_t value) { oc_io_print_u64(value); }
void ocb_io_print_bool(bool value) { oc_io_print_bool(value); }

void ocb_io_println_text(oc_text value) {
    oc_io_println_text(value);
}

void ocb_io_println_i64(int64_t value) {
    oc_io_print_i64(value);
    oc_io_println_text(OC_TEXT_EMPTY);
}

void ocb_io_println_u64(uint64_t value) {
    oc_io_print_u64(value);
    oc_io_println_text(OC_TEXT_EMPTY);
}

void ocb_io_println_bool(bool value) {
    oc_io_print_bool(value);
    oc_io_println_text(OC_TEXT_EMPTY);
}

void ocb_io_error(oc_text value) { oc_io_error_text(value); }

uintptr_t ocb_text_byte_length(oc_text value) { return value.length; }

uint8_t ocb_text_byte_at_unchecked(oc_text value, uintptr_t index) {
    return value.data[index];
}

oc_text ocb_text_from_utf8(void *data, uintptr_t length) {
    oc_text value = {(const uint8_t *)data, length};
    if (!oc_text_is_valid_utf8(value)) {
        oc_checked_failure(
            OC_STATUS_INVALID_UTF8,
            "OPENC-TEXT-UTF8-001",
            "text contains invalid UTF-8",
            0
        );
    }
    return ocb_copy_text(value);
}

oc_status ocb_text_slice(
    oc_text value,
    uintptr_t lower,
    uintptr_t upper,
    oc_text *result
) {
    if (result == NULL) {
        return ocb_failure(OC_STATUS_INVALID_ARGUMENT, "text output is null");
    }
    if (lower > upper) {
        return ocb_failure(OC_STATUS_OUT_OF_BOUNDS, "invalid text range");
    }
    *result = oc_text_slice(value, lower, upper, 0);
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

bool ocb_text_equal(oc_text left, oc_text right) {
    return oc_text_equal(left, right);
}

int32_t ocb_text_compare(oc_text left, oc_text right) {
    return oc_text_compare(left, right);
}

oc_status ocb_file_read_text(oc_text path, oc_text *value) {
    oc_file file;
    oc_owned_bytes bytes;
    oc_status opened;
    oc_status read;
    if (value == NULL) {
        return ocb_failure(OC_STATUS_INVALID_ARGUMENT, "text output is null");
    }
    opened = oc_file_open_read(path, &file);
    if (!oc_status_ok(opened)) return opened;
    read = oc_file_read_all(&file, &bytes);
    oc_file_close(file);
    if (!oc_status_ok(read)) return read;
    if (!oc_text_is_valid_utf8((oc_text){bytes.data, bytes.length})) {
        oc_memory_release(bytes.data);
        return ocb_failure(OC_STATUS_INVALID_UTF8, "file is not valid UTF-8 text");
    }
    *value = (oc_text){bytes.data, bytes.length};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocb_file_read_text_cached(oc_text path, oc_text *value) {
    uintptr_t index;
    oc_status result;
    for (index = 0; index < ocb_text_cache_length; ++index) {
        if (oc_text_equal(path, ocb_text_cache[index].path)) {
            *value = ocb_text_cache[index].value;
            return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
        }
    }
    result = ocb_file_read_text(path, value);
    if (!oc_status_ok(result)) return result;
    if (ocb_text_cache_length == ocb_text_cache_capacity) {
        uintptr_t next_capacity = ocb_text_cache_capacity == 0u
            ? 16u
            : ocb_text_cache_capacity * 2u;
        ocb_text_cache_entry *next = (ocb_text_cache_entry *)oc_memory_allocate(
            next_capacity * (uintptr_t)sizeof(ocb_text_cache_entry),
            (uintptr_t)_Alignof(ocb_text_cache_entry)
        );
        if (ocb_text_cache_length != 0u) {
            oc_memory_copy(
                next,
                ocb_text_cache,
                ocb_text_cache_length * (uintptr_t)sizeof(ocb_text_cache_entry)
            );
        }
        oc_memory_release(ocb_text_cache);
        ocb_text_cache = next;
        ocb_text_cache_capacity = next_capacity;
    }
    ocb_text_cache[ocb_text_cache_length].path = ocb_copy_text(path);
    ocb_text_cache[ocb_text_cache_length].value = *value;
    ++ocb_text_cache_length;
    return result;
}

oc_status ocb_file_write_text(oc_text path, oc_text value) {
    oc_file file;
    oc_status opened = oc_file_open_write(path, true, &file);
    oc_status written;
    if (!oc_status_ok(opened)) return opened;
    written = oc_file_write_all(&file, value);
    if (oc_status_ok(written)) written = oc_file_flush(&file);
    oc_file_close(file);
    return written;
}

oc_text ocb_path_join(oc_text left, oc_text right) {
    oc_owned_bytes bytes;
    oc_status result = oc_path_join(left, right, &bytes);
    if (!oc_status_ok(result)) {
        oc_checked_failure(result.code, "OPENC-PATH-JOIN-001", "path join failed", 0);
    }
    return (oc_text){bytes.data, bytes.length};
}

oc_text ocb_path_directory(oc_text value) {
    uintptr_t end = value.length;
    while (end != 0u) {
        uint8_t byte_value = value.data[end - 1u];
        if (byte_value == '/' || byte_value == '\\') break;
        --end;
    }
    if (end == 0u) return OC_TEXT_LITERAL(".");
    while (end > 1u && (
        value.data[end - 1u] == '/' || value.data[end - 1u] == '\\'
    )) {
        --end;
    }
    return (oc_text){value.data, end};
}

uintptr_t ocb_process_argument_count(void) {
    return oc_process_argument_count();
}

oc_text ocb_process_argument(uintptr_t index) {
    return oc_process_argument(index, 0);
}

oc_text ocb_process_executable_directory(void) {
    return ocb_executable_directory_value;
}

oc_status ocb_process_run(
    oc_text command,
    int32_t *exit_code,
    oc_text *output
) {
    char *wrapped_command;
    FILE *pipe;
    uint8_t *data;
    uintptr_t length = 0u;
    uintptr_t capacity = 4096u;
    int close_code;
    if (exit_code == NULL || output == NULL) {
        return ocb_failure(OC_STATUS_INVALID_ARGUMENT, "process output is null");
    }
    wrapped_command = (char *)oc_memory_allocate(command.length + 3u, 1u);
    wrapped_command[0] = '"';
    if (command.length != 0u) {
        oc_memory_copy(
            wrapped_command + 1u, command.data, command.length
        );
    }
    wrapped_command[command.length + 1u] = '"';
    wrapped_command[command.length + 2u] = '\0';
    pipe = _popen(wrapped_command, "rb");
    oc_memory_release(wrapped_command);
    if (pipe == NULL) {
        *exit_code = -1;
        *output = OC_TEXT_EMPTY;
        return ocb_failure(OC_STATUS_IO_ERROR, "cannot start process");
    }
    data = (uint8_t *)oc_memory_allocate(capacity, 1u);
    for (;;) {
        size_t available;
        size_t count;
        if (capacity - length < 2048u) {
            uintptr_t next_capacity = capacity * 2u;
            uint8_t *next = (uint8_t *)oc_memory_allocate(next_capacity, 1u);
            oc_memory_copy(next, data, length);
            oc_memory_release(data);
            data = next;
            capacity = next_capacity;
        }
        available = (size_t)(capacity - length);
        count = fread(data + length, 1u, available, pipe);
        length += (uintptr_t)count;
        if (count == 0u) break;
    }
    close_code = _pclose(pipe);
    *exit_code = (int32_t)close_code;
    *output = (oc_text){data, length};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

_Noreturn void ocb_checked_failure(oc_text message) {
    char *text = ocb_c_string(message);
    oc_checked_failure(OC_STATUS_CHECKED_FAILURE, "OPENC-CHECKED-001", text, 0);
}

_Noreturn void ocb_target_fault(oc_text message) {
    char *text = ocb_c_string(message);
    oc_target_fault("OPENC-TARGET-FAULT-001", text, 0);
}
