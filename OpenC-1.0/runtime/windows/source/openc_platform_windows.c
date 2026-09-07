#define WIN32_LEAN_AND_MEAN
#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"
#include <windows.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>

#if defined(__TINYC__)
#  define CP_UTF8 65001u
#  define WC_ERR_INVALID_CHARS 0x00000080u
#  define MB_ERR_INVALID_CHARS 0x00000008u
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
WINBASEAPI int WINAPI MultiByteToWideChar(
    UINT code_page,
    DWORD flags,
    const char *bytes,
    int byte_length,
    wchar_t *wide,
    int wide_length
);
#endif

#ifndef LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR
#  define LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR 0x00000100u
#endif
#ifndef LOAD_LIBRARY_SEARCH_SYSTEM32
#  define LOAD_LIBRARY_SEARCH_SYSTEM32 0x00000800u
#endif

typedef int (WINAPI *ocw_message_box_w_fn)(HWND, LPCWSTR, LPCWSTR, UINT);
typedef HWND (WINAPI *ocw_get_desktop_window_fn)(void);
typedef BOOL (WINAPI *ocw_is_window_fn)(HWND);
typedef int (WINAPI *ocw_get_window_text_length_w_fn)(HWND);
typedef int (WINAPI *ocw_get_window_text_w_fn)(HWND, LPWSTR, int);
typedef HDC (WINAPI *ocw_get_dc_fn)(HWND);
typedef int (WINAPI *ocw_release_dc_fn)(HWND, HDC);
typedef int (WINAPI *ocw_fill_rect_fn)(HDC, const RECT *, HBRUSH);
typedef HBRUSH (WINAPI *ocw_create_solid_brush_fn)(COLORREF);
typedef BOOL (WINAPI *ocw_delete_object_fn)(HGDIOBJ);
typedef int (WINAPI *ocw_wsa_startup_fn)(WORD, void *);
typedef int (WINAPI *ocw_wsa_cleanup_fn)(void);
typedef int (WINAPI *ocw_wsa_get_last_error_fn)(void);
typedef int (WINAPI *ocw_get_host_name_w_fn)(LPWSTR, int);
typedef LONG (WINAPI *ocw_reg_open_key_ex_w_fn)(
    HKEY, LPCWSTR, DWORD, REGSAM, PHKEY
);
typedef LONG (WINAPI *ocw_reg_query_value_ex_w_fn)(
    HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD
);
typedef LONG (WINAPI *ocw_reg_close_key_fn)(HKEY);
typedef HRESULT (WINAPI *ocw_sh_get_folder_path_w_fn)(
    HWND, int, HANDLE, DWORD, LPWSTR
);
typedef HINSTANCE (WINAPI *ocw_shell_execute_w_fn)(
    HWND, LPCWSTR, LPCWSTR, LPCWSTR, LPCWSTR, INT
);

typedef struct oc_windows_allocation_header {
    void *base;
    uintptr_t requested_size;
    uintptr_t requested_alignment;
} oc_windows_allocation_header;

static bool oc_is_power_of_two(uintptr_t value) {
    return value != 0u && (value & (value - 1u)) == 0u;
}

static uintptr_t oc_normalize_alignment(uintptr_t alignment) {
    uintptr_t minimum = (uintptr_t)_Alignof(long double);
    if (alignment < minimum) alignment = minimum;
    return alignment;
}

static void oc_windows_write(DWORD standard_handle, const uint8_t *data, uintptr_t length) {
    HANDLE handle = GetStdHandle(standard_handle);
    if (handle == NULL || handle == INVALID_HANDLE_VALUE) return;
    while (length != 0u) {
        DWORD chunk = length > 0x7fffffffu ? 0x7fffffffu : (DWORD)length;
        DWORD written = 0;
        if (!WriteFile(handle, data, chunk, &written, NULL) || written == 0u) return;
        data += written;
        length -= written;
    }
}

void oc_platform_write_stdout(const uint8_t *data, uintptr_t length) {
    oc_windows_write(STD_OUTPUT_HANDLE, data, length);
}

void oc_platform_write_stderr(const uint8_t *data, uintptr_t length) {
    oc_windows_write(STD_ERROR_HANDLE, data, length);
}

void *oc_platform_allocate(uintptr_t size, uintptr_t alignment) {
    if (size == 0u) size = 1u;
    alignment = oc_normalize_alignment(alignment);
    if (!oc_is_power_of_two(alignment)) return NULL;

    const uintptr_t header_size = (uintptr_t)sizeof(oc_windows_allocation_header);
    if (size > UINTPTR_MAX - header_size - (alignment - 1u)) return NULL;
    const uintptr_t total = size + header_size + alignment - 1u;

    void *base = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)total);
    if (base == NULL) return NULL;

    uintptr_t candidate = (uintptr_t)base + header_size;
    uintptr_t aligned = (candidate + alignment - 1u) & ~(alignment - 1u);
    oc_windows_allocation_header *header =
        (oc_windows_allocation_header *)(void *)(aligned - header_size);
    header->base = base;
    header->requested_size = size;
    header->requested_alignment = alignment;
    return (void *)aligned;
}

void oc_platform_release(void *allocation) {
    if (allocation == NULL) return;
    const uintptr_t header_size = (uintptr_t)sizeof(oc_windows_allocation_header);
    oc_windows_allocation_header *header =
        (oc_windows_allocation_header *)(void *)((uintptr_t)allocation - header_size);
    if (header->base != NULL) {
        HeapFree(GetProcessHeap(), 0, header->base);
    }
}

oc_status oc_platform_current_directory(oc_owned_bytes *out_bytes) {
    if (out_bytes == NULL) {
        return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("current-directory output is null")};
    }
    DWORD required = GetCurrentDirectoryW(0, NULL);
    if (required == 0u) {
        return (oc_status){OC_STATUS_IO_ERROR, OC_TEXT_LITERAL("cannot query current directory")};
    }
    wchar_t *wide = (wchar_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)required * sizeof(wchar_t));
    if (wide == NULL) {
        return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate current-directory buffer")};
    }
    if (GetCurrentDirectoryW(required, wide) == 0u) {
        HeapFree(GetProcessHeap(), 0, wide);
        return (oc_status){OC_STATUS_IO_ERROR, OC_TEXT_LITERAL("cannot read current directory")};
    }
    int utf8_length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, NULL, 0, NULL, NULL);
    if (utf8_length <= 0) {
        HeapFree(GetProcessHeap(), 0, wide);
        return (oc_status){OC_STATUS_IO_ERROR, OC_TEXT_LITERAL("cannot encode current directory")};
    }
    uint8_t *data = (uint8_t *)oc_platform_allocate((uintptr_t)utf8_length, 1u);
    if (data == NULL) {
        HeapFree(GetProcessHeap(), 0, wide);
        return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate UTF-8 path")};
    }
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1,
                            (char *)data, utf8_length, NULL, NULL) <= 0) {
        HeapFree(GetProcessHeap(), 0, wide);
        oc_platform_release(data);
        return (oc_status){OC_STATUS_IO_ERROR, OC_TEXT_LITERAL("cannot encode current directory")};
    }
    HeapFree(GetProcessHeap(), 0, wide);
    *out_bytes = (oc_owned_bytes){data, (uintptr_t)(utf8_length - 1)};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

_Noreturn void oc_platform_exit(int32_t code) {
    ExitProcess((UINT)code);
}

static oc_status ocw_status_code(uint32_t code, const char *operation) {
    int32_t status_code;
    if (code == 0u) code = (uint32_t)OC_STATUS_TARGET_FAULT;
    status_code = code <= 0x7fffffffu ? (int32_t)code : OC_STATUS_TARGET_FAULT;
    return (oc_status){
        status_code,
        {(const uint8_t *)operation, (uintptr_t)strlen(operation)}
    };
}

static oc_status ocw_last_error_status(const char *operation) {
    return ocw_status_code((uint32_t)GetLastError(), operation);
}

static HMODULE ocw_load_system_library(const wchar_t *name) {
    return LoadLibraryExW(name, NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
}

static FARPROC ocw_required_symbol(
    HMODULE module, const char *name, oc_status *failure
) {
    FARPROC symbol;
    if (module == NULL) {
        *failure = ocw_last_error_status("cannot load documented Windows system DLL");
        return NULL;
    }
    symbol = GetProcAddress(module, name);
    if (symbol == NULL) {
        *failure = ocw_last_error_status("cannot resolve documented Windows API");
    }
    return symbol;
}

oc_status ocw_utf16_encode(
    oc_text value, uint8_t **data, uintptr_t *units
) {
    int required;
    wchar_t *wide;
    if (data == NULL || units == NULL) {
        return (oc_status){
            OC_STATUS_INVALID_ARGUMENT,
            OC_TEXT_LITERAL("UTF-16 output is null")
        };
    }
    *data = NULL;
    *units = 0u;
    if (value.length == 0u) {
        wide = (wchar_t *)oc_platform_allocate(sizeof(wchar_t), sizeof(wchar_t));
        if (wide == NULL) {
            return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate UTF-16 text")};
        }
        wide[0] = L'\0';
        *data = (uint8_t *)(void *)wide;
        return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
    }
    if (value.length > (uintptr_t)INT_MAX) {
        return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("UTF-8 text is too large")};
    }
    required = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)value.data,
        (int)value.length, NULL, 0
    );
    if (required <= 0) return ocw_last_error_status("invalid UTF-8 Windows text");
    if ((uintptr_t)required > (UINTPTR_MAX / sizeof(wchar_t)) - 1u) {
        return (oc_status){OC_STATUS_INTEGER_OVERFLOW, OC_TEXT_LITERAL("UTF-16 text size overflow")};
    }
    wide = (wchar_t *)oc_platform_allocate(
        ((uintptr_t)required + 1u) * sizeof(wchar_t), sizeof(wchar_t)
    );
    if (wide == NULL) {
        return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate UTF-16 text")};
    }
    if (MultiByteToWideChar(
            CP_UTF8, MB_ERR_INVALID_CHARS, (const char *)value.data,
            (int)value.length, wide, required
        ) != required) {
        oc_status failure = ocw_last_error_status("cannot encode UTF-16 Windows text");
        oc_platform_release(wide);
        return failure;
    }
    wide[required] = L'\0';
    *data = (uint8_t *)(void *)wide;
    *units = (uintptr_t)required;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_utf16_decode(
    const uint8_t *data, uintptr_t units,
    uint8_t **utf8_data, uintptr_t *utf8_length
) {
    int required;
    uint8_t *bytes;
    if (utf8_data == NULL || utf8_length == NULL ||
        (data == NULL && units != 0u)) {
        return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("UTF-8 output is null")};
    }
    *utf8_data = NULL;
    *utf8_length = 0u;
    if (units == 0u) {
        bytes = (uint8_t *)oc_platform_allocate(1u, 1u);
        if (bytes == NULL) return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate UTF-8 text")};
        bytes[0] = 0u;
        *utf8_data = bytes;
        return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
    }
    if (units > (uintptr_t)INT_MAX) {
        return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("UTF-16 text is too large")};
    }
    required = WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, (const wchar_t *)(const void *)data,
        (int)units, NULL, 0, NULL, NULL
    );
    if (required <= 0) return ocw_last_error_status("invalid UTF-16 Windows text");
    bytes = (uint8_t *)oc_platform_allocate((uintptr_t)required + 1u, 1u);
    if (bytes == NULL) return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate UTF-8 text")};
    if (WideCharToMultiByte(
            CP_UTF8, WC_ERR_INVALID_CHARS,
            (const wchar_t *)(const void *)data, (int)units,
            (char *)bytes, required, NULL, NULL
        ) != required) {
        oc_status failure = ocw_last_error_status("cannot decode UTF-16 Windows text");
        oc_platform_release(bytes);
        return failure;
    }
    bytes[required] = 0u;
    *utf8_data = bytes;
    *utf8_length = (uintptr_t)required;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_buffer_free(void *data) { oc_platform_release(data); }

oc_text ocw_text_view(uint8_t *data, uintptr_t length) {
    oc_text result = {data, length};
    return result;
}

uint32_t ocw_last_error(void) { return (uint32_t)GetLastError(); }

oc_status ocw_format_error(
    uint32_t code, uint8_t **utf8_data, uintptr_t *utf8_length
) {
    wchar_t *message = NULL;
    DWORD units;
    oc_status result;
    units = FormatMessageW(
        FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
            FORMAT_MESSAGE_IGNORE_INSERTS,
        NULL, (DWORD)code, 0, (LPWSTR)(void *)&message, 0, NULL
    );
    if (units == 0u) return ocw_last_error_status("cannot format Windows error");
    while (units != 0u && (message[units - 1u] == L'\r' ||
                           message[units - 1u] == L'\n')) {
        --units;
    }
    result = ocw_utf16_decode(
        (const uint8_t *)(const void *)message, (uintptr_t)units,
        utf8_data, utf8_length
    );
    LocalFree(message);
    return result;
}

oc_status ocw_file_open(
    const uint8_t *path, bool write, bool create, bool truncate,
    bool exclusive, uintptr_t *handle
) {
    DWORD access = write ? (GENERIC_READ | GENERIC_WRITE) : GENERIC_READ;
    DWORD share = exclusive ? 0u : (FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE);
    DWORD disposition = OPEN_EXISTING;
    HANDLE file;
    if (path == NULL || handle == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file-open argument is null")};
    if (create && exclusive) disposition = CREATE_NEW;
    else if (create && truncate) disposition = CREATE_ALWAYS;
    else if (create) disposition = OPEN_ALWAYS;
    else if (truncate) disposition = TRUNCATE_EXISTING;
    file = CreateFileW(
        (const wchar_t *)(const void *)path, access, share, NULL, disposition,
        FILE_ATTRIBUTE_NORMAL, NULL
    );
    if (file == INVALID_HANDLE_VALUE) return ocw_last_error_status("CreateFileW failed");
    *handle = (uintptr_t)file;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_file_read(
    uintptr_t handle, uint8_t **data, uintptr_t *length
) {
    DWORD size_high = 0u;
    DWORD size_low;
    uint64_t size;
    uint8_t *bytes;
    uintptr_t done = 0u;
    if (handle == 0u || data == NULL || length == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file-read argument is null")};
    SetLastError(NO_ERROR);
    size_low = GetFileSize((HANDLE)handle, &size_high);
    if (size_low == INVALID_FILE_SIZE && GetLastError() != NO_ERROR) return ocw_last_error_status("GetFileSize failed");
    size = ((uint64_t)size_high << 32u) | (uint64_t)size_low;
    if (size > (uint64_t)UINTPTR_MAX - 1u) return (oc_status){OC_STATUS_INTEGER_OVERFLOW, OC_TEXT_LITERAL("file is too large")};
    bytes = (uint8_t *)oc_platform_allocate((uintptr_t)size + 1u, 1u);
    if (bytes == NULL) return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate file buffer")};
    size_high = 0u;
    SetLastError(NO_ERROR);
    if (SetFilePointer((HANDLE)handle, 0, (LONG *)&size_high, FILE_BEGIN) == INVALID_SET_FILE_POINTER && GetLastError() != NO_ERROR) {
        oc_status failure = ocw_last_error_status("SetFilePointer failed");
        oc_platform_release(bytes);
        return failure;
    }
    while (done < (uintptr_t)size) {
        DWORD chunk = (uintptr_t)size - done > 0x7fffffffu ? 0x7fffffffu : (DWORD)((uintptr_t)size - done);
        DWORD observed = 0u;
        if (!ReadFile((HANDLE)handle, bytes + done, chunk, &observed, NULL)) {
            oc_status failure = ocw_last_error_status("ReadFile failed");
            oc_platform_release(bytes);
            return failure;
        }
        if (observed == 0u) break;
        done += (uintptr_t)observed;
    }
    bytes[done] = 0u;
    *data = bytes;
    *length = done;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_file_write(
    uintptr_t handle, const uint8_t *data, uintptr_t length
) {
    uintptr_t done = 0u;
    if (handle == 0u || (data == NULL && length != 0u)) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file-write argument is null")};
    while (done < length) {
        DWORD chunk = length - done > 0x7fffffffu ? 0x7fffffffu : (DWORD)(length - done);
        DWORD written = 0u;
        if (!WriteFile((HANDLE)handle, data + done, chunk, &written, NULL)) return ocw_last_error_status("WriteFile failed");
        if (written == 0u) return (oc_status){OC_STATUS_IO_ERROR, OC_TEXT_LITERAL("WriteFile made no progress")};
        done += (uintptr_t)written;
    }
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_file_write_text(uintptr_t handle, oc_text value) {
    return ocw_file_write(handle, value.data, value.length);
}

oc_status ocw_file_write_byte(uintptr_t handle, uint8_t value) {
    return ocw_file_write(handle, &value, 1u);
}

oc_status ocw_file_flush(uintptr_t handle) {
    if (handle == 0u) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file handle is null")};
    if (!FlushFileBuffers((HANDLE)handle)) return ocw_last_error_status("FlushFileBuffers failed");
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_file_remove(const uint8_t *path) {
    if (path == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file path is null")};
    if (!DeleteFileW((const wchar_t *)(const void *)path)) return ocw_last_error_status("DeleteFileW failed");
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_close_handle(uintptr_t handle) {
    if (handle != 0u && (HANDLE)handle != INVALID_HANDLE_VALUE) CloseHandle((HANDLE)handle);
}

oc_status ocw_heap_create(uintptr_t *heap) {
    HANDLE value;
    if (heap == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("heap output is null")};
    value = HeapCreate(0u, 0u, 0u);
    if (value == NULL) return ocw_last_error_status("HeapCreate failed");
    *heap = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

uintptr_t ocw_process_heap(void) { return (uintptr_t)GetProcessHeap(); }

oc_status ocw_heap_allocate(
    uintptr_t heap, uintptr_t length, uint8_t **data
) {
    void *value;
    if (heap == 0u || data == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("heap allocation argument is null")};
    if (length == 0u) length = 1u;
    value = HeapAlloc((HANDLE)heap, HEAP_ZERO_MEMORY, (SIZE_T)length);
    if (value == NULL) return ocw_last_error_status("HeapAlloc failed");
    *data = (uint8_t *)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_heap_resize(
    uintptr_t heap, void *data, uintptr_t length, uint8_t **resized
) {
    void *value;
    if (heap == 0u || data == NULL || resized == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("heap resize argument is null")};
    *resized = NULL;
    if (length == 0u) length = 1u;
    value = HeapReAlloc((HANDLE)heap, HEAP_ZERO_MEMORY, data, (SIZE_T)length);
    if (value == NULL) {
        oc_status failure = ocw_last_error_status("HeapReAlloc failed");
        HeapFree((HANDLE)heap, 0u, data);
        return failure;
    }
    *resized = (uint8_t *)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_heap_free(uintptr_t heap, void *data) {
    if (heap != 0u && data != NULL) HeapFree((HANDLE)heap, 0u, data);
}

void ocw_heap_destroy(uintptr_t heap) { if (heap != 0u) HeapDestroy((HANDLE)heap); }

oc_status ocw_process_start(
    const uint8_t *command, const uint8_t *directory, bool has_directory,
    bool hidden, uintptr_t *process_handle, uintptr_t *thread_handle,
    uint32_t *process_id
) {
    STARTUPINFOW startup;
    PROCESS_INFORMATION process;
    const wchar_t *source = (const wchar_t *)(const void *)command;
    wchar_t *mutable_command;
    SIZE_T command_bytes;
    DWORD flags = CREATE_UNICODE_ENVIRONMENT;
    BOOL created;
    if (command == NULL || process_handle == NULL || thread_handle == NULL || process_id == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("process-start argument is null")};
    command_bytes = ((SIZE_T)lstrlenW(source) + 1u) * sizeof(wchar_t);
    mutable_command = (wchar_t *)HeapAlloc(GetProcessHeap(), 0u, command_bytes);
    if (mutable_command == NULL) return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate process command")};
    memcpy(mutable_command, source, command_bytes);
    memset(&startup, 0, sizeof(startup));
    memset(&process, 0, sizeof(process));
    startup.cb = sizeof(startup);
    if (hidden) {
        startup.dwFlags = STARTF_USESHOWWINDOW;
        startup.wShowWindow = SW_HIDE;
        flags |= CREATE_NO_WINDOW;
    }
    created = CreateProcessW(
        NULL, mutable_command, NULL, NULL, FALSE, flags, NULL,
        has_directory ? (const wchar_t *)(const void *)directory : NULL,
        &startup, &process
    );
    if (!created) {
        oc_status failure = ocw_last_error_status("CreateProcessW failed");
        HeapFree(GetProcessHeap(), 0u, mutable_command);
        return failure;
    }
    HeapFree(GetProcessHeap(), 0u, mutable_command);
    *process_handle = (uintptr_t)process.hProcess;
    *thread_handle = (uintptr_t)process.hThread;
    *process_id = (uint32_t)process.dwProcessId;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_wait_handle(
    uintptr_t handle, uint32_t milliseconds, bool infinite, bool *timed_out
) {
    DWORD result;
    if (handle == 0u || timed_out == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("wait argument is null")};
    result = WaitForSingleObject((HANDLE)handle, infinite ? INFINITE : (DWORD)milliseconds);
    if (result == WAIT_FAILED) return ocw_last_error_status("WaitForSingleObject failed");
    *timed_out = result == WAIT_TIMEOUT;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_process_exit_code(uintptr_t handle, uint32_t *exit_code) {
    DWORD value;
    if (handle == 0u || exit_code == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("process exit-code argument is null")};
    if (!GetExitCodeProcess((HANDLE)handle, &value)) return ocw_last_error_status("GetExitCodeProcess failed");
    *exit_code = (uint32_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_event_create(
    bool manual_reset, bool initially_signaled, uintptr_t *handle
) {
    HANDLE value;
    if (handle == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("event output is null")};
    value = CreateEventW(NULL, manual_reset, initially_signaled, NULL);
    if (value == NULL) return ocw_last_error_status("CreateEventW failed");
    *handle = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_event_set(uintptr_t handle) {
    if (handle == 0u) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("event handle is null")};
    if (!SetEvent((HANDLE)handle)) return ocw_last_error_status("SetEvent failed");
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

uint32_t ocw_current_thread_id(void) { return (uint32_t)GetCurrentThreadId(); }
void ocw_sleep(uint32_t milliseconds) { Sleep((DWORD)milliseconds); }

oc_status ocw_console_write(
    const uint8_t *wide, uintptr_t units, oc_text utf8,
    bool standard_error
) {
    HANDLE handle = GetStdHandle(standard_error ? STD_ERROR_HANDLE : STD_OUTPUT_HANDLE);
    DWORD mode;
    if (handle == NULL || handle == INVALID_HANDLE_VALUE) return ocw_last_error_status("GetStdHandle failed");
    if (GetConsoleMode(handle, &mode)) {
        uintptr_t done = 0u;
        while (done < units) {
            DWORD chunk = units - done > 0x7fffffffu ? 0x7fffffffu : (DWORD)(units - done);
            DWORD written = 0u;
            if (!WriteConsoleW(handle, ((const wchar_t *)(const void *)wide) + done, chunk, &written, NULL)) return ocw_last_error_status("WriteConsoleW failed");
            if (written == 0u) break;
            done += (uintptr_t)written;
        }
    } else {
        uintptr_t done = 0u;
        while (done < utf8.length) {
            DWORD chunk = utf8.length - done > 0x7fffffffu ? 0x7fffffffu : (DWORD)(utf8.length - done);
            DWORD written = 0u;
            if (!WriteFile(handle, utf8.data + done, chunk, &written, NULL)) return ocw_last_error_status("WriteFile console fallback failed");
            if (written == 0u) break;
            done += (uintptr_t)written;
        }
    }
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_window_desktop(uintptr_t *window) {
    HMODULE library;
    ocw_get_desktop_window_fn function;
    HWND value;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    if (window == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("window output is null")};
    library = ocw_load_system_library(L"user32.dll");
    function = (ocw_get_desktop_window_fn)(void *)ocw_required_symbol(library, "GetDesktopWindow", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    value = function();
    FreeLibrary(library);
    if (value == NULL) return ocw_last_error_status("GetDesktopWindow failed");
    *window = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

bool ocw_window_valid(uintptr_t window) {
    HMODULE library = ocw_load_system_library(L"user32.dll");
    ocw_is_window_fn function;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    BOOL result = FALSE;
    function = (ocw_is_window_fn)(void *)ocw_required_symbol(library, "IsWindow", &failure);
    if (function != NULL) result = function((HWND)window);
    if (library) FreeLibrary(library);
    return result != FALSE;
}

oc_status ocw_window_title(
    uintptr_t window, uint8_t **utf8_data, uintptr_t *utf8_length
) {
    HMODULE library = ocw_load_system_library(L"user32.dll");
    ocw_get_window_text_length_w_fn length_function;
    ocw_get_window_text_w_fn text_function;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    int length;
    wchar_t *wide;
    oc_status result;
    length_function = (ocw_get_window_text_length_w_fn)(void *)ocw_required_symbol(library, "GetWindowTextLengthW", &failure);
    text_function = (ocw_get_window_text_w_fn)(void *)ocw_required_symbol(library, "GetWindowTextW", &failure);
    if (length_function == NULL || text_function == NULL) { if (library) FreeLibrary(library); return failure; }
    length = length_function((HWND)window);
    if (length < 0) { FreeLibrary(library); return ocw_last_error_status("GetWindowTextLengthW failed"); }
    wide = (wchar_t *)oc_platform_allocate(((uintptr_t)length + 1u) * sizeof(wchar_t), sizeof(wchar_t));
    if (wide == NULL) { FreeLibrary(library); return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate window title")}; }
    if (length != 0 && text_function((HWND)window, wide, length + 1) == 0) {
        oc_status text_failure = ocw_last_error_status("GetWindowTextW failed");
        oc_platform_release(wide); FreeLibrary(library); return text_failure;
    }
    wide[length] = L'\0';
    FreeLibrary(library);
    result = ocw_utf16_decode((const uint8_t *)(const void *)wide, (uintptr_t)length, utf8_data, utf8_length);
    oc_platform_release(wide);
    return result;
}

oc_status ocw_message_box(
    uintptr_t owner, const uint8_t *message, const uint8_t *title,
    uint32_t flags, int32_t *selection
) {
    HMODULE library = ocw_load_system_library(L"user32.dll");
    ocw_message_box_w_fn function;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    int result;
    function = (ocw_message_box_w_fn)(void *)ocw_required_symbol(library, "MessageBoxW", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    result = function((HWND)owner, (LPCWSTR)(const void *)message, (LPCWSTR)(const void *)title, (UINT)flags);
    FreeLibrary(library);
    if (result == 0) return ocw_last_error_status("MessageBoxW failed");
    if (selection != NULL) *selection = (int32_t)result;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_dc_acquire(uintptr_t window, uintptr_t *dc) {
    HMODULE library = ocw_load_system_library(L"user32.dll");
    ocw_get_dc_fn function;
    HDC value;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    if (dc == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("device-context output is null")};
    function = (ocw_get_dc_fn)(void *)ocw_required_symbol(library, "GetDC", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    value = function((HWND)window);
    FreeLibrary(library);
    if (value == NULL) return ocw_last_error_status("GetDC failed");
    *dc = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_dc_release(uintptr_t window, uintptr_t dc) {
    HMODULE library = ocw_load_system_library(L"user32.dll");
    ocw_release_dc_fn function;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    function = (ocw_release_dc_fn)(void *)ocw_required_symbol(library, "ReleaseDC", &failure);
    if (function != NULL && dc != 0u) function((HWND)window, (HDC)dc);
    if (library) FreeLibrary(library);
}

oc_status ocw_brush_create(uint32_t color, uintptr_t *brush) {
    HMODULE library = ocw_load_system_library(L"gdi32.dll");
    ocw_create_solid_brush_fn function;
    HBRUSH value;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    if (brush == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("brush output is null")};
    function = (ocw_create_solid_brush_fn)(void *)ocw_required_symbol(library, "CreateSolidBrush", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    value = function((COLORREF)color);
    FreeLibrary(library);
    if (value == NULL) return ocw_last_error_status("CreateSolidBrush failed");
    *brush = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_gdi_delete(uintptr_t object) {
    HMODULE library = ocw_load_system_library(L"gdi32.dll");
    ocw_delete_object_fn function;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    function = (ocw_delete_object_fn)(void *)ocw_required_symbol(library, "DeleteObject", &failure);
    if (function != NULL && object != 0u) function((HGDIOBJ)object);
    if (library) FreeLibrary(library);
}

oc_status ocw_fill_rectangle(
    uintptr_t dc, int32_t left, int32_t top, int32_t right, int32_t bottom,
    uintptr_t brush
) {
    HMODULE library = ocw_load_system_library(L"user32.dll");
    ocw_fill_rect_fn function;
    RECT rectangle;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    function = (ocw_fill_rect_fn)(void *)ocw_required_symbol(library, "FillRect", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    rectangle.left = left; rectangle.top = top; rectangle.right = right; rectangle.bottom = bottom;
    if (function((HDC)dc, &rectangle, (HBRUSH)brush) == 0) { FreeLibrary(library); return ocw_last_error_status("FillRect failed"); }
    FreeLibrary(library);
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_module_path(uint8_t **utf8_data, uintptr_t *utf8_length) {
    DWORD capacity = 512u;
    wchar_t *wide = NULL;
    DWORD length;
    oc_status result;
    while (capacity <= 32768u) {
        wide = (wchar_t *)oc_platform_allocate((uintptr_t)capacity * sizeof(wchar_t), sizeof(wchar_t));
        if (wide == NULL) return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate module path")};
        length = GetModuleFileNameW(NULL, wide, capacity);
        if (length == 0u) { oc_status failure = ocw_last_error_status("GetModuleFileNameW failed"); oc_platform_release(wide); return failure; }
        if (length < capacity - 1u) break;
        oc_platform_release(wide); wide = NULL; capacity *= 2u;
    }
    if (wide == NULL) return (oc_status){OC_STATUS_OUT_OF_BOUNDS, OC_TEXT_LITERAL("module path is too long")};
    result = ocw_utf16_decode((const uint8_t *)(const void *)wide, (uintptr_t)length, utf8_data, utf8_length);
    oc_platform_release(wide);
    return result;
}

oc_status ocw_library_load_system(const uint8_t *name, uintptr_t *module) {
    HMODULE value;
    if (name == NULL || module == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("library-load argument is null")};
    value = LoadLibraryExW((LPCWSTR)(const void *)name, NULL, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (value == NULL) return ocw_last_error_status("LoadLibraryExW failed");
    *module = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_library_close(uintptr_t module) { if (module != 0u) FreeLibrary((HMODULE)module); }

oc_status ocw_network_start(uintptr_t *module) {
    HMODULE library = ocw_load_system_library(L"ws2_32.dll");
    ocw_wsa_startup_fn function;
    unsigned char data[512];
    int result;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    if (module == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("network-session output is null")};
    function = (ocw_wsa_startup_fn)(void *)ocw_required_symbol(library, "WSAStartup", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    memset(data, 0, sizeof(data));
    result = function((WORD)0x0202u, data);
    if (result != 0) { FreeLibrary(library); return ocw_status_code((uint32_t)result, "WSAStartup failed"); }
    *module = (uintptr_t)library;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void ocw_network_stop(uintptr_t module) {
    HMODULE library = (HMODULE)module;
    ocw_wsa_cleanup_fn function;
    if (library == NULL) return;
    function = (ocw_wsa_cleanup_fn)(void *)GetProcAddress(library, "WSACleanup");
    if (function != NULL) function();
    FreeLibrary(library);
}

oc_status ocw_network_host_name(
    uintptr_t module, uint8_t **utf8_data, uintptr_t *utf8_length
) {
    HMODULE library = (HMODULE)module;
    ocw_get_host_name_w_fn function;
    ocw_wsa_get_last_error_fn error_function;
    wchar_t wide[256];
    int result;
    if (library == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("network session is closed")};
    function = (ocw_get_host_name_w_fn)(void *)GetProcAddress(library, "GetHostNameW");
    error_function = (ocw_wsa_get_last_error_fn)(void *)GetProcAddress(library, "WSAGetLastError");
    if (function == NULL) return ocw_last_error_status("GetHostNameW is unavailable");
    result = function(wide, 256);
    if (result != 0) return ocw_status_code(error_function ? (uint32_t)error_function() : 1u, "GetHostNameW failed");
    return ocw_utf16_decode((const uint8_t *)(const void *)wide, (uintptr_t)lstrlenW(wide), utf8_data, utf8_length);
}

oc_status ocw_registry_open_current_user(
    const uint8_t *subkey, bool write, uintptr_t *key
) {
    HMODULE library = ocw_load_system_library(L"advapi32.dll");
    ocw_reg_open_key_ex_w_fn function;
    HKEY value = NULL;
    LONG result;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    if (subkey == NULL || key == NULL) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("registry-open argument is null")};
    function = (ocw_reg_open_key_ex_w_fn)(void *)ocw_required_symbol(library, "RegOpenKeyExW", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    result = function(HKEY_CURRENT_USER, (LPCWSTR)(const void *)subkey, 0u, write ? (KEY_READ | KEY_WRITE) : KEY_READ, &value);
    FreeLibrary(library);
    if (result != ERROR_SUCCESS) return ocw_status_code((uint32_t)result, "RegOpenKeyExW failed");
    *key = (uintptr_t)value;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status ocw_registry_read_text(
    uintptr_t key, const uint8_t *name,
    uint8_t **utf8_data, uintptr_t *utf8_length
) {
    HMODULE library = ocw_load_system_library(L"advapi32.dll");
    ocw_reg_query_value_ex_w_fn function;
    DWORD kind = 0u;
    DWORD bytes = 0u;
    uint8_t *wide;
    LONG result;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    function = (ocw_reg_query_value_ex_w_fn)(void *)ocw_required_symbol(library, "RegQueryValueExW", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    result = function((HKEY)key, (LPCWSTR)(const void *)name, NULL, &kind, NULL, &bytes);
    if (result != ERROR_SUCCESS || (kind != REG_SZ && kind != REG_EXPAND_SZ)) { FreeLibrary(library); return ocw_status_code((uint32_t)(result == ERROR_SUCCESS ? ERROR_INVALID_DATATYPE : result), "registry value is not text"); }
    wide = (uint8_t *)oc_platform_allocate((uintptr_t)bytes + sizeof(wchar_t), sizeof(wchar_t));
    if (wide == NULL) { FreeLibrary(library); return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate registry text")}; }
    result = function((HKEY)key, (LPCWSTR)(const void *)name, NULL, &kind, wide, &bytes);
    FreeLibrary(library);
    if (result != ERROR_SUCCESS) { oc_platform_release(wide); return ocw_status_code((uint32_t)result, "RegQueryValueExW failed"); }
    while (bytes >= sizeof(wchar_t) && ((wchar_t *)(void *)wide)[bytes / sizeof(wchar_t) - 1u] == L'\0') bytes -= sizeof(wchar_t);
    failure = ocw_utf16_decode(wide, (uintptr_t)(bytes / sizeof(wchar_t)), utf8_data, utf8_length);
    oc_platform_release(wide);
    return failure;
}

void ocw_registry_close(uintptr_t key) {
    HMODULE library = ocw_load_system_library(L"advapi32.dll");
    ocw_reg_close_key_fn function;
    if (library == NULL || key == 0u) { if (library) FreeLibrary(library); return; }
    function = (ocw_reg_close_key_fn)(void *)GetProcAddress(library, "RegCloseKey");
    if (function != NULL) function((HKEY)key);
    FreeLibrary(library);
}

oc_status ocw_shell_local_app_data(
    uint8_t **utf8_data, uintptr_t *utf8_length
) {
    HMODULE library = ocw_load_system_library(L"shell32.dll");
    ocw_sh_get_folder_path_w_fn function;
    wchar_t path[MAX_PATH];
    HRESULT result;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    function = (ocw_sh_get_folder_path_w_fn)(void *)ocw_required_symbol(library, "SHGetFolderPathW", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    result = function(NULL, 0x001cu, NULL, 0u, path);
    FreeLibrary(library);
    if (result < 0) return ocw_status_code((uint32_t)result, "SHGetFolderPathW failed");
    return ocw_utf16_decode((const uint8_t *)(const void *)path, (uintptr_t)lstrlenW(path), utf8_data, utf8_length);
}

oc_status ocw_shell_open(const uint8_t *target) {
    HMODULE library = ocw_load_system_library(L"shell32.dll");
    ocw_shell_execute_w_fn function;
    HINSTANCE result;
    oc_status failure = {OC_STATUS_OK, OC_TEXT_EMPTY};
    function = (ocw_shell_execute_w_fn)(void *)ocw_required_symbol(library, "ShellExecuteW", &failure);
    if (function == NULL) { if (library) FreeLibrary(library); return failure; }
    result = function(NULL, L"open", (LPCWSTR)(const void *)target, NULL, NULL, SW_SHOWNORMAL);
    FreeLibrary(library);
    if ((INT_PTR)result <= 32) return ocw_status_code((uint32_t)(INT_PTR)result, "ShellExecuteW failed");
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}
