import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe void native_process_supervise(ref NativeFunction function) {
    usize read_loop = function.code.bytes.length;

    // An exited process can no longer exceed a resource limit, and some Windows
    // versions no longer expose meaningful live counters after it is signaled.
    // Mark it first, skip supervision, then drain any bytes still in the pipe.
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    native_import(function, 26);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize supervise_running_process = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 888, 0);
    usize skip_process_supervision = native_jump(function.code);
    native_skip_end(function.code, supervise_running_process);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 258));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 4);

    // Enforce the unprivileged 64 MiB working-set rule by observing the child
    // directly; JOB_OBJECT_LIMIT_WORKINGSET requires a quota privilege and is
    // not available to ordinary compiler processes.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 80));
    x64_mov_memory_r64(function.code, 4, 1040, 0);
    x64_mov_r64_memory(function.code, 11, 4, 864);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    native_stack_address(function, 1040, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 80));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    x64_mov_r64_memory(function.code, 10, 4, 1056);
    x64_mov_r64_memory(function.code, 9, 4, 1144);
    x64_cmp_r64_r64(function.code, 10, 9);
    usize working_set_not_peak = native_skip(function.code, 6);
    x64_mov_memory_r64(function.code, 4, 1144, 10);
    native_skip_end(function.code, working_set_not_peak);
    x64_mov_r64_memory(function.code, 10, 4, 1112);
    x64_mov_r64_memory(function.code, 9, 4, 1408);
    x64_cmp_r64_r64(function.code, 10, 9);
    usize private_not_peak = native_skip(function.code, 6);
    x64_mov_memory_r64(function.code, 4, 1408, 10);
    native_skip_end(function.code, private_not_peak);
    x64_mov_r64_memory(function.code, 10, 4, 1056);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 67108864));
    x64_cmp_r64_r64(function.code, 10, 11);
    usize working_set_within_budget = native_skip(function.code, 6);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 1120, 0);
    x64_mov_r64_memory(function.code, 11, 4, 872);
    x64_mov_r64_memory(function.code, 1, 4, 784);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 70));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    native_skip_end(function.code, working_set_within_budget);

    native_import(function, 16);
    x64_mov_r64_memory(function.code, 11, 4, 1136);
    x64_binary_r64_r64(function.code, 41, 0, 11);
    x64_mov_r64_memory(function.code, 11, 4, 880);
    x64_cmp_r64_r64(function.code, 0, 11);
    usize time_within_budget = native_skip(function.code, 2);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 1128, 0);
    x64_mov_r64_memory(function.code, 11, 4, 872);
    x64_mov_r64_memory(function.code, 1, 4, 784);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 70));
    x64_call_r64(function.code, 11); native_runtime_nonzero(function);
    native_skip_end(function.code, time_within_budget);
    native_skip_end(function.code, skip_process_supervision);

    // Peek before every synchronous read, then wait at most 25 ms for process
    // progress. This keeps output capture responsive to RAM and timeout rules.
    x64_mov_r64_memory(function.code, 11, 4, 856);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 9, cast(u64, 0));
    native_stack_address(function, 824, 0);
    x64_mov_memory_r64(function.code, 4, 32, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 40, 0);
    x64_call_r64(function.code, 11);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize peek_ready = native_skip(function.code, 5);
    usize peek_finished = native_jump(function.code);
    native_skip_end(function.code, peek_ready);
    x64_mov_r64_memory(function.code, 0, 4, 824);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize data_ready = native_skip(function.code, 5);

    x64_mov_r64_memory(function.code, 0, 4, 888);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize wait_needed = native_skip(function.code, 4);
    usize signaled_finished = native_jump(function.code);
    native_skip_end(function.code, wait_needed);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 25));
    native_import(function, 26);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize process_still_running = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 888, 0);
    usize repeat_after_signal = native_jump(function.code);
    native_skip_end(function.code, process_still_running);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 258));
    x64_cmp_r64_r64(function.code, 0, 11); native_require(function.code, 4);
    usize repeat_after_wait = native_jump(function.code);
    x64_patch_u32(function.code, repeat_after_signal,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_after_signal + 4 - read_loop)));
    x64_patch_u32(function.code, repeat_after_wait,
        cast(u32, cast(u64, 4294967296) -
            cast(u64, repeat_after_wait + 4 - read_loop)));
    native_skip_end(function.code, data_ready);

    x64_mov_r64_memory(function.code, 10, 4, 808);
    x64_mov_r64_memory(function.code, 11, 4, 816);
    x64_cmp_r64_r64(function.code, 10, 11);
    usize buffer_has_room = native_skip(function.code, 5);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 4194304));
    x64_cmp_r64_r64(function.code, 11, 0);
    usize buffer_can_grow = native_skip(function.code, 2);

    // At the cap, continue draining into scratch and remember the overflow.
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    x64_mov_memory_r64(function.code, 4, 840, 0);
    x64_mov_r64_memory(function.code, 1, 4, 576);
    native_stack_address(function, 1152, 2);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 256));
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
    native_skip_end(function.code, peek_finished);
    native_skip_end(function.code, signaled_finished);
    x64_mov_r64_memory(function.code, 1, 4, 576); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 4294967295));
    native_import(function, 26);
    x64_mov_r64_memory(function.code, 1, 4, 752);
    native_stack_address(function, 832, 2);
    native_import(function, 27);
    x64_mov_r64_memory(function.code, 1, 4, 760); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 752); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 784); native_import(function, 0);
    x64_mov_r64_memory(function.code, 1, 4, 776); native_import(function, 22);
}
