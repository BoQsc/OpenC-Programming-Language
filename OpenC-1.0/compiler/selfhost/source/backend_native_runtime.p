import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

// Native Hosted primitives. These emit documented Windows calls directly;
// they never invoke a C runtime or shell command.
unsafe void native_import(ref NativeFunction function, usize index) {
    x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 21);
    usize offset = function.code.bytes.length;
    x64_emit_u32(function.code, 0);
    x64_add_relocation(function.code, offset, x64_relocation_relative32(),
        cast(usize, 1073741824) + index, 0, 4);
}

// Native images reserve .data+32 for the current heap payload byte count.
// The relocation is RIP-relative and therefore adds no base-relocation entry.
unsafe void native_data_address(ref NativeFunction function, usize offset, usize reg) {
    x64_emit_rex(function.code, true, reg, 0, 5);
    x64_emit_u8(function.code, 141);
    x64_emit_u8(function.code, 5 + (reg & 7) * 8);
    usize patch = function.code.bytes.length; x64_emit_u32(function.code, 0);
    x64_add_relocation(function.code, patch, x64_relocation_relative32(),
        cast(usize, 3221225472) + offset, 0, 4);
}

unsafe void native_counter_increment(ref NativeFunction function, usize offset) {
    native_data_address(function, offset, 11);
    x64_mov_r64_memory(function.code, 0, 11, 0);
    x64_add_r64_imm8(function.code, 0, 1);
    x64_mov_memory_r64(function.code, 11, 0, 0);
}

unsafe void native_runtime_nonzero(ref NativeFunction function) {
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); native_require(function.code, 5);
}

unsafe void native_heap_allocate_named_r8(ref NativeFunction function, text live_message) {
    native_allocation_budget(function, 8);
    x64_mov_memory_r64(function.code, 4, 456, 8);
    native_data_address(function, 32, 10);
    x64_mov_r64_memory(function.code, 9, 10, 0);
    x64_mov_r64_r64(function.code, 11, 9);
    x64_add_r64_r64(function.code, 11, 8);
    x64_cmp_r64_r64(function.code, 11, 9);
    usize no_overflow = native_skip(function.code, 3);
    native_allocation_fatal(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocation byte counter overflow\n");
    native_skip_end(function.code, no_overflow);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 536870912));
    x64_cmp_r64_r64(function.code, 11, 9);
    usize within_live_budget = native_skip(function.code, 6);
    native_allocation_fatal(function, live_message);
    native_skip_end(function.code, within_live_budget);
    x64_mov_memory_r64(function.code, 4, 464, 11);
    native_import(function, 7); x64_mov_r64_r64(function.code, 1, 0);
    // The compiler's packed arenas contain sparse caches whose unused slots
    // must start at zero. Keep this deterministic under the live-byte guard.
    x64_mov_r64_imm64(function.code, 2, cast(u64, 8));
    x64_mov_r64_memory(function.code, 8, 4, 456);
    x64_add_r64_imm8(function.code, 8, 16);
    native_import(function, 9); native_runtime_nonzero(function);
    x64_mov_r64_r64(function.code, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 456);
    x64_mov_memory_r64(function.code, 10, 0, 11);
    x64_mov_r64_r64(function.code, 9, 10); x64_add_r64_imm8(function.code, 9, 16);
    native_data_address(function, 32, 10);
    x64_mov_r64_memory(function.code, 11, 4, 464);
    x64_mov_memory_r64(function.code, 10, 0, 11);
    x64_mov_r64_r64(function.code, 0, 9);
}

unsafe void native_heap_allocate_r8(ref NativeFunction function) {
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in native runtime\n");
}

unsafe void native_allocation_fatal(ref NativeFunction function, text message) {
    native_constant_ascii(function, message, false, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, text.byte_length(message)));
    native_write_console(function, true);
    native_constant_ascii(function, "OpenC checked failure\n", false, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 22));
    native_write_console(function, true);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 70));
    native_import(function, 2);
}

unsafe void native_allocation_budget(ref NativeFunction function, usize size_register) {
    x64_mov_r64_imm64(function.code, 11, cast(u64, 268435456));
    x64_cmp_r64_r64(function.code, size_register, 11);
    usize allowed = native_skip(function.code, 6);
    native_allocation_fatal(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: one allocation exceeds 256 MiB\n");
    native_skip_end(function.code, allowed);
}

unsafe void native_heap_free_r8(ref NativeFunction function) {
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize empty = native_skip(function.code, 4);
    x64_alu_r64_imm8(function.code, 5, 8, 16);
    x64_mov_memory_r64(function.code, 4, 456, 8);
    x64_mov_r64_memory(function.code, 11, 8, 0);
    native_data_address(function, 32, 10);
    x64_mov_r64_memory(function.code, 9, 10, 0);
    x64_cmp_r64_r64(function.code, 11, 9); native_require(function.code, 6);
    x64_binary_r64_r64(function.code, 41, 9, 11);
    x64_mov_memory_r64(function.code, 10, 0, 9);
    native_import(function, 7); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 456);
    native_import(function, 10); native_runtime_nonzero(function);
    native_skip_end(function.code, empty);
}

unsafe void native_copy_bytes(ref NativeFunction function) {
    // R10=destination, R11=source, R9=count.
    // Move full words first. Compiler input is dominated by text and path
    // copies, so the former byte-only loop was a major self-host throughput
    // bottleneck even though it was functionally correct.
    usize word_loop_start = function.code.bytes.length;
    x64_alu_r64_imm8(function.code, 7, 9, 8);
    usize byte_tail = native_skip(function.code, 2);
    x64_mov_r64_memory(function.code, 0, 11, 0);
    x64_mov_memory_r64(function.code, 10, 0, 0);
    x64_add_r64_imm8(function.code, 10, 8); x64_add_r64_imm8(function.code, 11, 8);
    x64_alu_r64_imm8(function.code, 5, 9, 8);
    usize repeat_words = native_jump(function.code);
    x64_patch_u32(function.code, repeat_words, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_words + 4 - word_loop_start)));
    native_skip_end(function.code, byte_tail);
    usize loop_start = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize done = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    native_runtime_store_byte(function, 10, 0);
    x64_add_r64_imm8(function.code, 10, 1); x64_add_r64_imm8(function.code, 11, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat = native_jump(function.code);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    native_skip_end(function.code, done);
}

unsafe void native_constant_ascii(ref NativeFunction function, text value,
    bool wide, usize register_code) {
    usize start = function.constants.length;
    usize index = 0;
    while index < text.byte_length(value) {
        d_put_byte(function.constants, byte_at_or_zero(value, index));
        if wide { d_put_byte(function.constants, 0); }
        index = index + 1;
    }
    d_put_byte(function.constants, 0);
    if wide { d_put_byte(function.constants, 0); }
    x64_emit_rex(function.code, true, register_code, 0, 5);
    x64_emit_u8(function.code, 141);
    x64_emit_u8(function.code, 5 + (register_code & 7) * 8);
    usize patch = function.code.bytes.length; x64_emit_u32(function.code, 0);
    x64_add_relocation(function.code, patch, x64_relocation_relative32(),
        cast(usize, 2147483648) + start, 0, 4);
}

unsafe void native_runtime_store_byte(ref NativeFunction function,
    usize base, usize source) {
    x64_emit_rex(function.code, false, source, 0, base);
    x64_emit_u8(function.code, 136);
    x64_emit_memory_modrm(function.code, source, base, 0);
}

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

unsafe void native_text_scalar_slice(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result) {
    usize value = d_operand_value(context, instruction, 0);
    native_load(function, value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_memory_r64(function.code, 4, 360, 0);
    native_load(function, d_operand_value(context, instruction, 2), 11);
    x64_mov_memory_r64(function.code, 4, 368, 11);
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 6);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 376, 0);
    x64_mov_memory_r64(function.code, 4, 384, 0);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 0));
    usize loop_start = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize at_end = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 37);
    x64_emit_u32(function.code, 192);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 128));
    x64_cmp_r64_r64(function.code, 0, 11); usize continuation = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 11, 4, 360);
    x64_cmp_r64_r64(function.code, 10, 11); usize not_lower = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 376, 8); native_skip_end(function.code, not_lower);
    x64_mov_r64_memory(function.code, 11, 4, 368);
    x64_cmp_r64_r64(function.code, 10, 11); usize not_upper = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 384, 8); native_skip_end(function.code, not_upper);
    x64_add_r64_imm8(function.code, 10, 1); native_skip_end(function.code, continuation);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat = native_jump(function.code);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    native_skip_end(function.code, at_end);
    x64_mov_r64_memory(function.code, 11, 4, 360);
    x64_cmp_r64_r64(function.code, 10, 11); usize end_not_lower = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 376, 8); native_skip_end(function.code, end_not_lower);
    x64_mov_r64_memory(function.code, 11, 4, 368);
    x64_cmp_r64_r64(function.code, 10, 11); usize end_not_upper = native_skip(function.code, 5);
    x64_mov_memory_r64(function.code, 4, 384, 8); native_skip_end(function.code, end_not_upper);
    x64_cmp_r64_r64(function.code, 11, 10); native_require(function.code, 6);
    usize out_value = d_operand_value(context, instruction, 3);
    native_output_address(function, out_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 376);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 10, 4, 384);
    x64_binary_r64_r64(function.code, 41, 10, 0);
    x64_mov_memory_r64(function.code, 11, 8, 10);
    native_status_success(function, result);
}

unsafe void native_path_join(ref NativeFunction function, usize left, usize right,
    usize result) {
    native_load(function, left, 0); x64_mov_memory_r64(function.code, 4, 416, 0);
    x64_mov_r64_memory(function.code, 0, 4, native_slot(function, left) + 8);
    x64_mov_memory_r64(function.code, 4, 424, 0);
    native_load(function, right, 0); x64_mov_memory_r64(function.code, 4, 432, 0);
    x64_mov_r64_memory(function.code, 0, 4, native_slot(function, right) + 8);
    x64_mov_memory_r64(function.code, 4, 440, 0);
    // A Windows drive-qualified right operand is already absolute. Returning
    // it directly also avoids allocating and caching a meaningless
    // "base/C:\\..." spelling when project/test manifests use absolute paths.
    x64_mov_r64_memory(function.code, 10, 4, 440);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 3));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize relative_short = native_skip(function.code, 2);
    x64_mov_r64_memory(function.code, 11, 4, 432);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182);
    x64_emit_memory_modrm(function.code, 0, 11, 1);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 58));
    x64_cmp_r64_r64(function.code, 0, 10);
    usize relative_no_colon = native_skip(function.code, 5);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182);
    x64_emit_memory_modrm(function.code, 0, 11, 2);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 47));
    x64_cmp_r64_r64(function.code, 0, 10);
    usize absolute_slash = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 92));
    x64_cmp_r64_r64(function.code, 0, 10);
    usize relative_no_separator = native_skip(function.code, 5);
    native_skip_end(function.code, absolute_slash);
    x64_mov_r64_memory(function.code, 0, 4, 432);
    native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 440);
    x64_mov_memory_r64(
        function.code, 4, native_slot(function, result) + 8, 0
    );
    usize absolute_finished = native_jump(function.code);
    native_skip_end(function.code, relative_short);
    native_skip_end(function.code, relative_no_colon);
    native_skip_end(function.code, relative_no_separator);
    native_data_address(function, 48, 11);
    x64_mov_r64_memory(function.code, 10, 11, 0);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210); usize join_table_ready = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 3145728));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in path.join cache\n");
    x64_mov_r64_r64(function.code, 10, 0);
    native_data_address(function, 48, 11);
    x64_mov_memory_r64(function.code, 11, 0, 10);
    x64_mov_r64_r64(function.code, 8, 10);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 3145728));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    usize clear_join_table = function.code.bytes.length;
    native_runtime_store_byte(function, 8, 0);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 133);
    usize repeat_clear_join = function.code.bytes.length; x64_emit_u32(function.code, 0);
    x64_patch_u32(function.code, repeat_clear_join,
        cast(u32, cast(u64, 4294967296) - cast(u64,
            repeat_clear_join + 4 - clear_join_table)));
    native_skip_end(function.code, join_table_ready);
    x64_mov_r64_memory(function.code, 10, 4, 416);
    x64_shift_r64_imm8(function.code, 5, 10, 4);
    x64_mov_r64_memory(function.code, 11, 4, 432);
    x64_shift_r64_imm8(function.code, 5, 11, 4);
    x64_binary_r64_r64(function.code, 49, 10, 11);
    x64_add_r64_memory(function.code, 10, 4, 424);
    x64_mov_r64_memory(function.code, 11, 4, 440);
    x64_binary_r64_r64(function.code, 49, 10, 11);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 65535));
    x64_binary_r64_r64(function.code, 33, 10, 11);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 10, 5);
    x64_shift_r64_imm8(function.code, 4, 11, 4);
    x64_add_r64_r64(function.code, 10, 11);
    native_data_address(function, 48, 11);
    x64_mov_r64_memory(function.code, 11, 11, 0);
    x64_add_r64_r64(function.code, 10, 11);
    x64_mov_memory_r64(function.code, 4, 576, 10);
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 416);
    x64_cmp_r64_r64(function.code, 0, 11); usize join_miss_left = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 0, 10, 8);
    x64_mov_r64_memory(function.code, 11, 4, 424);
    x64_cmp_r64_r64(function.code, 0, 11); usize join_miss_left_length = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 0, 10, 16);
    x64_mov_r64_memory(function.code, 11, 4, 432);
    x64_cmp_r64_r64(function.code, 0, 11); usize join_miss_right = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 0, 10, 24);
    x64_mov_r64_memory(function.code, 11, 4, 440);
    x64_cmp_r64_r64(function.code, 0, 11); usize join_miss_right_length = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 0, 10, 32); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 10, 40);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    native_counter_increment(function, 72);
    usize join_finished = native_jump(function.code);
    native_skip_end(function.code, join_miss_left);
    native_skip_end(function.code, join_miss_left_length);
    native_skip_end(function.code, join_miss_right);
    native_skip_end(function.code, join_miss_right_length);
    native_counter_increment(function, 80);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 0));
    x64_mov_r64_memory(function.code, 9, 4, 424);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize no_left = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 11, 4, 416); x64_add_r64_r64(function.code, 11, 9);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 203);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 47));
    x64_cmp_r64_r64(function.code, 0, 11); usize no_slash = native_skip(function.code, 5);
    usize separator_done = native_jump(function.code); native_skip_end(function.code, no_slash);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 92));
    x64_cmp_r64_r64(function.code, 0, 11); usize no_backslash = native_skip(function.code, 5);
    usize separator_done_two = native_jump(function.code); native_skip_end(function.code, no_backslash);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 1));
    native_skip_end(function.code, separator_done_two);
    native_skip_end(function.code, separator_done); native_skip_end(function.code, no_left);
    x64_mov_memory_r64(function.code, 4, 448, 10);
    x64_mov_r64_memory(function.code, 8, 4, 424);
    x64_add_r64_memory(function.code, 8, 4, 440); x64_add_r64_r64(function.code, 8, 10);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in path.join\n");
    x64_mov_memory_r64(function.code, 4, 464, 0);
    x64_mov_r64_r64(function.code, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 416);
    x64_mov_r64_memory(function.code, 9, 4, 424); native_copy_bytes(function);
    x64_mov_r64_memory(function.code, 9, 4, 448);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize no_separator = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 47)); native_runtime_store_byte(function, 10, 0);
    x64_add_r64_imm8(function.code, 10, 1); native_skip_end(function.code, no_separator);
    x64_mov_r64_memory(function.code, 11, 4, 432);
    x64_mov_r64_memory(function.code, 9, 4, 440); native_copy_bytes(function);
    x64_mov_r64_memory(function.code, 0, 4, 464); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 456);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    x64_mov_r64_memory(function.code, 10, 4, 576);
    x64_mov_r64_memory(function.code, 0, 4, 416); x64_mov_memory_r64(function.code, 10, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 424); x64_mov_memory_r64(function.code, 10, 8, 0);
    x64_mov_r64_memory(function.code, 0, 4, 432); x64_mov_memory_r64(function.code, 10, 16, 0);
    x64_mov_r64_memory(function.code, 0, 4, 440); x64_mov_memory_r64(function.code, 10, 24, 0);
    x64_mov_r64_memory(function.code, 0, 4, 464); x64_mov_memory_r64(function.code, 10, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 456); x64_mov_memory_r64(function.code, 10, 40, 0);
    native_skip_end(function.code, join_finished);
    native_skip_end(function.code, absolute_finished);
}

unsafe void native_path_directory(ref NativeFunction function, usize value,
    usize result) {
    native_load(function, value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
    x64_mov_r64_r64(function.code, 10, 9);
    usize search = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210); usize no_separator = native_skip(function.code, 4);
    x64_mov_r64_r64(function.code, 11, 8); x64_add_r64_r64(function.code, 11, 10);
    x64_alu_r64_imm8(function.code, 5, 11, 1);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 47));
    x64_cmp_r64_r64(function.code, 0, 11); usize not_slash = native_skip(function.code, 5);
    usize found_slash = native_jump(function.code); native_skip_end(function.code, not_slash);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 92));
    x64_cmp_r64_r64(function.code, 0, 11); usize not_backslash = native_skip(function.code, 5);
    usize found_backslash = native_jump(function.code); native_skip_end(function.code, not_backslash);
    x64_alu_r64_imm8(function.code, 5, 10, 1);
    usize repeat_search = native_jump(function.code);
    x64_patch_u32(function.code, repeat_search,
        cast(u32, cast(u64, 4294967296) - cast(u64, repeat_search + 4 - search)));

    native_skip_end(function.code, found_slash); native_skip_end(function.code, found_backslash);
    usize trim = function.code.bytes.length;
    x64_mov_r64_imm64(function.code, 11, cast(u64, 1));
    x64_cmp_r64_r64(function.code, 10, 11); usize directory_ready = native_skip(function.code, 6);
    x64_mov_r64_r64(function.code, 11, 8); x64_add_r64_r64(function.code, 11, 10);
    x64_alu_r64_imm8(function.code, 5, 11, 1);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 47));
    x64_cmp_r64_r64(function.code, 0, 11); usize not_trim_slash = native_skip(function.code, 5);
    usize trim_slash = native_jump(function.code); native_skip_end(function.code, not_trim_slash);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 92));
    x64_cmp_r64_r64(function.code, 0, 11); usize not_trim_backslash = native_skip(function.code, 5);
    usize trim_backslash = native_jump(function.code); native_skip_end(function.code, not_trim_backslash);
    usize directory_ready_jump = native_jump(function.code);
    native_skip_end(function.code, trim_slash); native_skip_end(function.code, trim_backslash);
    x64_alu_r64_imm8(function.code, 5, 10, 1);
    usize repeat_trim = native_jump(function.code);
    x64_patch_u32(function.code, repeat_trim,
        cast(u32, cast(u64, 4294967296) - cast(u64, repeat_trim + 4 - trim)));
    native_skip_end(function.code, directory_ready);
    native_skip_end(function.code, directory_ready_jump);
    native_store(function, result, 8);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 10);
    usize done = native_jump(function.code);

    native_skip_end(function.code, no_separator);
    usize constant_start = function.constants.length;
    d_put_byte(function.constants, 46); d_put_byte(function.constants, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 141);
    x64_emit_u8(function.code, 5); usize constant_patch = function.code.bytes.length;
    x64_emit_u32(function.code, 0);
    x64_add_relocation(function.code, constant_patch, x64_relocation_relative32(),
        cast(usize, 2147483648) + constant_start, 0, 4);
    native_store(function, result, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    native_skip_end(function.code, done);
}
