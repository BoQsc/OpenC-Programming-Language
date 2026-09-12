import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
        native_output_address(function, data_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 536); x64_mov_memory_r64(function.code, 11, 0, 0);
        usize length_value = d_operand_value(context, instruction, 2);
        native_output_address(function, length_value, 11);
        x64_mov_r64_memory(function.code, 0, 4, 528); x64_mov_memory_r64(function.code, 11, 0, 0);
    } else {
        usize output_value = d_operand_value(context, instruction, 1);
        native_output_address(function, output_value, 11);
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
    native_output_address(function, output_value, 11);
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
    native_output_address(function, output_value, 11);
    x64_mov_r64_memory(function.code, 0, 11, 0); x64_mov_memory_r64(function.code, 10, 24, 0);
    x64_mov_r64_memory(function.code, 0, 11, 8); x64_mov_memory_r64(function.code, 10, 32, 0);
    native_skip_end(function.code, read_failed); native_skip_end(function.code, finished);
}
