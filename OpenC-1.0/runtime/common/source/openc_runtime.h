#ifndef OPENC_RUNTIME_H
#define OPENC_RUNTIME_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>

#if defined(__TINYC__)
#  define _Noreturn __attribute__((noreturn))
#  define _Alignof __alignof__
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#  if defined(OPENC_RUNTIME_BUILD)
#    define OC_API __declspec(dllexport)
#  else
#    define OC_API __declspec(dllimport)
#  endif
#else
#  define OC_API
#endif

typedef struct oc_text {
    const uint8_t *data;
    uintptr_t length;
} oc_text;

typedef struct oc_status {
    int32_t code;
    oc_text message;
} oc_status;

typedef struct oc_none { uint8_t value; } oc_none;

typedef struct oc_owned_bytes {
    uint8_t *data;
    uintptr_t length;
} oc_owned_bytes;

typedef struct oc_file {
    void *handle;
    bool open;
} oc_file;

#define OC_NONE ((oc_none){0})
#define OC_TEXT_EMPTY ((oc_text){NULL, 0})
#define OC_TEXT_LITERAL(value) ((oc_text){(const uint8_t *)(value), (uintptr_t)(sizeof(value) - 1u)})
#define OC_CONSTRUCT(type, storage, value) \
    ((*(type *)(void *)((storage).bytes) = (value)), (type *)(void *)((storage).bytes))
#define oc_destroy_typed(value) ((void)(value))

static inline bool oc_status_ok(oc_status value) { return value.code == 0; }

/* Stable Core/Hosted status codes. Applications may define positive domain codes. */
enum {
    OC_STATUS_OK = 0,
    OC_STATUS_CHECKED_FAILURE = -1,
    OC_STATUS_OUT_OF_MEMORY = -2,
    OC_STATUS_INVALID_UTF8 = -3,
    OC_STATUS_OUT_OF_BOUNDS = -4,
    OC_STATUS_INTEGER_OVERFLOW = -5,
    OC_STATUS_DIVISION_BY_ZERO = -6,
    OC_STATUS_INVALID_SHIFT = -7,
    OC_STATUS_IO_ERROR = -8,
    OC_STATUS_NOT_FOUND = -9,
    OC_STATUS_INVALID_ARGUMENT = -10,
    OC_STATUS_UNSUPPORTED = -11,
    OC_STATUS_TARGET_FAULT = -12,
};

OC_API _Noreturn void oc_checked_failure(
    int32_t code,
    const char *rule_id,
    const char *message,
    uint32_t span_id
);
OC_API _Noreturn void oc_target_fault(
    const char *rule_id,
    const char *message,
    uint32_t span_id
);

OC_API uintptr_t oc_bounds_index(uintptr_t index, uintptr_t length, uint32_t span_id);
OC_API uintptr_t oc_range_length(uintptr_t start, uintptr_t end, uintptr_t total, uint32_t span_id);

#define OC_DECLARE_CHECKED_SIGNED(type, suffix) \
    OC_API type oc_checked_add_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_sub_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_mul_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_div_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_rem_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_shl_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_shr_##suffix(type a, type b, uint32_t span_id); \
    OC_API type oc_checked_cast_##suffix(long double value, uint32_t span_id)

#define OC_DECLARE_CHECKED_UNSIGNED(type, suffix) OC_DECLARE_CHECKED_SIGNED(type, suffix)

OC_DECLARE_CHECKED_SIGNED(int8_t, i8);
OC_DECLARE_CHECKED_SIGNED(int16_t, i16);
OC_DECLARE_CHECKED_SIGNED(int32_t, i32);
OC_DECLARE_CHECKED_SIGNED(int64_t, i64);
OC_DECLARE_CHECKED_SIGNED(intptr_t, isize);
OC_DECLARE_CHECKED_UNSIGNED(uint8_t, u8);
OC_DECLARE_CHECKED_UNSIGNED(uint16_t, u16);
OC_DECLARE_CHECKED_UNSIGNED(uint32_t, u32);
OC_DECLARE_CHECKED_UNSIGNED(uint64_t, u64);
OC_DECLARE_CHECKED_UNSIGNED(uintptr_t, usize);

OC_API float oc_checked_cast_f32(long double value, uint32_t span_id);
OC_API double oc_checked_cast_f64(long double value, uint32_t span_id);

OC_API bool oc_text_is_valid_utf8(oc_text value);
OC_API uintptr_t oc_text_length(oc_text value);
OC_API uintptr_t oc_text_scalar_length(oc_text value, uint32_t span_id);
OC_API oc_status oc_text_scalar_at(oc_text value, uintptr_t index, uint32_t *out_scalar);
OC_API uintptr_t oc_text_byte_length(oc_text value);
OC_API oc_status oc_text_byte_at(oc_text value, uintptr_t index, uint8_t *out_byte);
OC_API void oc_text_copy_utf8_unchecked(void *destination, oc_text value);
OC_API void oc_text_copy_utf8_slice_unchecked(
    void *destination,
    oc_text value,
    uintptr_t start,
    uintptr_t length
);
OC_API oc_text oc_text_slice(oc_text value, uintptr_t start, uintptr_t end, uint32_t span_id);
OC_API oc_status oc_text_from_utf8(oc_text bytes, oc_text *out_value);
OC_API oc_status oc_text_from_owned_bytes(const oc_owned_bytes *bytes, oc_text *out_value);
OC_API oc_status oc_text_to_utf8(oc_text value, oc_owned_bytes *out_bytes);
OC_API bool oc_text_equal(oc_text left, oc_text right);
OC_API int32_t oc_text_compare(oc_text left, oc_text right);

OC_API void *oc_memory_allocate(uintptr_t size, uintptr_t alignment);
OC_API void oc_memory_release(void *allocation);
OC_API void oc_memory_copy(void *destination, const void *source, uintptr_t size);
OC_API void oc_memory_move(void *destination, const void *source, uintptr_t size);
OC_API void oc_memory_clear(void *destination, uintptr_t size);

OC_API void oc_io_print_text(oc_text value);
OC_API void oc_io_println_text(oc_text value);
OC_API void oc_io_print_i64(int64_t value);
OC_API void oc_io_print_u64(uint64_t value);
OC_API void oc_io_print_bool(bool value);
OC_API void oc_io_error_text(oc_text value);
OC_API oc_text oc_io_read_message(void);

OC_API oc_status oc_file_open_read(oc_text path, oc_file *out_file);
OC_API oc_status oc_file_open_write(oc_text path, bool truncate, oc_file *out_file);
OC_API oc_status oc_file_read_all(oc_file *file, oc_owned_bytes *out_bytes);
OC_API oc_status oc_file_write_all(oc_file *file, oc_text bytes);
OC_API oc_status oc_file_flush(oc_file *file);
OC_API void oc_file_close(oc_file file);

OC_API oc_status oc_path_join(oc_text left, oc_text right, oc_owned_bytes *out_bytes);
OC_API bool oc_path_is_absolute(oc_text path);

OC_API void oc_process_initialize(int argc, char **argv);
OC_API void oc_process_finalize(void);
OC_API uintptr_t oc_process_argument_count(void);
OC_API oc_text oc_process_argument(uintptr_t index, uint32_t span_id);
OC_API oc_text oc_process_current_directory(void);

/* Platform provider contract. */
OC_API void oc_platform_write_stdout(const uint8_t *data, uintptr_t length);
OC_API void oc_platform_write_stderr(const uint8_t *data, uintptr_t length);
OC_API void *oc_platform_allocate(uintptr_t size, uintptr_t alignment);
OC_API void oc_platform_release(void *allocation);
OC_API oc_status oc_platform_current_directory(oc_owned_bytes *out_bytes);
OC_API _Noreturn void oc_platform_exit(int32_t code);

#ifdef __cplusplus
}
#endif

#endif
