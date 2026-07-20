#define _POSIX_C_SOURCE 200809L
#define OPENC_RUNTIME_BUILD 1
#include "openc_runtime.h"

#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void oc_linux_write(int descriptor, const uint8_t *data, uintptr_t length) {
    while (length != 0u) {
        ssize_t written = write(descriptor, data, (size_t)length);
        if (written < 0) {
            if (errno == EINTR) continue;
            return;
        }
        data += (uintptr_t)written;
        length -= (uintptr_t)written;
    }
}

void oc_platform_write_stdout(const uint8_t *data, uintptr_t length) { oc_linux_write(STDOUT_FILENO, data, length); }
void oc_platform_write_stderr(const uint8_t *data, uintptr_t length) { oc_linux_write(STDERR_FILENO, data, length); }

void *oc_platform_allocate(uintptr_t size, uintptr_t alignment) {
    void *result = NULL;
    if (alignment < sizeof(void *)) alignment = sizeof(void *);
    if (posix_memalign(&result, (size_t)alignment, (size_t)size) != 0) return NULL;
    return result;
}

void oc_platform_release(void *allocation) { free(allocation); }

oc_status oc_platform_current_directory(oc_owned_bytes *out_bytes) {
    long estimate = pathconf(".", _PC_PATH_MAX);
    if (estimate < 256) estimate = 4096;
    char *buffer = (char *)oc_platform_allocate((uintptr_t)estimate, 1u);
    if (!buffer) return (oc_status){OC_STATUS_OUT_OF_MEMORY, OC_TEXT_LITERAL("cannot allocate current-directory buffer")};
    if (!getcwd(buffer, (size_t)estimate)) {
        oc_platform_release(buffer);
        return (oc_status){OC_STATUS_IO_ERROR, OC_TEXT_LITERAL("cannot read current directory")};
    }
    *out_bytes = (oc_owned_bytes){(uint8_t *)buffer, (uintptr_t)strlen(buffer)};
    return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
}

_Noreturn void oc_platform_exit(int32_t code) { _exit((int)code); }
