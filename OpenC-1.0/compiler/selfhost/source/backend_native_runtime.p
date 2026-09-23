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
    // LOCK INC qword ptr [r11]: worker diagnostics may update these counters.
    x64_emit_u8(function.code, 240);
    x64_emit_rex(function.code, true, 0, 0, 11);
    x64_emit_u8(function.code, 255);
    x64_emit_memory_modrm(function.code, 0, 11, 0);
}

unsafe void native_atomic_compare_exchange_r10_r11(ref NativeFunction function) {
    // LOCK CMPXCHG qword ptr [r10], r11. RAX holds the expected old value;
    // on contention it receives the observed value for the retry loop.
    x64_emit_u8(function.code, 240);
    x64_emit_rex(function.code, true, 11, 0, 10);
    x64_emit_u8(function.code, 15);
    x64_emit_u8(function.code, 177);
    x64_emit_memory_modrm(function.code, 11, 10, 0);
}

unsafe void native_atomic_retry(ref NativeFunction function, usize loop_start) {
    usize retry = native_skip(function.code, 5);
    x64_patch_u32(function.code, retry,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, retry + 4 - loop_start)));
}

unsafe void native_runtime_nonzero(ref NativeFunction function) {
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192); native_require(function.code, 5);
}

unsafe void native_heap_allocate_named_r8(ref NativeFunction function, text live_message) {
    native_allocation_budget(function, 8);
    x64_mov_memory_r64(function.code, 4, 456, 8);
    native_data_address(function, 32, 10);
    usize reservation_start = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_mov_r64_r64(function.code, 11, 0);
    x64_add_r64_r64(function.code, 11, 8);
    x64_cmp_r64_r64(function.code, 11, 0);
    usize no_overflow = native_skip(function.code, 3);
    native_allocation_fatal(function,
        "fatal[OPENC-NATIVE-ALLOC-BUDGET]: live allocation byte counter overflow\n");
    native_skip_end(function.code, no_overflow);
    x64_mov_r64_imm64(function.code, 9, cast(u64, 536870912));
    x64_cmp_r64_r64(function.code, 11, 9);
    usize within_live_budget = native_skip(function.code, 6);
    native_allocation_fatal(function, live_message);
    native_skip_end(function.code, within_live_budget);
    native_atomic_compare_exchange_r10_r11(function);
    native_atomic_retry(function, reservation_start);
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
    usize release_start = function.code.bytes.length;
    x64_mov_r64_memory(function.code, 0, 10, 0);
    x64_cmp_r64_r64(function.code, 11, 0); native_require(function.code, 6);
    x64_mov_r64_r64(function.code, 9, 0);
    x64_binary_r64_r64(function.code, 41, 9, 11);
    // The desired value is in R9; CMPXCHG consumes R11, so preserve the
    // allocation size in the existing frame slot across CAS retries.
    x64_mov_memory_r64(function.code, 4, 464, 11);
    x64_mov_r64_r64(function.code, 11, 9);
    native_atomic_compare_exchange_r10_r11(function);
    x64_mov_r64_memory(function.code, 11, 4, 464);
    native_atomic_retry(function, release_start);
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
