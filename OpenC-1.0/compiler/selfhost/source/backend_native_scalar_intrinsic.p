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

unsafe bool native_compiler_intrinsic(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result) {
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize one = read_record_field(context.instruction_detail, instruction, 1);
    usize two = read_record_field(context.instruction_detail, instruction, 2);
    DCompilerCallSpan call_span = d_compiler_call_span(
        context, kind, one, two
    );
    if native_compiler_span_is(call_span, "c_native_parallel_jobs") {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        usize callback_one = native_compiler_named_function(
            context, "c_native_chunk_thread_entry");
        usize callback_two = native_compiler_named_function(
            context, "c_native_chunk_thread_entry_two");
        usize callback_three = native_compiler_named_function(
            context, "c_native_chunk_thread_entry_three");
        usize callback_four = native_compiler_named_function(
            context, "c_native_chunk_thread_entry_four");
        if callback_one == context.symbols.length ||
            callback_two == context.symbols.length ||
            callback_three == context.symbols.length ||
            callback_four == context.symbols.length {
            function.code.ok = false; return true;
        }
        usize argument = d_operand_value(context, instruction, 0);
        native_load(function, argument, 0);
        x64_mov_memory_r64(function.code, 4, 1424, 0);
        native_windows_dynamic_prepare(function, "kernel32.dll", "CreateThread");
        usize available = native_windows_dynamic_available(function);
        x64_mov_r64_memory(function.code, 1, 4, 600);
        x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
        x64_emit_u8(function.code, 201);
        usize missing_module = native_skip(function.code, 4);
        native_windows_dynamic_close(function);
        native_skip_end(function.code, missing_module);
        x64_mov_r64_imm64(function.code, 0, cast(u64, 3));
        native_store(function, result, 0);
        usize unavailable_done = native_jump(function.code);
        native_skip_end(function.code, available);

        x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
        x64_mov_memory_r64(function.code, 4, 1464, 0);
        usize worker = 0;
        while worker < 3 {
            usize callback = callback_one;
            if worker == 1 { callback = callback_two; }
            if worker == 2 { callback = callback_three; }
            x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
            x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
            native_symbol_address(function, callback, 8);
            x64_mov_r64_memory(function.code, 9, 4, 1424);
            x64_mov_r64_imm64(function.code, 0, cast(u64, 0));
            x64_mov_memory_r64(function.code, 4, 32, 0);
            x64_mov_memory_r64(function.code, 4, 40, 0);
            x64_mov_r64_memory(function.code, 11, 4, 608);
            x64_call_r64(function.code, 11);
            x64_mov_memory_r64(function.code, 4, 1440 + worker * 8, 0);
            x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 192);
            usize created = native_skip(function.code, 5);
            x64_mov_r64_imm64(function.code, 0, cast(u64, 3));
            x64_mov_memory_r64(function.code, 4, 1464, 0);
            native_skip_end(function.code, created);
            worker = worker + 1;
        }

        x64_mov_r64_memory(function.code, 1, 4, 1424);
        x64_call_symbol(function.code, callback_four, 0);
        worker = 0;
        while worker < 3 {
            x64_mov_r64_memory(function.code, 1, 4, 1440 + worker * 8);
            x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
            x64_emit_u8(function.code, 201);
            usize missing = native_skip(function.code, 4);
            x64_mov_r64_imm64(function.code, 2, cast(u64, 4294967295));
            native_import(function, 26);
            x64_mov_r64_imm64(function.code, 11, cast(u64, 0));
            x64_cmp_r64_r64(function.code, 0, 11);
            native_require(function.code, 4);
            x64_mov_r64_memory(function.code, 1, 4, 1440 + worker * 8);
            native_import(function, 0); native_runtime_nonzero(function);
            native_skip_end(function.code, missing);
            worker = worker + 1;
        }
        native_windows_dynamic_close(function);
        x64_mov_r64_memory(function.code, 0, 4, 1464);
        native_store(function, result, 0);
        native_skip_end(function.code, unavailable_done);
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
