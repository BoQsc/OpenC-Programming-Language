import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe usize native_compiler_named_function(ref IrContext context,
    text name) {
    usize symbol = 0;
    while symbol < context.symbols.length {
        if read_record_field(context.symbol_data, symbol, 0) ==
                resolution_symbol_function() &&
            d_symbol_name_is(context, symbol, name) {
            return symbol;
        }
        symbol = symbol + 1;
    }
    return context.symbols.length;
}

// All work objects are created before any submission. A setup failure closes
// unsubmitted objects and returns 3 for the existing serial fallback. After
// submission, every callback is joined before its state can be released.
usize native_compiler_work_handle_slot(usize worker) {
    if worker == 3 { return 1504; }
    return 1440 + worker * 8;
}

unsafe void native_compiler_pool_work(
    ref IrContext context, ref NativeFunction function,
    usize instruction, usize result,
    usize callback_one, usize callback_two, usize callback_three,
    usize callback_four, bool two_workers, bool cold_cache
) {
    usize workers = 3;
    if two_workers { workers = 1; }
    if cold_cache { workers = workers + 1; }
    if d_symbol_name_is(context, callback_one, "native_object_cache_publish_pool") { workers = 2; }
    usize caller = callback_four;
    if two_workers {
        text name = "c_native_chunk_thread_entry_two";
        if d_symbol_name_is(context, callback_one, "flow_parallel_pool_one") {
            name = "flow_parallel_thread_entry_two";
        }
        if d_symbol_name_is(context, callback_one, "native_object_cache_publish_pool") {
            name = "native_object_cache_link_main";
        }
        caller = native_compiler_named_function(context, name);
        if caller >= context.symbols.length { function.code.ok = false; return; }
    }
    ptr byte failures = memory.alloc(8 * size_of(usize));
    scope memory.free(failures);
    usize failure_count = 0;
    native_load(function, d_operand_value(context, instruction, 0), 0);
    x64_mov_memory_r64(function.code, 4, 1424, 0);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    usize worker = 0;
    while worker < workers {
        x64_mov_memory_r64(function.code, 4, native_compiler_work_handle_slot(worker), 0);
        worker = worker + 1;
    }
    x64_mov_r64_imm64(function.code, 0, cast(u64, 3));
    x64_mov_memory_r64(function.code, 4, 1464, 0);
    native_windows_dynamic_prepare(function, "kernel32.dll", "CreateThreadpoolWork");
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_memory_r64(function.code, 4, 1472, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    write_usize(failures, failure_count * 8, native_skip(function.code, 4));
    failure_count = failure_count + 1;
    usize api_index = 0;
    while api_index < 3 {
        text name = "SubmitThreadpoolWork";
        if api_index == 1 { name = "WaitForThreadpoolWorkCallbacks"; }
        if api_index == 2 { name = "CloseThreadpoolWork"; }
        x64_mov_r64_memory(function.code, 1, 4, 600);
        native_constant_ascii(function, name, false, 2);
        native_import(function, 20);
        x64_mov_memory_r64(function.code, 4, 1480 + api_index * 8, 0);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 192);
        write_usize(failures, failure_count * 8, native_skip(function.code, 4));
        failure_count = failure_count + 1;
        api_index = api_index + 1;
    }
    worker = 0;
    while worker < workers {
        usize callback = callback_one;
        if worker == 1 { callback = callback_two; }
        if worker == 2 { callback = callback_three; }
        if cold_cache && worker + 1 == workers {
            callback = native_compiler_named_function(context, "c_native_cache_pool");
            if callback >= context.symbols.length { function.code.ok = false; return; }
        }
        native_symbol_address(function, callback, 1);
        x64_mov_r64_memory(function.code, 2, 4, 1424);
        x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
        x64_mov_r64_memory(function.code, 11, 4, 1472);
        x64_call_r64(function.code, 11);
        x64_mov_memory_r64(function.code, 4, native_compiler_work_handle_slot(worker), 0);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 192);
        write_usize(failures, failure_count * 8, native_skip(function.code, 4));
        failure_count = failure_count + 1;
        worker = worker + 1;
    }
    worker = 0;
    while worker < workers {
        x64_mov_r64_memory(function.code, 1, 4, native_compiler_work_handle_slot(worker));
        x64_mov_r64_memory(function.code, 11, 4, 1480);
        x64_call_r64(function.code, 11);
        worker = worker + 1;
    }
    x64_mov_r64_memory(function.code, 1, 4, 1424);
    x64_call_symbol(function.code, caller, 0);
    worker = 0;
    while worker < workers {
        x64_mov_r64_memory(function.code, 1, 4, native_compiler_work_handle_slot(worker));
        x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
        x64_mov_r64_memory(function.code, 11, 4, 1488);
        x64_call_r64(function.code, 11);
        worker = worker + 1;
    }
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, 1464, 0);
    usize failure = 0;
    while failure < failure_count {
        native_skip_end(function.code, read_usize(failures, failure * 8));
        failure = failure + 1;
    }
    worker = 0;
    while worker < workers {
        x64_mov_r64_memory(function.code, 1, 4, native_compiler_work_handle_slot(worker));
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 201);
        usize absent = native_skip(function.code, 4);
        x64_mov_r64_memory(function.code, 11, 4, 1496);
        x64_call_r64(function.code, 11);
        native_skip_end(function.code, absent);
        worker = worker + 1;
    }
    x64_mov_r64_memory(function.code, 1, 4, 600);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 201);
    usize missing_module = native_skip(function.code, 4);
    native_windows_dynamic_close(function);
    native_skip_end(function.code, missing_module);
    x64_mov_r64_memory(function.code, 0, 4, 1464);
    native_store(function, result, 0);
}

// Start one owned identity callback without joining it at the launch site.
// All four APIs resolve before a work object can be created. The caller owns
// the state and 24-byte record until the separate mandatory join completes.
unsafe void native_frontend_identity_intrinsic(
    ref IrContext context, ref NativeFunction function,
    usize instruction, usize result, bool starting
) {
    if !starting {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        x64_mov_memory_r64(function.code, 4, 1424, 10);
        x64_mov_r64_memory(function.code, 1, 10, 0);
        x64_mov_memory_r64(function.code, 4, 1440, 1);
        x64_mov_r64_memory(function.code, 11, 10, 8);
        x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
        x64_call_r64(function.code, 11);
        x64_mov_r64_memory(function.code, 10, 4, 1424);
        x64_mov_r64_memory(function.code, 1, 4, 1440);
        x64_mov_r64_memory(function.code, 11, 10, 16);
        x64_call_r64(function.code, 11);
        x64_mov_r64_memory(function.code, 10, 4, 1424);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        x64_mov_memory_r64(function.code, 10, 0, 0);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
        native_store(function, result, 0);
        return;
    }
    usize callback = native_compiler_named_function(context, "native_frontend_identity_pool");
    if callback >= context.symbols.length { function.code.ok = false; return; }
    ptr byte failures = memory.alloc(5 * size_of(usize));
    scope memory.free(failures);
    if failures == null { function.code.ok = false; return; }
    usize count = 0;
    x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
    native_store(function, result, 0);
    native_load(function, d_operand_value(context, instruction, 0), 0);
    x64_mov_memory_r64(function.code, 4, 1424, 0);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_memory_r64(function.code, 4, 1432, 0);
    native_windows_dynamic_prepare(function, "kernel32.dll", "CreateThreadpoolWork");
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_mov_memory_r64(function.code, 4, 1472, 0);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    write_usize(failures, count * 8, native_skip(function.code, 4)); count = count + 1;
    usize api = 0;
    while api < 3 {
        text name = "SubmitThreadpoolWork";
        if api == 1 { name = "WaitForThreadpoolWorkCallbacks"; }
        if api == 2 { name = "CloseThreadpoolWork"; }
        x64_mov_r64_memory(function.code, 1, 4, 600);
        native_constant_ascii(function, name, false, 2);
        native_import(function, 20);
        x64_mov_memory_r64(function.code, 4, 1480 + api * 8, 0);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
        write_usize(failures, count * 8, native_skip(function.code, 4)); count = count + 1;
        api = api + 1;
    }
    native_symbol_address(function, callback, 1);
    x64_mov_r64_memory(function.code, 2, 4, 1424);
    x64_mov_r64_imm64(function.code, 8, cast(u64, 0));
    x64_mov_r64_memory(function.code, 11, 4, 1472);
    x64_call_r64(function.code, 11);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    write_usize(failures, count * 8, native_skip(function.code, 4)); count = count + 1;
    x64_mov_r64_memory(function.code, 10, 4, 1432);
    x64_mov_memory_r64(function.code, 10, 0, 0);
    x64_mov_r64_memory(function.code, 11, 4, 1488);
    x64_mov_memory_r64(function.code, 10, 8, 11);
    x64_mov_r64_memory(function.code, 11, 4, 1496);
    x64_mov_memory_r64(function.code, 10, 16, 11);
    x64_mov_r64_r64(function.code, 1, 0);
    x64_mov_r64_memory(function.code, 11, 4, 1480);
    x64_call_r64(function.code, 11);
    x64_mov_r64_imm64(function.code, 0, cast(u64, 1));
    native_store(function, result, 0);
    usize failure = 0;
    while failure < count {
        native_skip_end(function.code, read_usize(failures, failure * 8));
        failure = failure + 1;
    }
    native_windows_dynamic_close(function);
}

unsafe bool native_compiler_intrinsic(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result) {
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize one = read_record_field(context.instruction_detail, instruction, 1);
    usize two = read_record_field(context.instruction_detail, instruction, 2);
    DCompilerCallSpan call_span = d_compiler_call_span(
        context, kind, one, two
    );
    bool identity_start = native_compiler_span_is(call_span, "native_frontend_start_identity");
    bool identity_join = native_compiler_span_is(call_span, "native_frontend_join_identity");
    if identity_start || identity_join {
        usize arguments = 1;
        if identity_start { arguments = 2; }
        if d_operand_count(context, instruction) != arguments { function.code.ok = false; return true; }
        native_frontend_identity_intrinsic(context, function, instruction, result, identity_start);
        return true;
    }
    bool flow_workers = native_compiler_span_is(
        call_span, "flow_parallel_jobs_two"
    ) || native_compiler_span_is(call_span, "flow_parallel_jobs");
    bool parse_workers = native_compiler_span_is(
        call_span, "resolution_parse_parallel_jobs"
    );
    bool cache_publication = native_compiler_span_is(
        call_span, "native_object_cache_publish_link_jobs");
    bool two_workers = native_compiler_span_is(
        call_span, "c_native_parallel_jobs_two"
    ) || native_compiler_span_is(call_span, "flow_parallel_jobs_two") || cache_publication ||
        native_compiler_span_is(call_span, "c_native_parallel_jobs_two_cold");
    bool cold_cache = native_compiler_span_is(call_span, "c_native_parallel_jobs_cold") ||
        native_compiler_span_is(call_span, "c_native_parallel_jobs_two_cold");
    if two_workers || flow_workers || parse_workers || cold_cache || native_compiler_span_is(
        call_span, "c_native_parallel_jobs"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        text name_one = "c_native_pool_one";
        text name_two = "c_native_pool_two";
        text name_three = "c_native_pool_three";
        text name_four = "c_native_chunk_thread_entry_four";
        if flow_workers {
            name_one = "flow_parallel_pool_one";
            name_two = "flow_parallel_pool_two";
            name_three = "flow_parallel_pool_three";
            name_four = "flow_parallel_thread_entry_four";
        }
        if parse_workers {
            name_one = "resolution_parse_pool_one";
            name_two = "resolution_parse_pool_two";
            name_three = "resolution_parse_pool_three";
            name_four = "resolution_parse_thread_entry_four";
        }
        if cache_publication {
            name_one = "native_object_cache_publish_pool";
            name_two = "native_object_cache_frontend_pool"; name_three = name_one;
            name_four = "native_object_cache_link_main";
        }
        usize callback_one = native_compiler_named_function(context, name_one);
        usize callback_two = native_compiler_named_function(context, name_two);
        usize callback_three = native_compiler_named_function(context, name_three);
        usize callback_four = native_compiler_named_function(context, name_four);
        if callback_one == context.symbols.length ||
            callback_two == context.symbols.length ||
            callback_three == context.symbols.length ||
            callback_four == context.symbols.length {
            function.code.ok = false; return true;
        }
        native_compiler_pool_work(context, function, instruction, result,
            callback_one, callback_two, callback_three, callback_four,
            two_workers, cold_cache);
        return true;
    }
    if native_compiler_span_is(
        call_span, "compiler_live_allocation_bytes"
    ) {
        if d_operand_count(context, instruction) != 0 {
            function.code.ok = false; return true;
        }
        native_data_address(function, 32, 11);
        x64_mov_r64_memory(function.code, 0, 11, 0);
        native_store(function, result, 0); return true;
    }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_file_cache_hits", 56) { return true; }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_file_cache_misses", 64) { return true; }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_path_cache_hits", 72) { return true; }
    if native_compiler_counter_call(context, call_span, function, instruction, result,
        "compiler_path_cache_misses", 80) { return true; }
    if d_operand_count(context, instruction) == 0 {
        NativeCompilerConstant constant = native_compiler_constant_call(
            context, kind, one
        );
        if constant.found {
            x64_mov_r64_imm64(function.code, 0, cast(u64, constant.value));
            native_store(function, result, 0); return true;
        }
    }
    if native_compiler_span_is(call_span, "project_slice") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_compiler_project_slice(
            context, function, instruction, result);
        return true;
    }
    if native_compiler_span_is(call_span, "starts_with_ascii") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_compiler_text_match(
            context, function, instruction, result, false);
        return true;
    }
    if native_compiler_span_is(call_span, "span_equals_ascii") {
        if d_operand_count(context, instruction) != 4 {
            function.code.ok = false; return true;
        }
        native_compiler_text_match(
            context, function, instruction, result, true);
        return true;
    }
    if native_compiler_span_is(call_span, "record_stride") {
        x64_mov_r64_imm64(function.code, 0, cast(u64, 40));
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "native_read_u32") {
        if d_operand_count(context, instruction) != 2 || result == 0 {
            function.code.ok = false; return true;
        }
        // The private DBuffer is {data,length,capacity,ok}. Preserve the
        // byte-reader's range checks and failure flag, then use x64's exact
        // four-byte unaligned load. The portable source remains the oracle.
        native_value_address(context, function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_r64_memory(function.code, 8, 11, 8);
        x64_cmp_r64_r64(function.code, 0, 8);
        usize bad_offset = native_skip(function.code, 7);
        x64_binary_r64_r64(function.code, 41, 8, 0);
        x64_alu_r64_imm8(function.code, 7, 8, 4);
        usize bad_length = native_skip(function.code, 2);
        x64_mov_r64_memory(function.code, 10, 11, 0);
        x64_add_r64_r64(function.code, 10, 0);
        x64_emit_rex(function.code, false, 0, 0, 10);
        x64_emit_u8(function.code, 139);
        x64_emit_memory_modrm(function.code, 0, 10, 0);
        usize complete = native_jump(function.code);
        native_skip_end(function.code, bad_offset);
        native_skip_end(function.code, bad_length);
        x64_emit_rex(function.code, false, 0, 0, 11);
        x64_emit_u8(function.code, 198);
        x64_emit_memory_modrm(function.code, 0, 11, 24);
        x64_emit_u8(function.code, 0);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        native_skip_end(function.code, complete);
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "read_usize") {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        x64_mov_r64_memory(function.code, 0, 11, 0);
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "write_usize") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if native_compiler_span_is(call_span, "read_record_field") {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_compiler_record_address(context, function, instruction);
        x64_mov_r64_memory(function.code, 0, 11, 0);
        native_store(function, result, 0); return true;
    }
    if native_compiler_span_is(call_span, "write_record_field") {
        if d_operand_count(context, instruction) != 4 {
            function.code.ok = false; return true;
        }
        native_compiler_record_address(context, function, instruction);
        native_load(function, d_operand_value(context, instruction, 3), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if native_compiler_span_is(call_span, "byte_at_or_zero") {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        usize value = d_operand_value(context, instruction, 0);
        native_load(function, value, 11);
        x64_mov_r64_memory(function.code, 10, 4,
            native_slot(function, value) + 8);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_cmp_r64_r64(function.code, 0, 10);
        usize in_range = native_skip(function.code, 2);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        usize done = native_jump(function.code);
        native_skip_end(function.code, in_range);
        x64_add_r64_r64(function.code, 11, 0);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
        native_skip_end(function.code, done);
        native_store(function, result, 0); return true;
    }
    return false;
}
