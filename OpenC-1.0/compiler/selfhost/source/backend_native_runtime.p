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
    native_value_address(context, function, out_value, 11);
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

unsafe void native_process_executable_directory(ref NativeFunction function,
    usize result) {
    x64_mov_r64_imm64(function.code, 8, cast(u64, 65544));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.executable_directory\n");
    x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_r64(function.code, 2, 0);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 32768));
    native_import(function, 17); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 32768));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 2);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.executable_directory UTF-8 conversion\n");
    x64_mov_memory_r64(function.code, 4, 504, 0);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_memory(function.code, 0, 4, 504);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 10, 4, 496);
    x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 504); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
    native_path_directory(function, result, result);
}

unsafe void native_command_arguments(ref NativeFunction function) {
    native_constant_ascii(function, "shell32.dll", true, 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 2048));
    native_import(function, 19); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_r64(function.code, 1, 0);
    native_constant_ascii(function, "CommandLineToArgvW", false, 2);
    native_import(function, 20); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    native_import(function, 4); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 2, 4, 496);
    x64_mov_r64_memory(function.code, 11, 4, 488); x64_call_r64(function.code, 11);
    native_runtime_nonzero(function); x64_mov_memory_r64(function.code, 4, 504, 0);
}

unsafe void native_release_command_arguments(ref NativeFunction function) {
    x64_mov_r64_memory(function.code, 1, 4, 504); native_import(function, 21);
    x64_mov_r64_memory(function.code, 1, 4, 480); native_import(function, 22);
}

unsafe void native_process_argument_count(ref NativeFunction function, usize result) {
    native_command_arguments(function);
    x64_mov_r64_memory(function.code, 0, 4, 496); native_runtime_nonzero(function);
    x64_alu_r64_imm8(function.code, 5, 0, 1);
    native_store(function, result, 0);
    native_release_command_arguments(function);
}

unsafe void native_process_argument(ref NativeFunction function, usize value,
    usize result) {
    native_load(function, value, 0); x64_mov_memory_r64(function.code, 4, 472, 0);
    native_command_arguments(function);
    x64_mov_r64_memory(function.code, 10, 4, 472); x64_add_r64_imm8(function.code, 10, 1);
    x64_mov_r64_memory(function.code, 11, 4, 496);
    x64_cmp_r64_r64(function.code, 10, 11); native_require(function.code, 2);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_add_r64_r64(function.code, 11, 11);
    x64_add_r64_r64(function.code, 11, 11);
    x64_add_r64_r64(function.code, 11, 11);
    x64_add_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 8, 11, 0);
    x64_mov_memory_r64(function.code, 4, 512, 8);
    x64_mov_r64_r64(function.code, 10, 8);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    usize length_loop = function.code.bytes.length;
    x64_emit_rex(function.code, false, 0, 0, 10); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 183); x64_emit_memory_modrm(function.code, 0, 10, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize length_done = native_skip(function.code, 4);
    x64_add_r64_imm8(function.code, 10, 2); x64_add_r64_imm8(function.code, 9, 1);
    usize repeat_length = native_jump(function.code);
    x64_patch_u32(function.code, repeat_length,
        cast(u32, cast(u64, 4294967296) - cast(u64, repeat_length + 4 - length_loop)));
    native_skip_end(function.code, length_done);
    x64_mov_memory_r64(function.code, 4, 520, 9);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 512);
    x64_mov_r64_memory(function.code, 9, 4, 520);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process.argument\n");
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 512);
    x64_mov_r64_memory(function.code, 9, 4, 520);
    x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_import(function, 13); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 536);
    x64_mov_r64_memory(function.code, 10, 4, 528); x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 11, 0, 0);
    native_release_command_arguments(function);
    x64_mov_r64_memory(function.code, 0, 4, 536); native_store(function, result, 0);
    x64_mov_r64_memory(function.code, 0, 4, 528);
    x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
}

unsafe void native_utf8_path(ref NativeFunction function, usize value) {
    native_load(function, value, 0); x64_mov_memory_r64(function.code, 4, 480, 0);
    x64_mov_r64_memory(function.code, 0, 4, native_slot(function, value) + 8);
    x64_mov_memory_r64(function.code, 4, 488, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 8));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 32, 0); x64_mov_memory_r64(function.code, 4, 40, 0);
    native_import(function, 15); native_runtime_nonzero(function);
    x64_mov_memory_r64(function.code, 4, 496, 0);
    x64_mov_r64_r64(function.code, 8, 0); x64_add_r64_r64(function.code, 8, 8);
    x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in UTF-8 path conversion\n");
    x64_mov_memory_r64(function.code, 4, 504, 0);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 65001));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 8));
    x64_mov_r64_memory(function.code, 8, 4, 480);
    x64_mov_r64_memory(function.code, 9, 4, 488);
    x64_mov_r64_memory(function.code, 0, 4, 504); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_memory(function.code, 0, 4, 496); x64_mov_memory_r64(function.code, 4, 40, 0);
    native_import(function, 15); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 11, 4, 504);
    x64_mov_r64_memory(function.code, 10, 4, 496); x64_add_r64_r64(function.code, 10, 10);
    x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 11, 0, 0);
}

// Read one Content-Length-framed JSON-RPC request from standard input. The
// hosted C runtime used this internal file name as a transport hook; the native
// compiler owns the equivalent pipe reader so `openc lsp --stdio` has no CRT.
unsafe void native_lsp_read_frame(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    usize output_value = d_operand_value(context, instruction, 0);
    native_value_address(context, function, output_value, 11);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    // Scratch: handle=600, length=608, parse-first-line=616,
    // consecutive-linefeeds=624, bytes-read=632, byte=640,
    // body=648, body-read=656.
    x64_mov_memory_r64(function.code, 4, 608, 0);
    x64_mov_memory_r64(function.code, 4, 624, 0);
    x64_mov_memory_r64(function.code, 4, 648, 0);
    x64_mov_memory_r64(function.code, 4, 656, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 616, 0);
    x64_mov_r64_imm64(
        function.code, 1, pe32_u64_minus_eleven() + cast(u64, 1)
    );
    native_import(function, 8);
    x64_mov_memory_r64(function.code, 4, 600, 0);

    usize header_loop = function.code.bytes.length;
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 632, 0);
    x64_mov_memory_r64(function.code, 4, 640, 0);
    x64_mov_r64_memory(function.code, 1, 4, 600);
    native_stack_address(function, 640, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 1));
    native_stack_address(function, 632, 9);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize header_read_failed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 632);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize header_empty = native_skip(function.code, 4);

    // Only the first header line contributes decimal digits. This accepts the
    // case-insensitive Content-Length spelling already enforced by the public
    // LSP client contract while ignoring digits in optional later headers.
    x64_mov_r64_memory(function.code, 10, 4, 616);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210);
    usize skip_digit = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 48));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize below_digit = native_skip(function.code, 2);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 57));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize above_digit = native_skip(function.code, 7);
    x64_alu_r64_imm8(function.code, 5, 0, 48);
    x64_mov_r64_memory(function.code, 10, 4, 608);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 10, 3);
    x64_shift_r64_imm8(function.code, 4, 11, 1);
    x64_add_r64_r64(function.code, 10, 11);
    x64_add_r64_r64(function.code, 10, 0);
    x64_mov_memory_r64(function.code, 4, 608, 10);
    native_skip_end(function.code, below_digit);
    native_skip_end(function.code, above_digit);
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 13));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize not_first_cr = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 616, 10);
    native_skip_end(function.code, not_first_cr);
    native_skip_end(function.code, skip_digit);

    // Two linefeeds with only the separating carriage return terminate the
    // header block. Any other byte resets the small state machine.
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 10));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize not_linefeed = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 10, 4, 624);
    x64_add_r64_imm8(function.code, 10, 1);
    x64_mov_memory_r64(function.code, 4, 624, 10);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 2));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize header_not_done = native_skip(function.code, 5);
    usize header_done = native_jump(function.code);
    native_skip_end(function.code, header_not_done);
    usize repeat_header_after_lf = native_jump(function.code);
    x64_patch_u32(function.code, repeat_header_after_lf,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_header_after_lf + 4 - header_loop)));
    native_skip_end(function.code, not_linefeed);
    x64_mov_r64_memory(function.code, 0, 4, 640);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 13));
    x64_cmp_r64_r64(function.code, 0, 11);
    usize not_carriage_return = native_skip(function.code, 5);
    usize repeat_header_after_cr = native_jump(function.code);
    x64_patch_u32(function.code, repeat_header_after_cr,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_header_after_cr + 4 - header_loop)));
    native_skip_end(function.code, not_carriage_return);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 624, 0);
    usize repeat_header = native_jump(function.code);
    x64_patch_u32(function.code, repeat_header,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_header + 4 - header_loop)));

    native_skip_end(function.code, header_done);
    x64_mov_r64_memory(function.code, 10, 4, 608);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210);
    usize missing_length = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 16777216));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize length_too_large = native_skip(function.code, 7);
    x64_mov_r64_r64(function.code, 8, 10);
    x64_add_r64_imm8(function.code, 8, 1);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB reading LSP frame\n");
    x64_mov_memory_r64(function.code, 4, 648, 0);

    usize body_loop = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 10, 4, 656);
    x64_mov_r64_memory(function.code, 11, 4, 608);
    x64_cmp_r64_r64(function.code, 10, 11);
    usize body_done = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 1, 4, 600);
    x64_mov_r64_memory(function.code, 2, 4, 648);
    x64_add_r64_r64(function.code, 2, 10);
    x64_mov_r64_r64(function.code, 8, 11);
    x64_binary_r64_r64(function.code, 41, 8, 10);
    native_stack_address(function, 632, 9);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 632, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize body_read_failed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 632);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize body_empty = native_skip(function.code, 4);
    x64_add_r64_memory(function.code, 0, 4, 656);
    x64_mov_memory_r64(function.code, 4, 656, 0);
    usize repeat_body = native_jump(function.code);
    x64_patch_u32(function.code, repeat_body,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_body + 4 - body_loop)));

    native_skip_end(function.code, body_done);
    x64_mov_r64_memory(function.code, 11, 4, 648);
    x64_add_r64_memory(function.code, 11, 4, 608);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_runtime_store_byte(function, 11, 0);
    native_value_address(context, function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 648);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    native_status_success(function, result);
    usize lsp_finished = native_jump(function.code);

    native_skip_end(function.code, header_read_failed);
    native_skip_end(function.code, header_empty);
    native_skip_end(function.code, missing_length);
    native_skip_end(function.code, length_too_large);
    native_skip_end(function.code, body_read_failed);
    native_skip_end(function.code, body_empty);
    x64_mov_r64_memory(function.code, 8, 4, 648);
    native_heap_free_r8(function);
    native_status_failure(function, result, 1);
    native_skip_end(function.code, lsp_finished);
}

unsafe void native_file_read(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result, bool raw_outputs) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 2147483648));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 7));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 3)); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 128)); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 48, 0);
    native_import(function, 1);
    x64_mov_r64_imm64(function.code, 11, ~cast(u64, 0)); x64_cmp_r64_r64(function.code, 0, 11);
    usize valid_handle = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    native_status_failure(function, result, 1);
    usize read_finished = native_jump(function.code);
    native_skip_end(function.code, valid_handle);
    x64_mov_memory_r64(function.code, 4, 512, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 1, 4, 512);
    x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 2, 4, 520);
    native_import(function, 18); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 8, 4, 520); x64_add_r64_imm8(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in file.read buffer\n");
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_r64_memory(function.code, 1, 4, 512);
    x64_mov_r64_memory(function.code, 2, 4, 536);
    x64_mov_r64_memory(function.code, 8, 4, 520);
    x64_emit_rex(function.code, true, 9, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 9, 4, 528);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 1, 4, 512); native_import(function, 0);
    x64_mov_r64_memory(function.code, 11, 4, 536);
    x64_mov_r64_memory(function.code, 10, 4, 528); x64_add_r64_r64(function.code, 11, 10);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 11, 0, 0);
    if raw_outputs {
        usize data_value = d_operand_value(context, instruction, 1);
        native_value_address(context, function, data_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 11, 0, 0);
        usize length_value = d_operand_value(context, instruction, 2);
        native_value_address(context, function, length_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 11, 0, 0);
    } else {
        usize output_value = d_operand_value(context, instruction, 1);
        native_value_address(context, function, output_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 11, 0, 0);
        x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 11, 8, 0);
    }
    native_status_success(function, result);
    native_skip_end(function.code, read_finished);
}

// A direct-mapped cache keeps source texts process-owned for the compiler
// lifetime. The 262,144 entries are allocated lazily; collisions remain correct
// (they reread and replace the entry) and cannot create an unbounded table.
unsafe void native_file_read_cached(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result) {
    usize path_value = d_operand_value(context, instruction, 0);
    native_data_address(function, 40, 11);
    x64_mov_r64_memory(function.code, 10, 11, 0);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 210); usize table_ready = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 10485760));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in file text cache\n");
    x64_mov_r64_r64(function.code, 10, 0);
    native_data_address(function, 40, 11);
    x64_mov_memory_r64(function.code, 11, 0, 10);
    x64_mov_r64_r64(function.code, 8, 10);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 10485760));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    usize clear_loop = function.code.bytes.length;
    native_runtime_store_byte(function, 8, 0);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    x64_emit_u8(function.code, 15); x64_emit_u8(function.code, 133);
    usize repeat_clear = function.code.bytes.length; x64_emit_u32(function.code, 0);
    x64_patch_u32(function.code, repeat_clear, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_clear + 4 - clear_loop)));
    native_skip_end(function.code, table_ready);

    native_load(function, path_value, 8);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, path_value) + 8);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 5381));
    usize hash_loop = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize hash_done = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 11, 5);
    x64_add_r64_r64(function.code, 10, 11);
    x64_binary_r64_r64(function.code, 49, 10, 0);
    x64_add_r64_imm8(function.code, 8, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat_hash = native_jump(function.code);
    x64_patch_u32(function.code, repeat_hash, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_hash + 4 - hash_loop)));
    native_skip_end(function.code, hash_done);
    x64_mov_memory_r64(function.code, 4, 552, 10);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 262143));
    x64_binary_r64_r64(function.code, 33, 10, 11);
    x64_mov_r64_r64(function.code, 11, 10);
    x64_shift_r64_imm8(function.code, 4, 10, 5);
    x64_shift_r64_imm8(function.code, 4, 11, 3);
    x64_add_r64_r64(function.code, 10, 11);
    native_data_address(function, 40, 11);
    x64_mov_r64_memory(function.code, 11, 11, 0);
    x64_add_r64_r64(function.code, 10, 11);
    x64_mov_memory_r64(function.code, 4, 544, 10);

    x64_mov_r64_memory(function.code, 8, 10, 8);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize miss_empty = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 552);
    x64_cmp_r64_r64(function.code, 0, 11); usize miss_hash = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 0, 10, 16);
    x64_mov_r64_memory(function.code, 9, 4, native_slot(function, path_value) + 8);
    x64_cmp_r64_r64(function.code, 0, 9); usize miss_length = native_skip(function.code, 5);
    native_load(function, path_value, 11);
    usize compare_loop = function.code.bytes.length;
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201); usize cache_hit = native_skip(function.code, 4);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 0);
    x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 11);
    x64_cmp_r64_r64(function.code, 0, 1); usize miss_byte = native_skip(function.code, 5);
    x64_add_r64_imm8(function.code, 8, 1); x64_add_r64_imm8(function.code, 11, 1);
    x64_emit_u8(function.code, 73); x64_emit_u8(function.code, 255); x64_emit_u8(function.code, 201);
    usize repeat_compare = native_jump(function.code);
    x64_patch_u32(function.code, repeat_compare, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat_compare + 4 - compare_loop)));
    native_skip_end(function.code, cache_hit);
    native_counter_increment(function, 56);
    x64_mov_r64_memory(function.code, 10, 4, 544);
    usize output_value = d_operand_value(context, instruction, 1);
    native_value_address(context, function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 10, 24); x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 10, 32); x64_mov_memory_r64(function.code, 11, 8, 0);
    native_status_success(function, result);
    usize finished = native_jump(function.code);

    native_skip_end(function.code, miss_empty); native_skip_end(function.code, miss_hash);
    native_skip_end(function.code, miss_length); native_skip_end(function.code, miss_byte);
    native_counter_increment(function, 64);
    native_file_read(context, function, instruction, result, false);
    native_load(function, result, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize read_failed = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 10, 4, 544);
    x64_mov_r64_memory(function.code, 0, 4, 552); x64_mov_memory_r64(function.code, 10, 0, 0);
    native_load(function, path_value, 0); x64_mov_memory_r64(function.code, 10, 8, 0);
    x64_mov_r64_memory(function.code, 0, 4, native_slot(function, path_value) + 8);
    x64_mov_memory_r64(function.code, 10, 16, 0);
    native_value_address(context, function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 11, 0); x64_mov_memory_r64(function.code, 10, 24, 0);
    x64_mov_r64_memory(function.code, 0, 11, 8); x64_mov_memory_r64(function.code, 10, 32, 0);
    native_skip_end(function.code, read_failed); native_skip_end(function.code, finished);
}

unsafe void native_file_write(ref IrContext context, ref NativeFunction function,
    usize instruction, usize result, bool raw_bytes) {
    native_utf8_path(function, d_operand_value(context, instruction, 0));
    usize input = d_operand_value(context, instruction, 1);
    native_load(function, input, 0); x64_mov_memory_r64(function.code, 4, 520, 0);
    if raw_bytes {
        native_load(function, d_operand_value(context, instruction, 2), 0);
    } else {
        x64_mov_r64_memory(function.code, 0, 4, native_slot(function, input) + 8);
    }
    x64_mov_memory_r64(function.code, 4, 528, 0);
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 1073741824));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 2)); x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 128)); x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0)); x64_mov_memory_r64(function.code, 4, 48, 0);
    native_import(function, 1); x64_mov_memory_r64(function.code, 4, 512, 0);
    native_import(function, 7); x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 0, 4, 512);
    x64_mov_r64_imm64(function.code, 11, ~cast(u64, 0)); x64_cmp_r64_r64(function.code, 0, 11);
    usize open_failed = native_skip(function.code, 4);

    usize write_loop = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 8, 4, 528);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize write_done = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 2147483647));
    x64_cmp_r64_r64(function.code, 8, 11); usize chunk_ready = native_skip(function.code, 6);
    x64_mov_r64_r64(function.code, 8, 11); native_skip_end(function.code, chunk_ready);
    x64_mov_r64_memory(function.code, 1, 4, 512);
    x64_mov_r64_memory(function.code, 2, 4, 520);
    x64_emit_rex(function.code, true, 9, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 9, 4, 536);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 536, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 14);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize write_failed = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 536);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); usize write_stalled = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 10, 4, 528);
    x64_cmp_r64_r64(function.code, 0, 10); usize write_too_large = native_skip(function.code, 7);
    x64_mov_r64_memory(function.code, 11, 4, 520); x64_add_r64_r64(function.code, 11, 0);
    x64_mov_memory_r64(function.code, 4, 520, 11);
    x64_binary_r64_r64(function.code, 41, 10, 0);
    x64_mov_memory_r64(function.code, 4, 528, 10);
    usize repeat_write = native_jump(function.code);
    x64_patch_u32(function.code, repeat_write,
        cast(u32, cast(u64, 4294967296) - cast(u64, repeat_write + 4 - write_loop)));

    native_skip_end(function.code, write_done);
    x64_mov_r64_memory(function.code, 1, 4, 512); native_import(function, 0);
    native_status_success(function, result); usize finished = native_jump(function.code);

    native_skip_end(function.code, write_failed); native_skip_end(function.code, write_stalled);
    native_skip_end(function.code, write_too_large);
    x64_mov_r64_memory(function.code, 1, 4, 512); native_import(function, 0);
    native_skip_end(function.code, open_failed);
    native_status_failure(function, result, 1);
    native_skip_end(function.code, finished);
}

// RDX=data and R8=byte count. Handle and cursor survive partial writes and
// volatile-register clobbers in frame-local runtime scratch slots.
unsafe void native_write_console(ref NativeFunction function, bool error_stream) {
    x64_mov_memory_r64(function.code, 4, 160, 2);
    x64_mov_memory_r64(function.code, 4, 168, 8);
    u64 handle = pe32_u64_minus_eleven();
    if error_stream { handle = handle - cast(u64, 1); }
    x64_mov_r64_imm64(function.code, 1, handle);
    native_import(function, 8);
    x64_mov_memory_r64(function.code, 4, 176, 0);
    usize loop_start = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 8, 4, 168);
    x64_emit_u8(function.code, 77); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize done = native_skip(function.code, 4);
    x64_mov_r64_imm64(function.code, 10, cast(u64, 1048576));
    x64_cmp_r64_r64(function.code, 8, 10);
    usize small = native_skip(function.code, 6);
    x64_mov_r64_r64(function.code, 8, 10); native_skip_end(function.code, small);
    x64_mov_r64_memory(function.code, 1, 4, 176);
    x64_mov_r64_memory(function.code, 2, 4, 160);
    x64_emit_rex(function.code, true, 9, 0, 4); x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, 9, 4, 184);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 184, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 14); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 0, 4, 184); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 10, 4, 168);
    x64_cmp_r64_r64(function.code, 0, 10); native_require(function.code, 6);
    x64_binary_r64_r64(function.code, 41, 10, 0);
    x64_mov_memory_r64(function.code, 4, 168, 10);
    x64_mov_r64_memory(function.code, 10, 4, 160);
    x64_add_r64_r64(function.code, 10, 0);
    x64_mov_memory_r64(function.code, 4, 160, 10);
    usize repeat = native_jump(function.code);
    x64_patch_u32(function.code, repeat, cast(u32, cast(u64, 4294967296) -
        cast(u64, repeat + 4 - loop_start)));
    native_skip_end(function.code, done);
}

unsafe void native_stack_address(
    ref NativeFunction function, usize offset, usize register_code
) {
    x64_emit_rex(function.code, true, register_code, 0, 4);
    x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, register_code, 4, offset);
}

unsafe void native_process_failure_outputs(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    usize exit_value = d_operand_value(context, instruction, 1);
    native_value_address(context, function, exit_value, 11);
    x64_mov_r64_imm64(function.code, 0, ~cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    usize output_value = d_operand_value(context, instruction, 2);
    native_value_address(context, function, output_value, 11);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    native_status_failure(function, result, 1);
}

// Spawn a child with inherited pipe handles and capture both stdout and stderr.
// The implementation calls documented KERNEL32 APIs directly. Output grows from
// 4 KiB and is capped at 64 MiB; excess data is drained before a visible guarded
// failure is returned so a noisy child cannot deadlock or exhaust the compiler.
unsafe void native_process_run(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    usize command_value = d_operand_value(context, instruction, 0);
    native_utf8_path(function, command_value);

    // Frame-local runtime storage. The first 1,536 bytes are reserved by every
    // native function specifically for runtime calls and Win64 shadow arguments.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    usize clear_offset = 576;
    while clear_offset < 896 {
        x64_mov_memory_r64(function.code, 4, clear_offset, 0);
        clear_offset = clear_offset + 8;
    }
    x64_mov_r64_imm64(function.code, 0, cast(u64, 24));
    x64_mov_memory_r64(function.code, 4, 600, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 616, 0);

    native_stack_address(function, 576, 1);
    native_stack_address(function, 584, 2);
    native_stack_address(function, 600, 8);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    native_import(function, 23);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize pipe_ready = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 8, 4, 504);
    native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result);
    usize pipe_failure_finished = native_jump(function.code);
    native_skip_end(function.code, pipe_ready);

    x64_mov_r64_memory(function.code, 1, 4, 576);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 1));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    native_import(function, 24);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize inheritance_ready = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 584); native_import(function, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result);
    usize inheritance_failure_finished = native_jump(function.code);
    native_skip_end(function.code, inheritance_ready);

    // STARTUPINFOW (640..743) and PROCESS_INFORMATION (752..775).
    x64_mov_r64_imm64(function.code, 0, cast(u64, 104));
    x64_mov_memory_r64(function.code, 4, 640, 0);
    // dwFlags occupies the high dword of the qword beginning at offset 696.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1099511627776));
    x64_mov_memory_r64(function.code, 4, 696, 0);
    x64_mov_r64_imm64(function.code, 1,
        pe32_u64_minus_eleven() + cast(u64, 1));
    native_import(function, 8);
    x64_mov_memory_r64(function.code, 4, 720, 0);
    x64_mov_r64_memory(function.code, 0, 4, 584);
    x64_mov_memory_r64(function.code, 4, 728, 0);
    x64_mov_memory_r64(function.code, 4, 736, 0);

    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_memory(function.code, 2, 4, 504);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_mov_memory_r64(function.code, 4, 48, 0);
    x64_mov_memory_r64(function.code, 4, 56, 0);
    native_stack_address(function, 640, 0);
    x64_mov_memory_r64(function.code, 4, 64, 0);
    native_stack_address(function, 752, 0);
    x64_mov_memory_r64(function.code, 4, 72, 0);
    native_import(function, 25);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize process_ready = native_skip(function.code, 5);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 584); native_import(function, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result);
    usize process_failure_finished = native_jump(function.code);
    native_skip_end(function.code, process_ready);

    // Only the child keeps the write side. This lets ReadFile observe EOF.
    x64_mov_r64_memory(function.code, 1, 4, 584); native_import(function, 0);
    x64_mov_r64_memory(function.code, 8, 4, 504); native_heap_free_r8(function);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 4096));
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB in process output\n");
    x64_mov_memory_r64(function.code, 4, 800, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 808, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 4096));
    x64_mov_memory_r64(function.code, 4, 816, 0);

    usize read_loop = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 10, 4, 808);
    x64_mov_r64_memory(function.code, 11, 4, 816);
    x64_cmp_r64_r64(function.code, 10, 11);
    usize buffer_has_room = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 67108864));
    x64_cmp_r64_r64(function.code, 11, 0);
    usize buffer_can_grow = native_skip(function.code, 2);

    // At the cap, continue draining into scratch and remember the overflow.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 840, 0);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    native_stack_address(function, 896, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 512));
    native_stack_address(function, 824, 9);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 824, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize drain_finished = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 824);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize drain_empty = native_skip(function.code, 4);
    usize repeat_drain = native_jump(function.code);
    x64_patch_u32(function.code, repeat_drain,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_drain + 4 - read_loop)));

    native_skip_end(function.code, buffer_can_grow);
    x64_mov_r64_memory(function.code, 8, 4, 816);
    x64_add_r64_r64(function.code, 8, 8);
    native_heap_allocate_named_r8(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB growing process output\n");
    x64_mov_memory_r64(function.code, 4, 848, 0);
    x64_mov_r64_r64(function.code, 10, 0);
    x64_mov_r64_memory(function.code, 11, 4, 800);
    x64_mov_r64_memory(function.code, 9, 4, 808);
    native_copy_bytes(function);
    x64_mov_r64_memory(function.code, 8, 4, 800);
    native_heap_free_r8(function);
    x64_mov_r64_memory(function.code, 0, 4, 848);
    x64_mov_memory_r64(function.code, 4, 800, 0);
    x64_mov_r64_memory(function.code, 0, 4, 816);
    x64_add_r64_r64(function.code, 0, 0);
    x64_mov_memory_r64(function.code, 4, 816, 0);

    native_skip_end(function.code, buffer_has_room);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    x64_mov_r64_memory(function.code, 2, 4, 800);
    x64_mov_r64_memory(function.code, 10, 4, 808);
    x64_add_r64_r64(function.code, 2, 10);
    x64_mov_r64_memory(function.code, 8, 4, 816);
    x64_binary_r64_r64(function.code, 41, 8, 10);
    native_stack_address(function, 824, 9);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 824, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    native_import(function, 12);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize read_finished = native_skip(function.code, 4);
    x64_mov_r64_memory(function.code, 0, 4, 824);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize read_empty = native_skip(function.code, 4);
    x64_add_r64_memory(function.code, 0, 4, 808);
    x64_mov_memory_r64(function.code, 4, 808, 0);
    usize repeat_read = native_jump(function.code);
    x64_patch_u32(function.code, repeat_read,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_read + 4 - read_loop)));

    native_skip_end(function.code, drain_finished);
    native_skip_end(function.code, drain_empty);
    native_skip_end(function.code, read_finished);
    native_skip_end(function.code, read_empty);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 4294967295));
    native_import(function, 26);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    native_stack_address(function, 832, 2);
    native_import(function, 27);
    x64_mov_r64_memory(function.code, 1, 4, 760); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 752); native_import(function, 0);

    x64_mov_r64_memory(function.code, 0, 4, 840);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize output_within_budget = native_skip(function.code, 4);
    native_constant_ascii(function,
        "fatal[OPENC-NATIVE-PROCESS-OUTPUT-BUDGET]: child output exceeds 64 MiB\n",
        false, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 73));
    native_write_console(function, true);
    x64_mov_r64_memory(function.code, 8, 4, 800);
    native_heap_free_r8(function);
    native_process_failure_outputs(context, function, instruction, result);
    usize output_failure_finished = native_jump(function.code);

    native_skip_end(function.code, output_within_budget);
    usize exit_value = d_operand_value(context, instruction, 1);
    native_value_address(context, function, exit_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 832);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    usize output_value = d_operand_value(context, instruction, 2);
    native_value_address(context, function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 4, 800);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    x64_mov_r64_memory(function.code, 0, 4, 808);
    x64_mov_memory_r64(function.code, 11, 8, 0);
    native_status_success(function, result);

    native_skip_end(function.code, pipe_failure_finished);
    native_skip_end(function.code, inheritance_failure_finished);
    native_skip_end(function.code, process_failure_finished);
    native_skip_end(function.code, output_failure_finished);
}

unsafe bool native_runtime_call(ref IrContext context, ref NativeFunction function,
    usize instruction) {
    usize result = read_record_field(context.instruction_data, instruction, 1);
    if c_builtin_is(context, instruction, "memory.alloc", "system.memory.alloc") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        DBuffer allocation_message = d_buffer_create(512);
        d_put(allocation_message,
            "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocations exceed 512 MiB at memory.alloc in ");
        d_put_symbol_name(context, allocation_message, context.function_symbol);
        d_put(allocation_message, "\n");
        native_heap_allocate_named_r8(function, d_buffer_text(allocation_message));
        d_buffer_destroy(allocation_message);
        native_store(function, result, 0); return true;
    }
    if c_builtin_is(context, instruction, "memory.free", "system.memory.free") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        native_heap_free_r8(function); return true;
    }
    if c_builtin_is(context, instruction, "text.trim", "system.text.trim") {
        native_text_trim(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if c_builtin_is(context, instruction, "text.length", "system.text.length") {
        native_text_scalar_length(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if c_builtin_is(context, instruction, "memory.load_usize", "system.memory.load_usize") {
        native_load(function, d_operand_value(context, instruction, 0), 11);
        x64_mov_r64_memory(function.code, 0, 11, 0); native_store(function, result, 0);
        return true;
    }
    if c_builtin_is(context, instruction, "memory.store_usize", "system.memory.store_usize") {
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if c_builtin_is(context, instruction, "text.byte_at_unchecked", "system.text.byte_at_unchecked") {
        usize value = d_operand_value(context, instruction, 0);
        native_load(function, value, 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
        native_store(function, result, 0); return true;
    }
    if c_builtin_is(context, instruction, "text.copy_utf8_unchecked",
        "system.text.copy_utf8_unchecked") {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        usize value = d_operand_value(context, instruction, 1);
        native_load(function, value, 11);
        x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
        native_copy_bytes(function); return true;
    }
    if c_builtin_is(context, instruction, "text.copy_utf8_slice_unchecked",
        "system.text.copy_utf8_slice_unchecked") {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        usize value = d_operand_value(context, instruction, 1);
        native_load(function, value, 11);
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_add_r64_r64(function.code, 11, 0);
        native_load(function, d_operand_value(context, instruction, 3), 9);
        native_copy_bytes(function); return true;
    }
    if c_builtin_is(context, instruction, "text.from_utf8", "system.text.from_utf8") {
        native_load(function, d_operand_value(context, instruction, 0), 0);
        native_store(function, result, 0);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
        return true;
    }
    if c_builtin_is(context, instruction, "text.equal", "system.text.equal") {
        native_text_equal(function, d_operand_value(context, instruction, 0),
            d_operand_value(context, instruction, 1));
        native_store(function, result, 0); return true;
    }
    if c_builtin_is(context, instruction, "text.slice", "system.text.slice") {
        if d_operand_count(context, instruction) != 4 { function.code.ok = false; return true; }
        native_text_scalar_slice(context, function, instruction, result); return true;
    }
    if c_builtin_is(context, instruction, "process.run", "system.process.run") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if c_builtin_is(context, instruction, "path.join", "system.path.join") {
        native_path_join(function, d_operand_value(context, instruction, 0),
        d_operand_value(context, instruction, 1), result); return true;
    }
    if c_builtin_is(context, instruction, "path.directory", "system.path.directory") {
        native_path_directory(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if c_builtin_is(context, instruction, "process.monotonic_milliseconds",
        "system.process.monotonic_milliseconds") {
        native_import(function, 16); native_store(function, result, 0); return true;
    }
    if c_builtin_is(context, instruction, "process.argument_count",
        "system.process.argument_count") {
        native_process_argument_count(function, result); return true;
    }
    if c_builtin_is(context, instruction, "process.argument", "system.process.argument") {
        native_process_argument(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if c_builtin_is(context, instruction, "process.executable_directory",
        "system.process.executable_directory") {
        native_process_executable_directory(function, result); return true;
    }
    if c_builtin_is(context, instruction, "lsp_read_frame", "ocb_lsp_read_frame") {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_lsp_read_frame(context, function, instruction, result);
        return true;
    }
    if c_builtin_is(context, instruction, "file.read_text_cached", "system.file.read_text_cached") {
        native_file_read_cached(context, function, instruction, result); return true;
    }
    if c_builtin_is(context, instruction, "file.read_text", "system.file.read_text") ||
        c_builtin_is(context, instruction, "file.read_bytes", "system.file.read_bytes") {
        native_file_read(context, function, instruction, result, false); return true;
    }
    if c_builtin_is(context, instruction, "file.read_bytes_raw", "system.file.read_bytes_raw") {
        native_file_read(context, function, instruction, result, true); return true;
    }
    if c_builtin_is(context, instruction, "file.write_text", "system.file.write_text") {
        if d_operand_count(context, instruction) != 2 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, false); return true;
    }
    if c_builtin_is(context, instruction, "file.write_bytes", "system.file.write_bytes") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, true); return true;
    }
    bool println = c_builtin_is(context, instruction, "io.println", "system.io.println");
    bool print = c_builtin_is(context, instruction, "io.print", "system.io.print");
    bool error_stream = c_builtin_is(context, instruction, "io.error", "system.io.error");
    if println || print || error_stream {
        usize value = d_operand_value(context, instruction, 0);
        usize type_id = native_value_read(function, function.value_types, value);
        if c_type_is_text(context, type_id) {
            native_load(function, value, 2);
            x64_mov_r64_memory(function.code, 8, 4, native_slot(function, value) + 8);
            native_write_console(function, error_stream);
        } else {
            usize kind = read_record_field(context.type_data, type_id, 0);
            if error_stream || (kind != 2 && kind != 3 && kind != 5 && kind != 6) {
                function.code.ok = false; return true;
            }
            native_load(function, value, 0);
            if kind == 5 { native_write_bool(function); }
            else { native_write_integer(function, kind == 2); }
        }
        if println {
            x64_mov_r64_imm64(function.code, 0, cast(u64, 10));
            x64_mov_memory_r64(function.code, 4, 192, 0);
            x64_emit_rex(function.code, true, 2, 0, 4); x64_emit_u8(function.code, 141);
            x64_emit_memory_modrm(function.code, 2, 4, 192);
            x64_mov_r64_imm64(function.code, 8, cast(u64, 1));
            native_write_console(function, error_stream);
        }
        return true;
    }
    return false;
}
