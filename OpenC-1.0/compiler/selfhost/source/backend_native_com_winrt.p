import system.text;

// Optional COM/WinRT calls are resolved through documented LoadLibraryExW,
// GetProcAddress, and FreeLibrary calls on the secure system-library path.
// path. Ordinary OpenC images therefore retain the single KERNEL32 import
// surface and acquire OLE32/COMBASE only when these modules are used at run
// time.
unsafe void native_windows_dynamic_prepare(
    ref NativeFunction function,
    text library,
    text symbol
) {
    native_constant_ascii(function, library, true, 1);
    x64_mov_r64_imm64(function.code, 2, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 8, cast(u64, 2048));
    native_import(function, 19);
    x64_mov_memory_r64(function.code, 4, 600, 0);
    x64_mov_r64_r64(function.code, 1, 0);
    native_constant_ascii(function, symbol, false, 2);
    native_import(function, 20);
    x64_mov_memory_r64(function.code, 4, 608, 0);
}

unsafe void native_windows_dynamic_close(ref NativeFunction function) {
    x64_mov_r64_memory(function.code, 1, 4, 600);
    native_import(function, 22);
}

unsafe usize native_windows_dynamic_available(ref NativeFunction function) {
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    return native_skip(function.code, 5);
}

unsafe void native_windows_status_from_hresult(
    ref NativeFunction function,
    usize result
) {
    // HRESULT success is any non-negative signed 32-bit value.
    x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize succeeded = native_skip(function.code, 9);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, succeeded);
    native_status_success(function, result);
    native_skip_end(function.code, finished);
}

unsafe void native_windows_stack_address(
    ref NativeFunction function,
    usize destination,
    usize offset
) {
    x64_emit_rex(function.code, true, destination, 0, 4);
    x64_emit_u8(function.code, 141);
    x64_emit_memory_modrm(function.code, destination, 4, offset);
}

unsafe void native_com_initialize(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_windows_dynamic_prepare(function, "ole32.dll", "CoInitializeEx");
    usize available = native_windows_dynamic_available(function);
    native_status_failure(function, result, 1);
    native_windows_dynamic_close(function);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, available);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    native_load(function, d_operand_value(context, instruction, 0), 2);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize initialized = native_skip(function.code, 9);
    native_status_failure(function, result, 1);
    native_windows_dynamic_close(function);
    usize failed = native_jump(function.code);
    native_skip_end(function.code, initialized);
    native_output_address(
        function, d_operand_value(context, instruction, 1), 11
    );
    x64_mov_r64_memory(function.code, 0, 4, 600);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    native_status_success(function, result);
    native_skip_end(function.code, failed);
    native_skip_end(function.code, finished);
}

unsafe void native_com_uninitialize(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_memory_r64(function.code, 4, 600, 1);
    native_constant_ascii(function, "CoUninitialize", false, 2);
    native_import(function, 20);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize unavailable = native_skip(function.code, 4);
    x64_call_r64(function.code, 0);
    native_skip_end(function.code, unavailable);
    native_windows_dynamic_close(function);
}

unsafe void native_com_create_stream(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_windows_dynamic_prepare(
        function, "ole32.dll", "CreateStreamOnHGlobal"
    );
    usize available = native_windows_dynamic_available(function);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, available);
    x64_mov_r64_imm64(function.code, 1, cast(u64, 0));
    x64_mov_r64_imm64(function.code, 2, cast(u64, 1));
    native_output_address(
        function, d_operand_value(context, instruction, 0), 8
    );
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_windows_status_from_hresult(function, result);
    native_skip_end(function.code, finished);
    native_windows_dynamic_close(function);
}

unsafe void native_com_query_interface(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_r64_memory(function.code, 0, 1, 0);
    x64_mov_r64_memory(function.code, 0, 0, 0);
    x64_mov_memory_r64(function.code, 4, 608, 0);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_memory_r64(function.code, 4, 616, 0);
    native_load(function, d_operand_value(context, instruction, 2), 0);
    x64_mov_memory_r64(function.code, 4, 624, 0);
    native_windows_stack_address(function, 2, 616);
    native_output_address(
        function, d_operand_value(context, instruction, 3), 8
    );
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_windows_status_from_hresult(function, result);
}

unsafe void native_com_reference_call(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result,
    usize vtable_offset
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_r64_memory(function.code, 0, 1, 0);
    x64_mov_r64_memory(function.code, 0, 0, vtable_offset);
    x64_call_r64(function.code, 0);
    native_store(function, result, 0);
}

unsafe void native_winrt_initialize(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_windows_dynamic_prepare(function, "combase.dll", "RoInitialize");
    usize available = native_windows_dynamic_available(function);
    native_status_failure(function, result, 1);
    native_windows_dynamic_close(function);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, available);
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    x64_emit_u8(function.code, 133); x64_emit_u8(function.code, 192);
    usize initialized = native_skip(function.code, 9);
    native_status_failure(function, result, 1);
    native_windows_dynamic_close(function);
    usize failed = native_jump(function.code);
    native_skip_end(function.code, initialized);
    native_output_address(
        function, d_operand_value(context, instruction, 1), 11
    );
    x64_mov_r64_memory(function.code, 0, 4, 600);
    x64_mov_memory_r64(function.code, 11, 0, 0);
    native_status_success(function, result);
    native_skip_end(function.code, failed);
    native_skip_end(function.code, finished);
}

unsafe void native_winrt_uninitialize(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_memory_r64(function.code, 4, 600, 1);
    native_constant_ascii(function, "RoUninitialize", false, 2);
    native_import(function, 20);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize unavailable = native_skip(function.code, 4);
    x64_call_r64(function.code, 0);
    native_skip_end(function.code, unavailable);
    native_windows_dynamic_close(function);
}

unsafe void native_winrt_string_create(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_utf8_path(
        function, d_operand_value(context, instruction, 0)
    );
    native_windows_dynamic_prepare(
        function, "combase.dll", "WindowsCreateString"
    );
    usize available = native_windows_dynamic_available(function);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, available);
    x64_mov_r64_memory(function.code, 1, 4, 504);
    x64_mov_r64_memory(function.code, 2, 4, 496);
    native_output_address(
        function, d_operand_value(context, instruction, 1), 8
    );
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_windows_status_from_hresult(function, result);
    native_skip_end(function.code, finished);
    native_windows_dynamic_close(function);
    x64_mov_r64_memory(function.code, 8, 4, 504);
    native_heap_free_r8(function);
}

unsafe void native_winrt_string_delete(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction
) {
    native_windows_dynamic_prepare(
        function, "combase.dll", "WindowsDeleteString"
    );
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_emit_u8(function.code, 72); x64_emit_u8(function.code, 133);
    x64_emit_u8(function.code, 192);
    usize unavailable = native_skip(function.code, 4);
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_skip_end(function.code, unavailable);
    native_windows_dynamic_close(function);
}

unsafe void native_winrt_activation_factory(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result
) {
    native_windows_dynamic_prepare(
        function, "combase.dll", "RoGetActivationFactory"
    );
    usize available = native_windows_dynamic_available(function);
    native_status_failure(function, result, 1);
    usize finished = native_jump(function.code);
    native_skip_end(function.code, available);
    native_load(function, d_operand_value(context, instruction, 1), 0);
    x64_mov_memory_r64(function.code, 4, 616, 0);
    native_load(function, d_operand_value(context, instruction, 2), 0);
    x64_mov_memory_r64(function.code, 4, 624, 0);
    native_load(function, d_operand_value(context, instruction, 0), 1);
    native_windows_stack_address(function, 2, 616);
    native_output_address(
        function, d_operand_value(context, instruction, 3), 8
    );
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_windows_status_from_hresult(function, result);
    native_skip_end(function.code, finished);
    native_windows_dynamic_close(function);
}

unsafe void native_winrt_inspectable_call(
    ref IrContext context,
    ref NativeFunction function,
    usize instruction,
    usize result,
    usize vtable_offset
) {
    native_load(function, d_operand_value(context, instruction, 0), 1);
    x64_mov_r64_memory(function.code, 0, 1, 0);
    x64_mov_r64_memory(function.code, 0, 0, vtable_offset);
    x64_mov_memory_r64(function.code, 4, 608, 0);
    native_output_address(
        function, d_operand_value(context, instruction, 1), 2
    );
    x64_mov_r64_memory(function.code, 0, 4, 608);
    x64_call_r64(function.code, 0);
    native_windows_status_from_hresult(function, result);
}
