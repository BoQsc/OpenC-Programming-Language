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
    uintptr_t hash;
    oc_text path;
    oc_text value;
} ocb_text_cache_entry;

typedef struct ocb_path_cache_entry {
    uintptr_t hash;
    oc_text left;
    oc_text right;
    oc_text value;
} ocb_path_cache_entry;

#define OCB_FAST_CACHE_CAPACITY 1024u

typedef struct ocb_path_fast_entry {
    uintptr_t generation;
    const uint8_t *left_data;
    uintptr_t left_length;
    const uint8_t *right_data;
    uintptr_t right_length;
    oc_text value;
} ocb_path_fast_entry;

typedef struct ocb_file_fast_entry {
    uintptr_t generation;
    const uint8_t *path_data;
    uintptr_t path_length;
    oc_text value;
} ocb_file_fast_entry;

static ocb_text_cache_entry *ocb_text_cache;
static uintptr_t ocb_text_cache_length;
static uintptr_t ocb_text_cache_capacity;
static ocb_path_cache_entry *ocb_path_cache;
static uintptr_t ocb_path_cache_length;
static uintptr_t ocb_path_cache_capacity;
static ocb_path_fast_entry ocb_path_fast_cache[OCB_FAST_CACHE_CAPACITY];
static ocb_file_fast_entry ocb_file_fast_cache[OCB_FAST_CACHE_CAPACITY];
static uintptr_t ocb_fast_cache_generation = 1u;
static oc_text ocb_executable_directory_value;
static oc_text ocb_lsp_message;
static CRITICAL_SECTION ocb_cache_lock;
static volatile LONG ocb_parallel_active;
static volatile LONG ocb_parallel_type_growth;
static DWORD ocb_parallel_heap_tls = TLS_OUT_OF_INDEXES;

static void ocb_fast_cache_invalidate(void);

typedef struct ocb_parallel_job {
    void *state;
    uintptr_t worker;
    ocb_compiler_parallel_callback callback;
    int32_t result;
} ocb_parallel_job;

static void ocb_parallel_job_run(ocb_parallel_job *job) {
    HANDLE private_heap = HeapCreate(HEAP_NO_SERIALIZE, 0u, 0u);
    if (private_heap == NULL || ocb_parallel_heap_tls == TLS_OUT_OF_INDEXES ||
        !TlsSetValue(ocb_parallel_heap_tls, private_heap)) {
        if (private_heap != NULL) HeapDestroy(private_heap);
        job->result = 3;
        return;
    }
    job->result = job->callback(job->state, job->worker);
    (void)TlsSetValue(ocb_parallel_heap_tls, NULL);
    HeapDestroy(private_heap);
}

static DWORD WINAPI ocb_parallel_job_main(void *raw_job) {
    ocb_parallel_job *job = (ocb_parallel_job *)raw_job;
    ocb_parallel_job_run(job);
    return 0u;
}

int32_t ocb_compiler_parallel_jobs(
    void *state,
    uintptr_t worker_count,
    void *raw_callback
) {
    HANDLE handles[7];
    ocb_parallel_job jobs[8];
    uintptr_t created = 0u;
    uintptr_t worker;
    int32_t result = 0;
    ocb_compiler_parallel_callback callback =
        (ocb_compiler_parallel_callback)raw_callback;
    if (callback == NULL || state == NULL) return 3;
    if (worker_count > 8u) worker_count = 8u;
    if (worker_count == 0u) return 0;
    InterlockedExchange(&ocb_parallel_type_growth, 0);
    InterlockedExchange(&ocb_parallel_active, 1);
    for (worker = 0u; worker < worker_count; ++worker) {
        jobs[worker].state = state;
        jobs[worker].worker = worker;
        jobs[worker].callback = callback;
        jobs[worker].result = 3;
    }
    for (worker = 1u; worker < worker_count; ++worker) {
        handles[created] = CreateThread(
            NULL, 0u, ocb_parallel_job_main, &jobs[worker], 0u, NULL
        );
        if (handles[created] == NULL) {
            result = 3;
            break;
        }
        ++created;
    }
    ocb_parallel_job_run(&jobs[0]);
    if (created != 0u) {
        (void)WaitForMultipleObjects(
            (DWORD)created, handles, TRUE, INFINITE
        );
        for (worker = 0u; worker < created; ++worker) {
            CloseHandle(handles[worker]);
        }
    }
    InterlockedExchange(&ocb_parallel_active, 0);
    EnterCriticalSection(&ocb_cache_lock);
    ocb_fast_cache_invalidate();
    LeaveCriticalSection(&ocb_cache_lock);
    if (InterlockedCompareExchange(
            &ocb_parallel_type_growth, 0, 0
        ) != 0) {
        return 2;
    }
    for (worker = 0u; worker < worker_count; ++worker) {
        if (jobs[worker].result != 0 && result == 0) {
            result = jobs[worker].result;
        }
    }
    return result;
}

uintptr_t ocb_compiler_semantic_derived_type_impl(
    uint8_t *type_data,
    uintptr_t *type_count,
    uintptr_t kind,
    uintptr_t element,
    uintptr_t array_length,
    bool const_qualified,
    bool preserve_name
) {
    uintptr_t flags = (const_qualified ? 1u : 0u) |
        (preserve_name ? 8u : 0u);
    uintptr_t type_id;
    uintptr_t *records = (uintptr_t *)type_data;
    for (type_id = 0u; type_id < *type_count; ++type_id) {
        uintptr_t *record = records + type_id * 5u;
        if (record[0] == kind && record[1] == element &&
            record[2] == array_length && record[4] == flags &&
            (kind >= 10u || preserve_name)) {
            return type_id;
        }
    }
    if (InterlockedCompareExchange(&ocb_parallel_active, 0, 0) != 0) {
        InterlockedExchange(&ocb_parallel_type_growth, 1);
        return 0u;
    }
    records += *type_count * 5u;
    records[0] = kind;
    records[1] = element;
    records[2] = array_length;
    records[3] = 0u;
    records[4] = flags;
    type_id = *type_count;
    *type_count = type_id + 1u;
    return type_id;
}

static bool ocb_compiler_ir_node_contains_impl(
    const uintptr_t *records,
    uintptr_t parent,
    uintptr_t child
) {
    const uintptr_t *parent_record = records + parent * 5u;
    const uintptr_t *child_record = records + child * 5u;
    return child_record[1] >= parent_record[1] &&
        child_record[1] + child_record[2] <=
            parent_record[1] + parent_record[2];
}

static bool ocb_compiler_ir_expression_kind_impl(uintptr_t kind) {
    return kind >= 27u && kind <= 52u && kind != 28u;
}

uintptr_t ocb_compiler_ir_root_in_bounds_impl(
    uint8_t *syntax_data,
    uintptr_t syntax_length,
    uint8_t *expression_nodes,
    uintptr_t expression_count,
    uint8_t *expression_start_heads,
    uint8_t *expression_start_next,
    uintptr_t expression_start_capacity,
    uint8_t *expression_next_start,
    uintptr_t *profile_expression_positions,
    uintptr_t start,
    uintptr_t end
) {
    const uintptr_t *records = (const uintptr_t *)syntax_data;
    if (expression_start_heads != NULL && expression_start_next != NULL &&
        expression_start_capacity != 0u) {
        const uintptr_t *heads = (const uintptr_t *)expression_start_heads;
        const uintptr_t *next = (const uintptr_t *)expression_start_next;
        const uintptr_t *next_start =
            (const uintptr_t *)expression_next_start;
        uintptr_t selected = syntax_length;
        uintptr_t selected_length = 0u;
        uintptr_t cursor = start;
        if (next_start == NULL) {
            *profile_expression_positions += end - start;
        }
        while (cursor < end && cursor < expression_start_capacity) {
            uintptr_t encoded;
            if (next_start != NULL) {
                uintptr_t next_encoded = next_start[cursor];
                if (next_encoded == 0u) break;
                cursor = next_encoded - 1u;
                if (cursor >= end) break;
                *profile_expression_positions += 1u;
            }
            encoded = heads[cursor];
            while (encoded != 0u) {
                uintptr_t record = encoded - 1u;
                uintptr_t node_end = cursor + records[record * 5u + 2u];
                if (node_end <= end) {
                    uintptr_t length = node_end - cursor;
                    if (selected == syntax_length || length > selected_length ||
                        (length == selected_length && record < selected)) {
                        selected = record;
                        selected_length = length;
                    }
                }
                encoded = next[record];
            }
            cursor += 1u;
        }
        return selected;
    }
    {
        const uintptr_t *nodes = (const uintptr_t *)expression_nodes;
        uintptr_t selected = syntax_length;
        uintptr_t selected_length = 0u;
        uintptr_t candidate_count = expression_nodes != NULL
            ? expression_count : syntax_length;
        uintptr_t index;
        for (index = 0u; index < candidate_count; ++index) {
            uintptr_t record = expression_nodes != NULL ? nodes[index] : index;
            uintptr_t node_start = records[record * 5u + 1u];
            uintptr_t node_end = node_start + records[record * 5u + 2u];
            if (ocb_compiler_ir_expression_kind_impl(
                    records[record * 5u]
                ) && node_start >= start && node_end <= end) {
                uintptr_t length = node_end - node_start;
                if (selected == syntax_length || length > selected_length) {
                    selected = record;
                    selected_length = length;
                }
            }
        }
        return selected;
    }
}

uintptr_t ocb_compiler_ir_first_name_impl(
    uint8_t *syntax_data,
    uintptr_t syntax_length,
    uint8_t *expression_start_heads,
    uint8_t *expression_start_next,
    uintptr_t expression_start_capacity,
    uint8_t *expression_next_start,
    uintptr_t *profile_expression_positions,
    uint8_t *name_nodes,
    uintptr_t name_count,
    uintptr_t event
) {
    const uintptr_t *records = (const uintptr_t *)syntax_data;
    if (expression_start_heads != NULL && expression_start_next != NULL &&
        expression_start_capacity != 0u) {
        const uintptr_t *heads = (const uintptr_t *)expression_start_heads;
        const uintptr_t *next = (const uintptr_t *)expression_start_next;
        const uintptr_t *next_start =
            (const uintptr_t *)expression_next_start;
        uintptr_t event_start = records[event * 5u + 1u];
        uintptr_t event_end = event_start + records[event * 5u + 2u];
        uintptr_t cursor = event_start;
        if (next_start == NULL) {
            *profile_expression_positions += event_end - event_start;
        }
        while (cursor < event_end && cursor < expression_start_capacity) {
            uintptr_t encoded;
            uintptr_t selected = syntax_length;
            if (next_start != NULL) {
                uintptr_t next_encoded = next_start[cursor];
                if (next_encoded == 0u) break;
                cursor = next_encoded - 1u;
                if (cursor >= event_end) break;
                *profile_expression_positions += 1u;
            }
            encoded = heads[cursor];
            while (encoded != 0u) {
                uintptr_t record = encoded - 1u;
                if (records[record * 5u] == 27u &&
                    ocb_compiler_ir_node_contains_impl(records, event, record) &&
                    (selected == syntax_length || record < selected)) {
                    selected = record;
                }
                encoded = next[record];
            }
            if (selected < syntax_length) return selected;
            cursor += 1u;
        }
        return syntax_length;
    }
    {
        const uintptr_t *nodes = (const uintptr_t *)name_nodes;
        uintptr_t selected = syntax_length;
        uintptr_t selected_start = UINTPTR_MAX;
        uintptr_t candidate_count = name_nodes != NULL ? name_count : syntax_length;
        uintptr_t index;
        for (index = 0u; index < candidate_count; ++index) {
            uintptr_t record = name_nodes != NULL ? nodes[index] : index;
            if (records[record * 5u] == 27u &&
                ocb_compiler_ir_node_contains_impl(records, event, record)) {
                uintptr_t start = records[record * 5u + 1u];
                if (start < selected_start) {
                    selected = record;
                    selected_start = start;
                }
            }
        }
        return selected;
    }
}

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

static uintptr_t ocb_hash_bytes(
    uintptr_t hash,
    const uint8_t *data,
    uintptr_t length
) {
    uintptr_t index;
#if UINTPTR_MAX > UINT32_MAX
    const uintptr_t prime = (uintptr_t)1099511628211ull;
#else
    const uintptr_t prime = (uintptr_t)16777619u;
#endif
    for (index = 0u; index < length; ++index) {
        hash ^= (uintptr_t)data[index];
        hash *= prime;
    }
    return hash;
}

static uintptr_t ocb_hash_text(oc_text value) {
#if UINTPTR_MAX > UINT32_MAX
    uintptr_t hash = (uintptr_t)14695981039346656037ull;
#else
    uintptr_t hash = (uintptr_t)2166136261u;
#endif
    hash = ocb_hash_bytes(hash, value.data, value.length);
    return hash == 0u ? 1u : hash;
}

static uintptr_t ocb_hash_text_pair(oc_text left, oc_text right) {
    uintptr_t hash = ocb_hash_text(left);
    const uint8_t separator = 0xffu;
    hash = ocb_hash_bytes(hash, &separator, 1u);
    hash = ocb_hash_bytes(hash, right.data, right.length);
    return hash == 0u ? 1u : hash;
}

static uintptr_t ocb_hash_pointer(uintptr_t value) {
#if UINTPTR_MAX > UINT32_MAX
    value ^= value >> 33u;
    value *= (uintptr_t)0xff51afd7ed558ccdull;
    value ^= value >> 33u;
#else
    value ^= value >> 16u;
    value *= (uintptr_t)0x7feb352du;
    value ^= value >> 15u;
#endif
    return value;
}

static uintptr_t ocb_path_fast_slot(oc_text left, oc_text right) {
    uintptr_t key = ocb_hash_pointer((uintptr_t)left.data);
    key ^= ocb_hash_pointer((uintptr_t)right.data);
    key ^= ocb_hash_pointer(left.length);
    key ^= ocb_hash_pointer(right.length);
    return key & (OCB_FAST_CACHE_CAPACITY - 1u);
}

static uintptr_t ocb_file_fast_slot(oc_text path) {
    uintptr_t key = ocb_hash_pointer((uintptr_t)path.data);
    key ^= ocb_hash_pointer(path.length);
    return key & (OCB_FAST_CACHE_CAPACITY - 1u);
}

static void ocb_fast_cache_invalidate(void) {
    ++ocb_fast_cache_generation;
    if (ocb_fast_cache_generation == 0u) {
        memset(ocb_path_fast_cache, 0, sizeof(ocb_path_fast_cache));
        memset(ocb_file_fast_cache, 0, sizeof(ocb_file_fast_cache));
        ocb_fast_cache_generation = 1u;
    }
}

static uintptr_t ocb_text_cache_slot(
    ocb_text_cache_entry *entries,
    uintptr_t capacity,
    uintptr_t hash,
    oc_text path
) {
    uintptr_t slot = hash & (capacity - 1u);
    while (entries[slot].path.data != NULL &&
        (entries[slot].hash != hash ||
            !oc_text_equal(entries[slot].path, path))) {
        slot = (slot + 1u) & (capacity - 1u);
    }
    return slot;
}

static void ocb_text_cache_reserve(uintptr_t capacity) {
    uintptr_t index;
    ocb_text_cache_entry *next = (ocb_text_cache_entry *)oc_memory_allocate(
        capacity * (uintptr_t)sizeof(ocb_text_cache_entry),
        (uintptr_t)_Alignof(ocb_text_cache_entry)
    );
    oc_memory_clear(
        next, capacity * (uintptr_t)sizeof(ocb_text_cache_entry)
    );
    for (index = 0u; index < ocb_text_cache_capacity; ++index) {
        if (ocb_text_cache[index].path.data != NULL) {
            uintptr_t slot = ocb_text_cache_slot(
                next,
                capacity,
                ocb_text_cache[index].hash,
                ocb_text_cache[index].path
            );
            next[slot] = ocb_text_cache[index];
        }
    }
    oc_memory_release(ocb_text_cache);
    ocb_text_cache = next;
    ocb_text_cache_capacity = capacity;
}

static uintptr_t ocb_path_cache_slot(
    ocb_path_cache_entry *entries,
    uintptr_t capacity,
    uintptr_t hash,
    oc_text left,
    oc_text right
) {
    uintptr_t slot = hash & (capacity - 1u);
    while (entries[slot].value.data != NULL &&
        (entries[slot].hash != hash ||
            !oc_text_equal(entries[slot].left, left) ||
            !oc_text_equal(entries[slot].right, right))) {
        slot = (slot + 1u) & (capacity - 1u);
    }
    return slot;
}

static void ocb_path_cache_reserve(uintptr_t capacity) {
    uintptr_t index;
    ocb_path_cache_entry *next = (ocb_path_cache_entry *)oc_memory_allocate(
        capacity * (uintptr_t)sizeof(ocb_path_cache_entry),
        (uintptr_t)_Alignof(ocb_path_cache_entry)
    );
    oc_memory_clear(
        next, capacity * (uintptr_t)sizeof(ocb_path_cache_entry)
    );
    for (index = 0u; index < ocb_path_cache_capacity; ++index) {
        if (ocb_path_cache[index].value.data != NULL) {
            uintptr_t slot = ocb_path_cache_slot(
                next,
                capacity,
                ocb_path_cache[index].hash,
                ocb_path_cache[index].left,
                ocb_path_cache[index].right
            );
            next[slot] = ocb_path_cache[index];
        }
    }
    oc_memory_release(ocb_path_cache);
    ocb_path_cache = next;
    ocb_path_cache_capacity = capacity;
}

static void ocb_release_caches(void) {
    uintptr_t index;
    for (index = 0u; index < ocb_text_cache_capacity; ++index) {
        if (ocb_text_cache[index].path.data != NULL) {
            oc_memory_release((void *)ocb_text_cache[index].path.data);
            oc_memory_release((void *)ocb_text_cache[index].value.data);
        }
    }
    oc_memory_release(ocb_text_cache);
    ocb_text_cache = NULL;
    ocb_text_cache_length = 0u;
    ocb_text_cache_capacity = 0u;

    for (index = 0u; index < ocb_path_cache_capacity; ++index) {
        if (ocb_path_cache[index].value.data != NULL) {
            oc_memory_release((void *)ocb_path_cache[index].left.data);
            oc_memory_release((void *)ocb_path_cache[index].right.data);
            oc_memory_release((void *)ocb_path_cache[index].value.data);
        }
    }
    oc_memory_release(ocb_path_cache);
    ocb_path_cache = NULL;
    ocb_path_cache_length = 0u;
    ocb_path_cache_capacity = 0u;
}

static oc_status ocb_failure(int32_t code, const char *message) {
    return (oc_status){code, {(const uint8_t *)message, strlen(message)}};
}

void ocb_process_initialize(int argc, char **argv) {
    InitializeCriticalSection(&ocb_cache_lock);
    ocb_parallel_heap_tls = TlsAlloc();
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
    ocb_release_caches();
    if (ocb_lsp_message.data != NULL) {
        oc_memory_release((void *)ocb_lsp_message.data);
        ocb_lsp_message = OC_TEXT_EMPTY;
    }
    if (ocb_executable_directory_value.data != NULL) {
        oc_memory_release((void *)ocb_executable_directory_value.data);
        ocb_executable_directory_value = OC_TEXT_EMPTY;
    }
    oc_process_finalize();
    if (ocb_parallel_heap_tls != TLS_OUT_OF_INDEXES) {
        TlsFree(ocb_parallel_heap_tls);
        ocb_parallel_heap_tls = TLS_OUT_OF_INDEXES;
    }
    DeleteCriticalSection(&ocb_cache_lock);
}

void *ocb_memory_alloc(uintptr_t size) {
    if (ocb_parallel_heap_tls != TLS_OUT_OF_INDEXES) {
        HANDLE private_heap = (HANDLE)TlsGetValue(ocb_parallel_heap_tls);
        if (private_heap != NULL) {
            void *allocation = HeapAlloc(
                private_heap, HEAP_NO_SERIALIZE,
                (SIZE_T)(size == 0u ? 1u : size)
            );
            if (allocation == NULL) {
                oc_checked_failure(
                    OC_STATUS_OUT_OF_MEMORY,
                    "OPENC-COMPILER-PARALLEL-ALLOC-001",
                    "compiler worker scratch allocation failed",
                    0
                );
            }
            return allocation;
        }
    }
    return oc_memory_allocate(size, 1u);
}

void ocb_memory_free(void *allocation) {
    if (ocb_parallel_heap_tls != TLS_OUT_OF_INDEXES) {
        HANDLE private_heap = (HANDLE)TlsGetValue(ocb_parallel_heap_tls);
        if (private_heap != NULL) {
            if (allocation != NULL) {
                (void)HeapFree(private_heap, HEAP_NO_SERIALIZE, allocation);
            }
            return;
        }
    }
    if (InterlockedCompareExchange(&ocb_parallel_active, 0, 0) == 0) {
        EnterCriticalSection(&ocb_cache_lock);
        ocb_fast_cache_invalidate();
        LeaveCriticalSection(&ocb_cache_lock);
    }
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
    if (oc_text_equal(
        path, OC_TEXT_LITERAL("@openc-internal:lsp-stdio-frame")
    )) {
        if (ocb_lsp_message.data != NULL) {
            oc_memory_release((void *)ocb_lsp_message.data);
            ocb_lsp_message = OC_TEXT_EMPTY;
        }
        ocb_lsp_message = oc_io_read_message();
        if (ocb_lsp_message.length == 0u) {
            return ocb_failure(
                OC_STATUS_NOT_FOUND, "standard input is closed"
            );
        }
        *value = ocb_lsp_message;
        return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
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
    uintptr_t fast_slot;
    uintptr_t hash;
    uintptr_t slot;
    oc_status result;
    if (value == NULL) {
        return ocb_failure(OC_STATUS_INVALID_ARGUMENT, "text output is null");
    }
    if (InterlockedCompareExchange(&ocb_parallel_active, 0, 0) != 0) {
        hash = ocb_hash_text(path);
        if (ocb_text_cache_capacity != 0u) {
            slot = ocb_text_cache_slot(
                ocb_text_cache, ocb_text_cache_capacity, hash, path
            );
            if (ocb_text_cache[slot].path.data != NULL) {
                *value = ocb_text_cache[slot].value;
                return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
            }
        }
        return ocb_failure(
            OC_STATUS_NOT_FOUND,
            "compiler parallel source cache miss"
        );
    }
    EnterCriticalSection(&ocb_cache_lock);
    fast_slot = ocb_file_fast_slot(path);
    if (ocb_file_fast_cache[fast_slot].generation ==
            ocb_fast_cache_generation &&
        ocb_file_fast_cache[fast_slot].path_data == path.data &&
        ocb_file_fast_cache[fast_slot].path_length == path.length) {
        *value = ocb_file_fast_cache[fast_slot].value;
        LeaveCriticalSection(&ocb_cache_lock);
        return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
    }
    hash = ocb_hash_text(path);
    if (ocb_text_cache_capacity != 0u) {
        slot = ocb_text_cache_slot(
            ocb_text_cache, ocb_text_cache_capacity, hash, path
        );
        if (ocb_text_cache[slot].path.data != NULL) {
            *value = ocb_text_cache[slot].value;
            ocb_file_fast_cache[fast_slot].generation =
                ocb_fast_cache_generation;
            ocb_file_fast_cache[fast_slot].path_data = path.data;
            ocb_file_fast_cache[fast_slot].path_length = path.length;
            ocb_file_fast_cache[fast_slot].value = *value;
            LeaveCriticalSection(&ocb_cache_lock);
            return (oc_status){OC_STATUS_OK, OC_TEXT_EMPTY};
        }
    }
    result = ocb_file_read_text(path, value);
    if (!oc_status_ok(result)) {
        LeaveCriticalSection(&ocb_cache_lock);
        return result;
    }
    if (ocb_text_cache_capacity == 0u ||
        (ocb_text_cache_length + 1u) * 2u > ocb_text_cache_capacity) {
        ocb_text_cache_reserve(
            ocb_text_cache_capacity == 0u
                ? 16u
                : ocb_text_cache_capacity * 2u
        );
    }
    slot = ocb_text_cache_slot(
        ocb_text_cache, ocb_text_cache_capacity, hash, path
    );
    ocb_text_cache[slot].hash = hash;
    ocb_text_cache[slot].path = ocb_copy_text(path);
    ocb_text_cache[slot].value = *value;
    ++ocb_text_cache_length;
    ocb_file_fast_cache[fast_slot].generation = ocb_fast_cache_generation;
    ocb_file_fast_cache[fast_slot].path_data = path.data;
    ocb_file_fast_cache[fast_slot].path_length = path.length;
    ocb_file_fast_cache[fast_slot].value = *value;
    LeaveCriticalSection(&ocb_cache_lock);
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
    uintptr_t fast_slot = ocb_path_fast_slot(left, right);
    uintptr_t hash;
    uintptr_t slot;
    oc_owned_bytes bytes;
    oc_status result;
    if (InterlockedCompareExchange(&ocb_parallel_active, 0, 0) != 0) {
        hash = ocb_hash_text_pair(left, right);
        if (ocb_path_cache_capacity != 0u) {
            slot = ocb_path_cache_slot(
                ocb_path_cache, ocb_path_cache_capacity, hash, left, right
            );
            if (ocb_path_cache[slot].value.data != NULL) {
                return ocb_path_cache[slot].value;
            }
        }
        oc_checked_failure(
            OC_STATUS_NOT_FOUND,
            "OPENC-COMPILER-PARALLEL-CACHE-001",
            "compiler parallel path cache miss",
            0
        );
    }
    EnterCriticalSection(&ocb_cache_lock);
    if (ocb_path_fast_cache[fast_slot].generation ==
            ocb_fast_cache_generation &&
        ocb_path_fast_cache[fast_slot].left_data == left.data &&
        ocb_path_fast_cache[fast_slot].left_length == left.length &&
        ocb_path_fast_cache[fast_slot].right_data == right.data &&
        ocb_path_fast_cache[fast_slot].right_length == right.length) {
        oc_text value = ocb_path_fast_cache[fast_slot].value;
        LeaveCriticalSection(&ocb_cache_lock);
        return value;
    }
    hash = ocb_hash_text_pair(left, right);
    if (ocb_path_cache_capacity != 0u) {
        slot = ocb_path_cache_slot(
            ocb_path_cache, ocb_path_cache_capacity, hash, left, right
        );
        if (ocb_path_cache[slot].value.data != NULL) {
            ocb_path_fast_cache[fast_slot].generation =
                ocb_fast_cache_generation;
            ocb_path_fast_cache[fast_slot].left_data = left.data;
            ocb_path_fast_cache[fast_slot].left_length = left.length;
            ocb_path_fast_cache[fast_slot].right_data = right.data;
            ocb_path_fast_cache[fast_slot].right_length = right.length;
            ocb_path_fast_cache[fast_slot].value =
                ocb_path_cache[slot].value;
            {
                oc_text value = ocb_path_cache[slot].value;
                LeaveCriticalSection(&ocb_cache_lock);
                return value;
            }
        }
    }
    result = oc_path_join(left, right, &bytes);
    if (!oc_status_ok(result)) {
        oc_checked_failure(result.code, "OPENC-PATH-JOIN-001", "path join failed", 0);
    }
    if (ocb_path_cache_capacity == 0u ||
        (ocb_path_cache_length + 1u) * 2u > ocb_path_cache_capacity) {
        ocb_path_cache_reserve(
            ocb_path_cache_capacity == 0u
                ? 16u
                : ocb_path_cache_capacity * 2u
        );
    }
    slot = ocb_path_cache_slot(
        ocb_path_cache, ocb_path_cache_capacity, hash, left, right
    );
    ocb_path_cache[slot].hash = hash;
    ocb_path_cache[slot].left = ocb_copy_text(left);
    ocb_path_cache[slot].right = ocb_copy_text(right);
    ocb_path_cache[slot].value = (oc_text){bytes.data, bytes.length};
    ++ocb_path_cache_length;
    ocb_path_fast_cache[fast_slot].generation = ocb_fast_cache_generation;
    ocb_path_fast_cache[fast_slot].left_data = left.data;
    ocb_path_fast_cache[fast_slot].left_length = left.length;
    ocb_path_fast_cache[fast_slot].right_data = right.data;
    ocb_path_fast_cache[fast_slot].right_length = right.length;
    ocb_path_fast_cache[fast_slot].value = ocb_path_cache[slot].value;
    {
        oc_text value = ocb_path_cache[slot].value;
        LeaveCriticalSection(&ocb_cache_lock);
        return value;
    }
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

uintptr_t ocb_process_monotonic_milliseconds(void) {
    return (uintptr_t)GetTickCount();
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
