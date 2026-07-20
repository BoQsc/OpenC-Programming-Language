#define WIN32_LEAN_AND_MEAN
#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"
#include <windows.h>
#include <stdint.h>
#include <string.h>

typedef struct oc_windows_allocation_header {
    void *base;
    uintptr_t requested_size;
    uintptr_t requested_alignment;
} oc_windows_allocation_header;

static bool oc_is_power_of_two(uintptr_t value) {
    return value != 0u && (value & (value - 1u)) == 0u;
}

static uintptr_t oc_normalize_alignment(uintptr_t alignment) {
    uintptr_t minimum = (uintptr_t)_Alignof(max_align_t);
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
