#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"

/*
 * Freestanding providers replace these hooks or link platform-specific strong
 * definitions.  The default authored provider fails closed and never pretends
 * that unavailable hosted facilities succeeded.
 */

#if defined(__GNUC__) || defined(__clang__)
#define OC_WEAK __attribute__((weak))
#else
#define OC_WEAK
#endif

OC_WEAK void oc_freestanding_write_stdout(const uint8_t *data, uintptr_t length) { (void)data; (void)length; }
OC_WEAK void oc_freestanding_write_stderr(const uint8_t *data, uintptr_t length) { (void)data; (void)length; }
OC_WEAK void *oc_freestanding_allocate(uintptr_t size, uintptr_t alignment) { (void)size; (void)alignment; return NULL; }
OC_WEAK void oc_freestanding_release(void *allocation) { (void)allocation; }
OC_WEAK _Noreturn void oc_freestanding_exit(int32_t code) { (void)code; for (;;) { } }

void oc_platform_write_stdout(const uint8_t *data, uintptr_t length) { oc_freestanding_write_stdout(data, length); }
void oc_platform_write_stderr(const uint8_t *data, uintptr_t length) { oc_freestanding_write_stderr(data, length); }
void *oc_platform_allocate(uintptr_t size, uintptr_t alignment) { return oc_freestanding_allocate(size, alignment); }
void oc_platform_release(void *allocation) { oc_freestanding_release(allocation); }
oc_status oc_platform_current_directory(oc_owned_bytes *out_bytes) { (void)out_bytes; return (oc_status){OC_STATUS_UNSUPPORTED, OC_TEXT_LITERAL("current directory is unavailable in the default freestanding provider")}; }
_Noreturn void oc_platform_exit(int32_t code) { oc_freestanding_exit(code); }
