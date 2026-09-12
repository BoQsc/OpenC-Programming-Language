import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool native_compiler_intrinsic(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result) {
    usize kind = read_record_field(context.instruction_detail, instruction, 0);
    usize one = read_record_field(context.instruction_detail, instruction, 1);
    usize two = read_record_field(context.instruction_detail, instruction, 2);
    DCompilerCallSpan call_span = d_compiler_call_span(
        context, kind, one, two
    );
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
