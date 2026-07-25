#ifndef OPENC_SH5_RUNTIME_H
#define OPENC_SH5_RUNTIME_H

#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"

#ifdef __cplusplus
extern "C" {
#endif

void ocb_process_initialize(int argc, char **argv);
void ocb_process_finalize(void);

void *ocb_memory_alloc(uintptr_t size);
void ocb_memory_free(void *allocation);
uintptr_t ocb_memory_load_usize(const void *address);
void ocb_memory_store_usize(void *address, uintptr_t value);

void ocb_io_print_text(oc_text value);
void ocb_io_print_i64(int64_t value);
void ocb_io_print_u64(uint64_t value);
void ocb_io_print_bool(bool value);
void ocb_io_println_text(oc_text value);
void ocb_io_println_i64(int64_t value);
void ocb_io_println_u64(uint64_t value);
void ocb_io_println_bool(bool value);
void ocb_io_error(oc_text value);

uintptr_t ocb_text_byte_length(oc_text value);
uint8_t ocb_text_byte_at_unchecked(oc_text value, uintptr_t index);
oc_text ocb_text_from_utf8(void *data, uintptr_t length);
oc_status ocb_text_slice(
    oc_text value,
    uintptr_t lower,
    uintptr_t upper,
    oc_text *result
);
bool ocb_text_equal(oc_text left, oc_text right);
int32_t ocb_text_compare(oc_text left, oc_text right);

oc_status ocb_file_read_text(oc_text path, oc_text *value);
oc_status ocb_file_read_text_cached(oc_text path, oc_text *value);
oc_status ocb_file_write_text(oc_text path, oc_text value);

oc_text ocb_path_join(oc_text left, oc_text right);
oc_text ocb_path_directory(oc_text value);

uintptr_t ocb_process_argument_count(void);
oc_text ocb_process_argument(uintptr_t index);
oc_status ocb_process_run(
    oc_text command,
    int32_t *exit_code,
    oc_text *output
);

_Noreturn void ocb_checked_failure(oc_text message);
_Noreturn void ocb_target_fault(oc_text message);

#ifdef __cplusplus
}
#endif

#endif
