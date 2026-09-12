import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe NativeCompilerConstant native_compiler_constant_call(
    ref IrContext context, usize kind, usize symbol
) {
    usize value = 0;
    if kind != 3 || symbol >= context.symbols.length ||
        !d_symbol_module_name_is(
            context, symbol, "openc.selfhost.main"
        ) { return NativeCompilerConstant{ found = false, value = 0 }; }
    text source = d_symbol_source(context, symbol);
    usize cursor = read_record_field(context.symbol_data, symbol, 2) +
        read_record_field(context.symbol_data, symbol, 3);
    if !starts_with_ascii(source, cursor, "() { return ") {
        return NativeCompilerConstant{ found = false, value = 0 };
    }
    cursor = cursor + 12;
    usize digits = 0;
    while cursor < text.byte_length(source) &&
        is_digit(text.byte_at_unchecked(source, cursor)) {
        value = value * 10 + cast(usize,
            text.byte_at_unchecked(source, cursor) - 48);
        cursor = cursor + 1;
        digits = digits + 1;
    }
    return NativeCompilerConstant{
        found = digits != 0 && starts_with_ascii(source, cursor, "; }"),
        value = value
    };
}

unsafe void native_compiler_project_slice(ref IrContext context,
    ref NativeFunction function, usize instruction, usize result) {
    usize source = d_operand_value(context, instruction, 0);
    native_load(function, source, 10);
    x64_mov_r64_memory(function.code, 8, 4,
        native_slot(function, source) + 8);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    native_load(function, d_operand_value(context, instruction, 2), 9);
    x64_mov_r64_imm64(function.code, 11, cast(u64, 0));
    x64_mov_memory_r64(function.code, 4, native_slot(function, result), 11);
    x64_mov_memory_r64(function.code, 4,
        native_slot(function, result) + 8, 11);
    x64_cmp_r64_r64(function.code, 0, 8);
    usize bad_start = native_skip(function.code, 7);
    x64_binary_r64_r64(function.code, 41, 8, 0);
    x64_cmp_r64_r64(function.code, 9, 8);
    usize bad_length = native_skip(function.code, 7);
    x64_add_r64_r64(function.code, 10, 0);
    x64_mov_memory_r64(function.code, 4,
        native_slot(function, result), 10);
    x64_mov_memory_r64(function.code, 4,
        native_slot(function, result) + 8, 9);
    native_skip_end(function.code, bad_start);
    native_skip_end(function.code, bad_length);
}

unsafe bool native_compiler_span_is(
    ref DCompilerCallSpan call_span,
    text expected
) {
    return call_span.found && span_equals_ascii(
        call_span.source, call_span.start, call_span.length, expected
    );
}

unsafe bool native_compiler_counter_call(
    ref IrContext context,
    ref DCompilerCallSpan call_span,
    ref NativeFunction function, usize instruction, usize result,
    text name, usize offset) {
    if !native_compiler_span_is(call_span, name) { return false; }
    if d_operand_count(context, instruction) != 0 {
        function.code.ok = false; return true;
    }
    native_data_address(function, offset, 11);
    x64_mov_r64_memory(function.code, 0, 11, 0);
    native_store(function, result, 0);
    return true;
}

// Intrinsics for the compiler's packed-record primitives. These four helpers
// dominate frontend traffic; lowering them to direct memory operations avoids
// several native stack-frame calls for every token, syntax, symbol and IR field.
