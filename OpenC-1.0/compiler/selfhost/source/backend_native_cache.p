import system.text;

// CryptHashCertificate2 hashes arbitrary input bytes with the documented CNG
// SHA256 provider. Native program images reserve .data+0 for this immutable
// resolver; +8 is TLS and +16 the argument snapshot. The separate SH-16 probe
// image owns its own data layout and never calls this compiler-private hook.
// A winning initializer retains one DLL reference until process exit. Losing
// initializers release theirs; sentinel 1 remembers an unavailable API.
unsafe void native_cache_prepare_sha(ref NativeFunction function) {
    native_data_address(function, 0, 10);
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize cached = native_skip(function.code, 5);
    native_windows_dynamic_prepare(function, "crypt32.dll", "CryptHashCertificate2");
    x64_mov_r64_memory(function.code, 11, 4, 608);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 219);
    usize found = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 1));
    native_skip_end(function.code, found);
    native_data_address(function, 0, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_atomic_compare_exchange_r10_r11(function);
    usize lost = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 608, 11);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_cmp_r64_r64(function.code, 11, 0);
    usize retained = native_skip(function.code, 5);
    native_windows_dynamic_close(function);
    native_skip_end(function.code, retained);
    usize initialized = native_jump(function.code);
    native_skip_end(function.code, lost);
    x64_mov_memory_r64(function.code, 4, 608, 0);
    native_windows_dynamic_close(function);
    usize joined = native_jump(function.code);
    native_skip_end(function.code, cached);
    x64_mov_memory_r64(function.code, 4, 608, 0);
    native_skip_end(function.code, initialized);
    native_skip_end(function.code, joined);
}

unsafe void native_cache_sha256(
    ref IrContext context, ref NativeFunction function,
    usize instruction, usize result
) {
    native_cache_prepare_sha(function);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 1));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize available = native_skip(function.code, 7);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_store(function, result, 0);
    usize done = native_jump(function.code);
    native_skip_end(function.code, available);
    native_constant_ascii(function, "SHA256", true, 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    native_load(function, d_operand_value(context, instruction, 0), 9);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_load(function, d_operand_value(context, instruction, 2), 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 32));
    x64_mov_memory_r64(function.code, 4, 616, 0);
    native_windows_stack_address(function, 0, 616);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_store(function, result, 0);
    native_skip_end(function.code, done);
}

// Hash the complete bounded file through a read-only data mapping. The same
// handle supplies size and mapping, denies writers, and remains open until
// unmap. All APIs are optional; the caller retains bounded read/SHA fallback.
// Scratch 624..680 is private to this hook in the reserved 1536-byte frame.
unsafe void native_cache_file_sha256(
    ref IrContext context, ref NativeFunction function,
    usize instruction, usize result
) {
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_store(function, result, 0);
    native_cache_prepare_sha(function);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 1));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize missing_sha = native_skip(function.code, 6);
    x64_mov_memory_r64(function.code, 4, 624, 0);

    native_windows_dynamic_prepare(function, "kernel32.dll", "CreateFileMappingW");
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_memory_r64(function.code, 4, 632, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize missing_create = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 1, 4, 600);
    native_constant_ascii(function, "MapViewOfFile", false, 2);
    native_import(function, 20);
    x64_mov_memory_r64(function.code, 4, 640, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize missing_map = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 1, 4, 600);
    native_constant_ascii(function, "UnmapViewOfFile", false, 2);
    native_import(function, 20);
    x64_mov_memory_r64(function.code, 4, 648, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize missing_unmap = native_skip(function.code, 4);

    native_utf8_path(function, d_operand_value(context, instruction, 0));
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 2147483648));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 5));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 3)); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 128)); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 48, 0);
    native_import(function, 1);
    x64_mov_memory_r64(function.code, 4, 656, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 0, 4, 656);
    x64_mov_r64_imm64(function.code, 11, ~cast(u64, 0));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize missing_file = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 1, 4, 656);
    native_windows_stack_address(function, 2, 664);
    native_import(function, 18);
    x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize missing_size = native_skip(function.code, 4);
    native_load(function, d_operand_value(context, instruction, 1), 11);
    x64_mov_r64_memory(function.code, 0, 4, 664);
    x64_cmp_r64_r64(function.code, 0, 11);
    usize oversized = native_skip(function.code, 7);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 33554432));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize hard_limit = native_skip(function.code, 7);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize empty = native_skip(function.code, 4);

    x64_mov_r64_memory(function.code, 1, 4, 656);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 2));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_memory(function.code, 0, 4, 664);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_memory(function.code, 0, 4, 632); x64_call_r64(function.code, 0);
    x64_mov_memory_r64(function.code, 4, 672, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize create_failed = native_skip(function.code, 4);
    x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 4));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_memory(function.code, 0, 4, 664); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 640); x64_call_r64(function.code, 0);
    x64_mov_memory_r64(function.code, 4, 680, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize map_failed = native_skip(function.code, 4);

    native_constant_ascii(function, "SHA256", true, 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_memory(function.code, 9, 4, 680);
    x64_mov_r64_memory(function.code, 0, 4, 664); x64_mov_memory_r64(function.code, 4, 32, 0);
    native_load(function, d_operand_value(context, instruction, 2), 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 32)); x64_mov_memory_r64(function.code, 4, 616, 0);
    native_windows_stack_address(function, 0, 616); x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_r64_memory(function.code, 0, 4, 624); x64_call_r64(function.code, 0);
    native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 1, 4, 680);
    x64_mov_r64_memory(function.code, 0, 4, 648); x64_call_r64(function.code, 0);
    native_skip_end(function.code, map_failed);
    x64_mov_r64_memory(function.code, 1, 4, 672); native_import(function, 0);
    native_skip_end(function.code, create_failed);
    native_skip_end(function.code, missing_size);
    native_skip_end(function.code, oversized);
    native_skip_end(function.code, hard_limit);
    native_skip_end(function.code, empty);
    x64_mov_r64_memory(function.code, 1, 4, 656); native_import(function, 0);
    native_skip_end(function.code, missing_file);
    native_skip_end(function.code, missing_create);
    native_skip_end(function.code, missing_map);
    native_skip_end(function.code, missing_unmap);
    native_windows_dynamic_close(function);
    native_skip_end(function.code, missing_sha);
}

// Same-directory atomic replacement, through the documented system DLL API.
// No additional ordinary-program import or CRT dependency is introduced.
unsafe void native_cache_atomic_replace(
    ref IrContext context, ref NativeFunction function,
    usize instruction, usize result
) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    x64_mov_r64_memory(function.code, 0, 4, 504);
    x64_mov_memory_r64(function.code, 4, 616, 0);
    native_utf8_path(function, d_operand_value(context, instruction, 1));
    x64_mov_r64_memory(function.code, 0, 4, 504);
    x64_mov_memory_r64(function.code, 4, 624, 0);
    native_windows_dynamic_prepare(function, "kernel32.dll", "MoveFileExW");
    usize available = native_windows_dynamic_available(function);
    native_status_failure(function, result, 1);
    usize done = native_jump(function.code);
    native_skip_end(function.code, available);
    x64_mov_r64_memory(function.code, 1, 4, 616);
    x64_mov_r64_memory(function.code, 2, 4, 624);
    // MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH. No cross-volume copy.
    x64_mov_r64_imm64(function.code, 8, cast(u64, 9));
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize failed = native_skip(function.code, 4);
    native_status_success(function, result);
    usize succeeded = native_jump(function.code);
    native_skip_end(function.code, failed);
    native_status_failure(function, result, 1);
    native_skip_end(function.code, succeeded);
    native_skip_end(function.code, done);
    native_windows_dynamic_close(function);
    native_import(function, 7); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 616); native_heap_free_r8(function);
    native_import(function, 7); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 624); native_heap_free_r8(function);
}
