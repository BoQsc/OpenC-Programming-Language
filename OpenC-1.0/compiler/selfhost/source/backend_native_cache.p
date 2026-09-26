import system.text;

// CryptHashCertificate2 hashes arbitrary input bytes with the documented CNG
// SHA256 provider. It is loaded only by this opt-in cache path. An unavailable
// function returns false so the caller uses the OpenC SHA-256 implementation.
unsafe void native_cache_sha256(
    ref IrContext context, ref NativeFunction function,
    usize instruction, usize result
) {
    native_windows_dynamic_prepare(function, "crypt32.dll", "CryptHashCertificate2");
    usize available = native_windows_dynamic_available(function);
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
    native_windows_dynamic_close(function);
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
