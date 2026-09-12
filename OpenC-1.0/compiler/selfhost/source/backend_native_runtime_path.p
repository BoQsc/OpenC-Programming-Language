import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
