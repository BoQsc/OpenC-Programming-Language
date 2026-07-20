#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"

#include <errno.h>
#include <float.h>
#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

static int oc_argc = 0;
static char **oc_argv = NULL;
static oc_owned_bytes oc_cwd = {NULL, 0};

static oc_text oc_text_from_c_string(const char *value) {
    if (value == NULL) return OC_TEXT_EMPTY;
    return (oc_text){(const uint8_t *)value, (uintptr_t)strlen(value)};
}

static char *oc_c_string(oc_text value) {
    char *result = (char *)oc_memory_allocate(value.length + 1u, 1u);
    if (value.length != 0u) memcpy(result, value.data, (size_t)value.length);
    result[value.length] = '\0';
    return result;
}

_Noreturn void oc_checked_failure(int32_t code, const char *rule_id, const char *message, uint32_t span_id) {
    char buffer[512];
    int written = snprintf(
        buffer, sizeof(buffer),
        "OpenC checked failure %s at source span %" PRIu32 ": %s\n",
        rule_id ? rule_id : "OPENC-RUNTIME-CHECKED-001",
        span_id,
        message ? message : "checked operation failed"
    );
    if (written > 0) oc_platform_write_stderr((const uint8_t *)buffer, (uintptr_t)written);
    oc_platform_exit(code == 0 ? OC_STATUS_CHECKED_FAILURE : code);
}

_Noreturn void oc_target_fault(const char *rule_id, const char *message, uint32_t span_id) {
    char buffer[512];
    int written = snprintf(
        buffer, sizeof(buffer),
        "OpenC target fault %s at source span %" PRIu32 ": %s\n",
        rule_id ? rule_id : "OPENC-TERM-TARGET-FAULT-001",
        span_id,
        message ? message : "unsafe target precondition failed"
    );
    if (written > 0) oc_platform_write_stderr((const uint8_t *)buffer, (uintptr_t)written);
    oc_platform_exit(OC_STATUS_TARGET_FAULT);
}

uintptr_t oc_bounds_index(uintptr_t index, uintptr_t length, uint32_t span_id) {
    if (index >= length) {
        oc_checked_failure(OC_STATUS_OUT_OF_BOUNDS, "OPENC-SLICE-BOUNDS-001", "index is outside the bounded value", span_id);
    }
    return index;
}

uintptr_t oc_range_length(uintptr_t start, uintptr_t end, uintptr_t total, uint32_t span_id) {
    if (start > end || end > total) {
        oc_checked_failure(OC_STATUS_OUT_OF_BOUNDS, "OPENC-SLICE-RANGE-001", "range is outside the bounded value", span_id);
    }
    return end - start;
}

#define OC_SIGNED_IMPL(type, suffix, min_value, max_value, unsigned_type) \
    type oc_checked_add_##suffix(type a, type b, uint32_t span_id) { \
        if ((b > 0 && a > (type)((max_value) - b)) || (b < 0 && a < (type)((min_value) - b))) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed addition overflow", span_id); \
        return (type)(a + b); \
    } \
    type oc_checked_sub_##suffix(type a, type b, uint32_t span_id) { \
        if ((b < 0 && a > (type)((max_value) + b)) || (b > 0 && a < (type)((min_value) + b))) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed subtraction overflow", span_id); \
        return (type)(a - b); \
    } \
    type oc_checked_mul_##suffix(type a, type b, uint32_t span_id) { \
        if (a != 0 && b != 0) { \
            if (a == (type)-1 && b == (type)(min_value)) \
                oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed multiplication overflow", span_id); \
            if (b == (type)-1 && a == (type)(min_value)) \
                oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed multiplication overflow", span_id); \
            if (a > 0) { \
                if ((b > 0 && a > (type)((max_value) / b)) || (b < 0 && b < (type)((min_value) / a))) \
                    oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed multiplication overflow", span_id); \
            } else { \
                if ((b > 0 && a < (type)((min_value) / b)) || (b < 0 && a < (type)((max_value) / b))) \
                    oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed multiplication overflow", span_id); \
            } \
        } \
        return (type)(a * b); \
    } \
    type oc_checked_div_##suffix(type a, type b, uint32_t span_id) { \
        if (b == 0) oc_checked_failure(OC_STATUS_DIVISION_BY_ZERO, "OPENC-ARITH-DIVZERO-001", "division by zero", span_id); \
        if (a == (type)(min_value) && b == (type)-1) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "signed division overflow", span_id); \
        return (type)(a / b); \
    } \
    type oc_checked_rem_##suffix(type a, type b, uint32_t span_id) { \
        if (b == 0) oc_checked_failure(OC_STATUS_DIVISION_BY_ZERO, "OPENC-ARITH-DIVZERO-001", "remainder by zero", span_id); \
        if (a == (type)(min_value) && b == (type)-1) return 0; \
        return (type)(a % b); \
    } \
    type oc_checked_shl_##suffix(type a, type b, uint32_t span_id) { \
        unsigned width = (unsigned)(sizeof(type) * CHAR_BIT); \
        if (b < 0 || (unsigned_type)b >= width) \
            oc_checked_failure(OC_STATUS_INVALID_SHIFT, "OPENC-ARITH-SHIFT-RANGE-001", "shift count outside type width", span_id); \
        if (a < 0 || (unsigned_type)a > ((unsigned_type)(max_value) >> (unsigned)b)) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "left shift overflow", span_id); \
        return (type)((unsigned_type)a << (unsigned)b); \
    } \
    type oc_checked_shr_##suffix(type a, type b, uint32_t span_id) { \
        unsigned width = (unsigned)(sizeof(type) * CHAR_BIT); \
        if (b < 0 || (unsigned_type)b >= width) \
            oc_checked_failure(OC_STATUS_INVALID_SHIFT, "OPENC-ARITH-SHIFT-RANGE-001", "shift count outside type width", span_id); \
        if (a >= 0) return (type)((unsigned_type)a >> (unsigned)b); \
        unsigned_type bits = (unsigned_type)a; \
        unsigned_type shifted = bits >> (unsigned)b; \
        if ((unsigned)b != 0u) shifted |= (~(unsigned_type)0) << (width - (unsigned)b); \
        return (type)shifted; \
    } \
    type oc_checked_cast_##suffix(long double value, uint32_t span_id) { \
        if (!isfinite((double)value) || value < (long double)(min_value) || value > (long double)(max_value) || truncl(value) != value) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-CAST-CHECKED-001", "checked numeric cast is not representable", span_id); \
        return (type)value; \
    }

#define OC_UNSIGNED_IMPL(type, suffix, max_value) \
    type oc_checked_add_##suffix(type a, type b, uint32_t span_id) { \
        if (a > (type)((max_value) - b)) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "unsigned addition overflow", span_id); \
        return (type)(a + b); \
    } \
    type oc_checked_sub_##suffix(type a, type b, uint32_t span_id) { \
        if (a < b) oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "unsigned subtraction underflow", span_id); \
        return (type)(a - b); \
    } \
    type oc_checked_mul_##suffix(type a, type b, uint32_t span_id) { \
        if (b != 0 && a > (type)((max_value) / b)) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "unsigned multiplication overflow", span_id); \
        return (type)(a * b); \
    } \
    type oc_checked_div_##suffix(type a, type b, uint32_t span_id) { \
        if (b == 0) oc_checked_failure(OC_STATUS_DIVISION_BY_ZERO, "OPENC-ARITH-DIVZERO-001", "division by zero", span_id); \
        return (type)(a / b); \
    } \
    type oc_checked_rem_##suffix(type a, type b, uint32_t span_id) { \
        if (b == 0) oc_checked_failure(OC_STATUS_DIVISION_BY_ZERO, "OPENC-ARITH-DIVZERO-001", "remainder by zero", span_id); \
        return (type)(a % b); \
    } \
    type oc_checked_shl_##suffix(type a, type b, uint32_t span_id) { \
        unsigned width = (unsigned)(sizeof(type) * CHAR_BIT); \
        if ((uintmax_t)b >= width) oc_checked_failure(OC_STATUS_INVALID_SHIFT, "OPENC-ARITH-SHIFT-RANGE-001", "shift count outside type width", span_id); \
        if (a > (type)((max_value) >> (unsigned)b)) oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-ARITH-RUNTIME-OVERFLOW-001", "left shift overflow", span_id); \
        return (type)(a << (unsigned)b); \
    } \
    type oc_checked_shr_##suffix(type a, type b, uint32_t span_id) { \
        unsigned width = (unsigned)(sizeof(type) * CHAR_BIT); \
        if ((uintmax_t)b >= width) oc_checked_failure(OC_STATUS_INVALID_SHIFT, "OPENC-ARITH-SHIFT-RANGE-001", "shift count outside type width", span_id); \
        return (type)(a >> (unsigned)b); \
    } \
    type oc_checked_cast_##suffix(long double value, uint32_t span_id) { \
        if (!isfinite((double)value) || value < 0.0L || value > (long double)(max_value) || truncl(value) != value) \
            oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-CAST-CHECKED-001", "checked numeric cast is not representable", span_id); \
        return (type)value; \
    }

OC_SIGNED_IMPL(int8_t, i8, INT8_MIN, INT8_MAX, uint8_t)
OC_SIGNED_IMPL(int16_t, i16, INT16_MIN, INT16_MAX, uint16_t)
OC_SIGNED_IMPL(int32_t, i32, INT32_MIN, INT32_MAX, uint32_t)
OC_SIGNED_IMPL(int64_t, i64, INT64_MIN, INT64_MAX, uint64_t)
OC_SIGNED_IMPL(intptr_t, isize, INTPTR_MIN, INTPTR_MAX, uintptr_t)
OC_UNSIGNED_IMPL(uint8_t, u8, UINT8_MAX)
OC_UNSIGNED_IMPL(uint16_t, u16, UINT16_MAX)
OC_UNSIGNED_IMPL(uint32_t, u32, UINT32_MAX)
OC_UNSIGNED_IMPL(uint64_t, u64, UINT64_MAX)
OC_UNSIGNED_IMPL(uintptr_t, usize, UINTPTR_MAX)

float oc_checked_cast_f32(long double value, uint32_t span_id) {
    if (!isfinite((double)value) || fabsl(value) > FLT_MAX)
        oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-CAST-CHECKED-001", "checked f32 cast is not representable", span_id);
    return (float)value;
}

double oc_checked_cast_f64(long double value, uint32_t span_id) {
    if (!isfinite((double)value) || fabsl(value) > DBL_MAX)
        oc_checked_failure(OC_STATUS_INTEGER_OVERFLOW, "OPENC-CAST-CHECKED-001", "checked f64 cast is not representable", span_id);
    return (double)value;
}

static bool oc_utf8_decode(const uint8_t *data, uintptr_t length, uintptr_t *offset, uint32_t *scalar) {
    if (*offset >= length) return false;
    uint8_t first = data[(*offset)++];
    if (first < 0x80u) { *scalar = first; return true; }
    uint32_t value;
    unsigned remaining;
    uint32_t minimum;
    if ((first & 0xE0u) == 0xC0u) { value = first & 0x1Fu; remaining = 1u; minimum = 0x80u; }
    else if ((first & 0xF0u) == 0xE0u) { value = first & 0x0Fu; remaining = 2u; minimum = 0x800u; }
    else if ((first & 0xF8u) == 0xF0u) { value = first & 0x07u; remaining = 3u; minimum = 0x10000u; }
    else return false;
    if (*offset + remaining > length) return false;
    for (unsigned i = 0; i < remaining; ++i) {
        uint8_t next = data[(*offset)++];
        if ((next & 0xC0u) != 0x80u) return false;
        value = (value << 6u) | (uint32_t)(next & 0x3Fu);
    }
    if (value < minimum || value > 0x10FFFFu || (value >= 0xD800u && value <= 0xDFFFu)) return false;
    *scalar = value;
    return true;
}

bool oc_text_is_valid_utf8(oc_text value) {
    uintptr_t offset = 0;
    uint32_t scalar = 0;
    while (offset < value.length) if (!oc_utf8_decode(value.data, value.length, &offset, &scalar)) return false;
    return true;
}

uintptr_t oc_text_scalar_length(oc_text value, uint32_t span_id) {
    uintptr_t offset = 0, count = 0;
    uint32_t scalar = 0;
    while (offset < value.length) {
        if (!oc_utf8_decode(value.data, value.length, &offset, &scalar))
            oc_checked_failure(OC_STATUS_INVALID_UTF8, "OPENC-TEXT-UTF8-001", "text contains invalid UTF-8", span_id);
        ++count;
    }
    return count;
}

oc_status oc_text_scalar_at(oc_text value, uintptr_t index, uint32_t *out_scalar) {
    if (!out_scalar) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("scalar output is null")};
    uintptr_t offset = 0, count = 0;
    uint32_t scalar = 0;
    while (offset < value.length) {
        if (!oc_utf8_decode(value.data, value.length, &offset, &scalar))
            return (oc_status){OC_STATUS_INVALID_UTF8, OC_TEXT_LITERAL("text contains invalid UTF-8")};
        if (count == index) {
            *out_scalar = scalar;
            return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
        }
        ++count;
    }
    return (oc_status){OC_STATUS_OUT_OF_BOUNDS, OC_TEXT_LITERAL("text scalar index is outside the text")};
}

static uintptr_t oc_text_byte_offset(oc_text value, uintptr_t scalar_index, uint32_t span_id) {
    uintptr_t offset = 0, count = 0;
    uint32_t scalar = 0;
    while (offset < value.length && count < scalar_index) {
        if (!oc_utf8_decode(value.data, value.length, &offset, &scalar))
            oc_checked_failure(OC_STATUS_INVALID_UTF8, "OPENC-TEXT-UTF8-001", "text contains invalid UTF-8", span_id);
        ++count;
    }
    if (count != scalar_index)
        oc_checked_failure(OC_STATUS_OUT_OF_BOUNDS, "OPENC-TEXT-RANGE-001", "text scalar index is outside the text", span_id);
    return offset;
}

oc_text oc_text_slice(oc_text value, uintptr_t start, uintptr_t end, uint32_t span_id) {
    if (start > end) oc_checked_failure(OC_STATUS_OUT_OF_BOUNDS, "OPENC-TEXT-RANGE-001", "text range start exceeds end", span_id);
    uintptr_t start_byte = oc_text_byte_offset(value, start, span_id);
    uintptr_t end_byte = oc_text_byte_offset(value, end, span_id);
    return (oc_text){value.data + start_byte, end_byte - start_byte};
}

oc_status oc_text_from_utf8(oc_text bytes, oc_text *out_value) {
    if (!oc_text_is_valid_utf8(bytes)) return (oc_status){OC_STATUS_INVALID_UTF8, OC_TEXT_LITERAL("invalid UTF-8")};
    *out_value = bytes;
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status oc_text_from_owned_bytes(const oc_owned_bytes *bytes, oc_text *out_value) {
    if (!bytes) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("bytes argument is null")};
    return oc_text_from_utf8((oc_text){bytes->data, bytes->length}, out_value);
}

oc_status oc_text_to_utf8(oc_text value, oc_owned_bytes *out_bytes) {
    uint8_t *copy = (uint8_t *)oc_memory_allocate(value.length == 0 ? 1u : value.length, 1u);
    if (value.length != 0u) memcpy(copy, value.data, (size_t)value.length);
    *out_bytes = (oc_owned_bytes){copy, value.length};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

bool oc_text_equal(oc_text left, oc_text right) {
    return left.length == right.length && (left.length == 0u || memcmp(left.data, right.data, (size_t)left.length) == 0);
}

int32_t oc_text_compare(oc_text left, oc_text right) {
    uintptr_t length = left.length < right.length ? left.length : right.length;
    int comparison = length == 0u ? 0 : memcmp(left.data, right.data, (size_t)length);
    if (comparison < 0) return -1;
    if (comparison > 0) return 1;
    return left.length < right.length ? -1 : left.length > right.length ? 1 : 0;
}

void *oc_memory_allocate(uintptr_t size, uintptr_t alignment) {
    if (size == 0u) size = 1u;
    if (alignment == 0u || (alignment & (alignment - 1u)) != 0u)
        oc_checked_failure(OC_STATUS_INVALID_ARGUMENT, "OPENC-MEM-ALIGNMENT-001", "allocation alignment must be a nonzero power of two", 0);
    void *result = oc_platform_allocate(size, alignment);
    if (result == NULL) oc_checked_failure(OC_STATUS_OUT_OF_MEMORY, "OPENC-MEM-ALLOC-001", "memory allocation failed", 0);
    return result;
}

void oc_memory_release(void *allocation) { if (allocation != NULL) oc_platform_release(allocation); }
void oc_memory_copy(void *destination, const void *source, uintptr_t size) { if (size) memcpy(destination, source, (size_t)size); }
void oc_memory_move(void *destination, const void *source, uintptr_t size) { if (size) memmove(destination, source, (size_t)size); }
void oc_memory_clear(void *destination, uintptr_t size) { if (size) memset(destination, 0, (size_t)size); }

void oc_io_print_text(oc_text value) { oc_platform_write_stdout(value.data, value.length); }
void oc_io_println_text(oc_text value) { oc_platform_write_stdout(value.data, value.length); oc_platform_write_stdout((const uint8_t *)"\n", 1u); }
void oc_io_error_text(oc_text value) { oc_platform_write_stderr(value.data, value.length); }
void oc_io_print_i64(int64_t value) { char buffer[64]; int n = snprintf(buffer, sizeof(buffer), "%" PRId64, value); if (n > 0) oc_platform_write_stdout((const uint8_t *)buffer, (uintptr_t)n); }
void oc_io_print_u64(uint64_t value) { char buffer[64]; int n = snprintf(buffer, sizeof(buffer), "%" PRIu64, value); if (n > 0) oc_platform_write_stdout((const uint8_t *)buffer, (uintptr_t)n); }
void oc_io_print_bool(bool value) { oc_io_print_text(value ? OC_TEXT_LITERAL("true") : OC_TEXT_LITERAL("false")); }

oc_status oc_file_open_read(oc_text path, oc_file *out_file) {
    char *name = oc_c_string(path);
    FILE *handle = fopen(name, "rb");
    oc_memory_release(name);
    if (!handle) return (oc_status){errno == ENOENT ? OC_STATUS_NOT_FOUND : OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))};
    *out_file = (oc_file){handle, true};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status oc_file_open_write(oc_text path, bool truncate, oc_file *out_file) {
    char *name = oc_c_string(path);
    FILE *handle = fopen(name, truncate ? "wb" : "ab");
    oc_memory_release(name);
    if (!handle) return (oc_status){OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))};
    *out_file = (oc_file){handle, true};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status oc_file_read_all(oc_file *file, oc_owned_bytes *out_bytes) {
    if (!file || !file->open || !file->handle) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file is not open")};
    FILE *handle = (FILE *)file->handle;
    if (fseek(handle, 0, SEEK_END) != 0) return (oc_status){OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))};
    long length = ftell(handle);
    if (length < 0 || fseek(handle, 0, SEEK_SET) != 0) return (oc_status){OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))};
    uint8_t *data = (uint8_t *)oc_memory_allocate((uintptr_t)length + 1u, 1u);
    size_t read = fread(data, 1u, (size_t)length, handle);
    if (read != (size_t)length && ferror(handle)) { oc_memory_release(data); return (oc_status){OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))}; }
    *out_bytes = (oc_owned_bytes){data, (uintptr_t)read};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status oc_file_write_all(oc_file *file, oc_text bytes) {
    if (!file || !file->open || !file->handle) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file is not open")};
    size_t written = fwrite(bytes.data, 1u, (size_t)bytes.length, (FILE *)file->handle);
    if (written != (size_t)bytes.length) return (oc_status){OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

oc_status oc_file_flush(oc_file *file) {
    if (!file || !file->open || !file->handle) return (oc_status){OC_STATUS_INVALID_ARGUMENT, OC_TEXT_LITERAL("file is not open")};
    if (fflush((FILE *)file->handle) != 0) return (oc_status){OC_STATUS_IO_ERROR, oc_text_from_c_string(strerror(errno))};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

void oc_file_close(oc_file file) {
    if (file.open && file.handle) (void)fclose((FILE *)file.handle);
}

oc_status oc_path_join(oc_text left, oc_text right, oc_owned_bytes *out_bytes) {
    const uint8_t separator = '/';
    bool needs = left.length != 0u && left.data[left.length - 1u] != '/' && left.data[left.length - 1u] != '\\';
    uintptr_t length = left.length + right.length + (needs ? 1u : 0u);
    uint8_t *data = (uint8_t *)oc_memory_allocate(length == 0u ? 1u : length, 1u);
    uintptr_t offset = 0;
    if (left.length) { memcpy(data, left.data, (size_t)left.length); offset += left.length; }
    if (needs) data[offset++] = separator;
    if (right.length) memcpy(data + offset, right.data, (size_t)right.length);
    *out_bytes = (oc_owned_bytes){data, length};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

bool oc_path_is_absolute(oc_text path) {
    if (path.length == 0u) return false;
    if (path.data[0] == '/' || path.data[0] == '\\') return true;
    return path.length >= 3u && ((path.data[0] >= 'A' && path.data[0] <= 'Z') || (path.data[0] >= 'a' && path.data[0] <= 'z')) && path.data[1] == ':' && (path.data[2] == '/' || path.data[2] == '\\');
}

void oc_process_initialize(int argc, char **argv) {
    oc_argc = argc;
    oc_argv = argv;
    (void)oc_platform_current_directory(&oc_cwd);
}

void oc_process_finalize(void) {
    if (oc_cwd.data) oc_memory_release(oc_cwd.data);
    oc_cwd = (oc_owned_bytes){NULL, 0};
    oc_argc = 0;
    oc_argv = NULL;
}

uintptr_t oc_process_argument_count(void) { return oc_argc > 0 ? (uintptr_t)oc_argc : 0u; }

oc_text oc_process_argument(uintptr_t index, uint32_t span_id) {
    if (index >= oc_process_argument_count()) oc_checked_failure(OC_STATUS_OUT_OF_BOUNDS, "OPENC-PROCESS-ARGS-BOUNDS-001", "process argument index is out of range", span_id);
    return oc_text_from_c_string(oc_argv[index]);
}

oc_text oc_process_current_directory(void) { return (oc_text){oc_cwd.data, oc_cwd.length}; }
