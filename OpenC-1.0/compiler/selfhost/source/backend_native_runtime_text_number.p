import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_write_integer(ref NativeFunction function, bool signed_value) {
    // RAX is the normalized value. Build the canonical decimal spelling
    // backwards in frame scratch, then use the exact-write console loop.
    x64_mov_r64_r64(function.code, 10, 0);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    if signed_value {
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 192);
        usize nonnegative = native_skip(function.code, 9);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 247);
        x64_emit_u8(function.code, 216);
        x64_mov_r64_r64(function.code, 10, 0);
        x64_mov_r64_imm64(function.code, 9, cast(u64, 1));
        native_skip_end(function.code, nonnegative);
    }
    x64_emit_rex(function.code, true, 10, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 10, 4, 352);
    usize loop_start = function.code.bytes.length;
    x64_xor_r64_r64(function.code, 2, 2);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 10));
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 247);
    x64_emit_u8(function.code, 243);
    x64_add_r64_imm8(function.code, 2, 48);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255);
    x64_emit_u8(function.code, 202);
    native_runtime_store_byte(function, 10, 2);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 133);
    usize repeat = function.code.bytes.length; x64_emit_u32(function.code, 0);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize unsigned_value = native_skip(function.code, 4);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255);
    x64_emit_u8(function.code, 202);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 45));
    native_runtime_store_byte(function, 10, 0);
    native_skip_end(function.code, unsigned_value);
    x64_emit_rex(function.code, true, 8, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 8, 4, 352);
    x64_binary_r64_r64(function.code, 41, 8, 10);
    x64_mov_r64_r64(function.code, 2, 10);
    native_write_console(function, false);
}

unsafe void native_write_bool(ref NativeFunction function) {
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize false_value = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1702195828));
    x64_mov_memory_r64(function.code, 4, 400, 0);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 4));
    usize ready = native_jump(function.code); native_skip_end(function.code, false_value);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 435728179558));
    x64_mov_memory_r64(function.code, 4, 400, 0);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 5));
    native_skip_end(function.code, ready);
    x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 2, 4, 400);
    native_write_console(function, false);
}

unsafe void native_text_trim(ref NativeFunction function, usize value, usize result) {
    native_load(function, value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
    usize leading = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize no_leading = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 32));
    x64_cmp_r64_r64(function.code, 0, 10); usize no_leading_space = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat_leading = native_jump(function.code);
    x64_patch_u32(function.code, repeat_leading, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_leading + 4 - leading)));
    native_skip_end(function.code, no_leading_space); native_skip_end(function.code, no_leading);
    usize trailing = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize no_trailing = native_skip(function.code, 4);
    x64_mov_r64_r64(function.code, 11, 8); x64_add_r64_r64(function.code, 11, 9);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 203);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 32));
    x64_cmp_r64_r64(function.code, 0, 10); usize no_trailing_space = native_skip(function.code, 5);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat_trailing = native_jump(function.code);
    x64_patch_u32(function.code, repeat_trailing, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_trailing + 4 - trailing)));
    native_skip_end(function.code, no_trailing_space); native_skip_end(function.code, no_trailing);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result), 8);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 9);
}

unsafe void native_text_scalar_length(ref NativeFunction function, usize value,
    usize result) {
    native_load(function, value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 0));
    usize loop_start = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize done = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 37);
    x64_emit_u32(function.code, 192);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 128));
    x64_cmp_r64_r64(function.code, 0, 11); usize continuation = native_skip(function.code, 4);
    x64_add_r64_imm8(function.code, 10, 1); native_skip_end(function.code, continuation);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat = native_jump(function.code);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    native_skip_end(function.code, done);
    native_store(function, result, 10);
}

unsafe void native_status_success(ref NativeFunction function, usize result) {
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, native_slot(function, result), 0);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 16, 0);
}

unsafe void native_status_failure(ref NativeFunction function, usize result, usize code) {
    x64_mov_r64_imm64(function.code, 0, cast(u64, code));
    x64_mov_memory_r64(function.code, 4, native_slot(function, result), 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 16, 0);
}
