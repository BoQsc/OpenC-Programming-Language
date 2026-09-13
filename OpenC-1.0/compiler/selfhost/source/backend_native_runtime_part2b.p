import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool native_runtime_name(
    ref DCompilerCallSpan call_span,
    text short_name,
    text qualified_name
) {
    if !call_span.found { return false; }
    return span_equals_ascii(
            call_span.source, call_span.start, call_span.length, short_name
        ) || span_equals_ascii(
            call_span.source, call_span.start, call_span.length,
            qualified_name
        );
}

unsafe bool native_runtime_call(ref IrContext context, ref NativeFunction function,
    usize instruction) {
    usize result = read_record_field(context.instruction_data, instruction, 1);
    usize detail_kind = read_record_field(
        context.instruction_detail, instruction, 0
    );
    usize detail_one = read_record_field(
        context.instruction_detail, instruction, 1
    );
    usize detail_two = read_record_field(
        context.instruction_detail, instruction, 2
    );
    DCompilerCallSpan call_span = native_runtime_call_span(
        context, detail_kind, detail_one, detail_two
    );
    if detail_kind == 3 {
        if !native_runtime_name(
            call_span, "lsp_read_frame", "ocb_lsp_read_frame"
        ) && !native_runtime_name(
            call_span,
            "cli_process_run_bounded", "cli_process_run_bounded"
        ) && !native_runtime_name(
            call_span,
            "cli_process_run_measured", "cli_process_run_measured"
        ) && !native_runtime_name(
            call_span,
            "cli_file_append_bytes", "cli_file_append_bytes"
        ) && !native_runtime_name(
            call_span,
            "cli_file_create_directory", "cli_file_create_directory"
        ) && !native_runtime_name(
            call_span,
            "win_resources_load_runtime", "ocw_library_load_system"
        ) && !native_runtime_name(
            call_span,
            "win_resources_load_absolute_runtime", "ocw_library_load_absolute"
        ) && !native_runtime_name(
            call_span,
            "win_resources_symbol_runtime", "ocw_library_symbol"
        ) && !native_runtime_name(
            call_span,
            "win_resources_close_runtime", "ocw_library_close"
        ) && !native_runtime_name(
            call_span,
            "win_resources_call_i32_two_runtime",
            "ocw_library_call_i32_two"
        ) && !native_runtime_name(
            call_span,
            "cli_sh22_dynamic_probe", "cli_sh22_dynamic_probe"
        ) && !native_runtime_name(
            call_span, "win_com_initialize_runtime", "ocw_com_initialize"
        ) && !native_runtime_name(
            call_span, "win_com_uninitialize_runtime", "ocw_com_uninitialize"
        ) && !native_runtime_name(
            call_span, "win_com_create_stream_runtime", "ocw_com_create_stream"
        ) && !native_runtime_name(
            call_span, "win_com_query_runtime", "ocw_com_query_interface"
        ) && !native_runtime_name(
            call_span, "win_com_add_ref_runtime", "ocw_com_add_ref"
        ) && !native_runtime_name(
            call_span, "win_com_release_runtime", "ocw_com_release"
        ) && !native_runtime_name(
            call_span, "win_winrt_initialize_runtime", "ocw_winrt_initialize"
        ) && !native_runtime_name(
            call_span, "win_winrt_uninitialize_runtime", "ocw_winrt_uninitialize"
        ) && !native_runtime_name(
            call_span, "win_winrt_string_create_runtime", "ocw_winrt_string_create"
        ) && !native_runtime_name(
            call_span, "win_winrt_string_delete_runtime", "ocw_winrt_string_delete"
        ) && !native_runtime_name(
            call_span, "win_winrt_factory_runtime", "ocw_winrt_activation_factory"
        ) && !native_runtime_name(
            call_span, "win_winrt_activate_runtime", "ocw_winrt_activate_instance"
        ) && !native_runtime_name(
            call_span, "win_winrt_class_name_runtime", "ocw_winrt_runtime_class_name"
        ) && !native_runtime_name(
            call_span, "win_winrt_trust_level_runtime", "ocw_winrt_trust_level"
        ) {
            return false;
        }
    }
    if native_runtime_name(call_span, "memory.alloc", "system.memory.alloc") {
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
    if native_runtime_name(call_span, "memory.free", "system.memory.free") {
        native_load(function, d_operand_value(context, instruction, 0), 8);
        native_heap_free_r8(function); return true;
    }
    if native_runtime_name(call_span, "text.trim", "system.text.trim") {
        native_text_trim(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "text.length", "system.text.length") {
        native_text_scalar_length(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "memory.load_usize", "system.memory.load_usize") {
        native_load(function, d_operand_value(context, instruction, 0), 11);
        x64_mov_r64_memory(function.code, 0, 11, 0); native_store(function, result, 0);
        return true;
    }
    if native_runtime_name(call_span, "memory.store_usize", "system.memory.store_usize") {
        native_load(function, d_operand_value(context, instruction, 0), 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_memory_r64(function.code, 11, 0, 0); return true;
    }
    if native_runtime_name(call_span, "text.byte_at_unchecked", "system.text.byte_at_unchecked") {
        usize value = d_operand_value(context, instruction, 0);
        native_load(function, value, 11);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_add_r64_r64(function.code, 11, 0);
        x64_emit_u8(function.code, 65); x64_emit_u8(function.code, 15);
        x64_emit_u8(function.code, 182); x64_emit_u8(function.code, 3);
        native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "text.copy_utf8_unchecked",
        "system.text.copy_utf8_unchecked") {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        usize value = d_operand_value(context, instruction, 1);
        native_load(function, value, 11);
        x64_mov_r64_memory(function.code, 9, 4, native_slot(function, value) + 8);
        native_copy_bytes(function); return true;
    }
    if native_runtime_name(call_span, "text.copy_utf8_slice_unchecked",
        "system.text.copy_utf8_slice_unchecked") {
        native_load(function, d_operand_value(context, instruction, 0), 10);
        usize value = d_operand_value(context, instruction, 1);
        native_load(function, value, 11);
        native_load(function, d_operand_value(context, instruction, 2), 0);
        x64_add_r64_r64(function.code, 11, 0);
        native_load(function, d_operand_value(context, instruction, 3), 9);
        native_copy_bytes(function); return true;
    }
    if native_runtime_name(call_span, "text.from_utf8", "system.text.from_utf8") {
        native_load(function, d_operand_value(context, instruction, 0), 0);
        native_store(function, result, 0);
        native_load(function, d_operand_value(context, instruction, 1), 0);
        x64_mov_memory_r64(function.code, 4, native_slot(function, result) + 8, 0);
        return true;
    }
    if native_runtime_name(call_span, "text.equal", "system.text.equal") {
        native_text_equal(function, d_operand_value(context, instruction, 0),
            d_operand_value(context, instruction, 1));
        native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "text.slice", "system.text.slice") {
        if d_operand_count(context, instruction) != 4 { function.code.ok = false; return true; }
        native_text_scalar_slice(context, function, instruction, result); return true;
    }
    if native_runtime_name(call_span, "process.run", "system.process.run") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if native_runtime_name(
        call_span, "cli_process_run_bounded", "cli_process_run_bounded"
    ) {
        if d_operand_count(context, instruction) != 4 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if native_runtime_name(
        call_span, "cli_process_run_measured", "cli_process_run_measured"
    ) {
        if d_operand_count(context, instruction) != 6 { function.code.ok = false; return true; }
        native_process_run(context, function, instruction, result); return true;
    }
    if native_runtime_name(call_span, "path.join", "system.path.join") {
        native_path_join(function, d_operand_value(context, instruction, 0),
        d_operand_value(context, instruction, 1), result); return true;
    }
    if native_runtime_name(call_span, "path.directory", "system.path.directory") {
        native_path_directory(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(call_span, "process.monotonic_milliseconds",
        "system.process.monotonic_milliseconds") {
        native_import(function, 16); native_store(function, result, 0); return true;
    }
    if native_runtime_name(call_span, "process.argument_count",
        "system.process.argument_count") {
        native_process_argument_count(function, result); return true;
    }
    if native_runtime_name(call_span, "process.argument", "system.process.argument") {
        native_process_argument(function, d_operand_value(context, instruction, 0), result);
        return true;
    }
    if native_runtime_name(
            call_span, "process.current_directory",
            "system.process.current_directory"
        ) || native_runtime_name(
            call_span, "runtime_current_directory",
            "oc_process_current_directory"
        ) {
        native_process_current_directory(function, result); return true;
    }
    if native_runtime_name(call_span, "process.executable_directory",
        "system.process.executable_directory") {
        native_process_executable_directory(function, result); return true;
    }
    if native_runtime_name(call_span, "process.executable_path",
            "system.process.executable_path") || native_runtime_name(
            call_span, "runtime_executable_path",
            "oc_process_executable_path"
        ) {
        native_process_executable_path(function, result); return true;
    }
    if native_runtime_name(call_span, "lsp_read_frame", "ocb_lsp_read_frame") {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_lsp_read_frame(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(call_span, "file.read_text_cached", "system.file.read_text_cached") {
        native_file_read_cached(context, function, instruction, result); return true;
    }
    if native_runtime_name(
        call_span,
        "win_resources_load_runtime", "ocw_library_load_system"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_library_load(context, function, instruction, result, 2048);
        return true;
    }
    if native_runtime_name(
        call_span,
        "win_resources_load_absolute_runtime", "ocw_library_load_absolute"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_library_load(context, function, instruction, result, 4352);
        return true;
    }
    if native_runtime_name(
        call_span,
        "win_resources_symbol_runtime", "ocw_library_symbol"
    ) {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_library_symbol(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span,
        "win_resources_close_runtime", "ocw_library_close"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_library_close(context, function, instruction);
        return true;
    }
    if native_runtime_name(
        call_span,
        "win_resources_call_i32_two_runtime",
        "ocw_library_call_i32_two"
    ) {
        if d_operand_count(context, instruction) != 3 {
            function.code.ok = false; return true;
        }
        native_library_call_i32_two(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span,
        "cli_sh22_dynamic_probe", "cli_sh22_dynamic_probe"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_library_dynamic_probe(
            context, function, instruction, result
        );
        return true;
    }
    if native_runtime_name(
        call_span, "win_com_initialize_runtime", "ocw_com_initialize"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_com_initialize(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span, "win_com_uninitialize_runtime", "ocw_com_uninitialize"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_com_uninitialize(context, function, instruction); return true;
    }
    if native_runtime_name(
        call_span, "win_com_create_stream_runtime", "ocw_com_create_stream"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_com_create_stream(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span, "win_com_query_runtime", "ocw_com_query_interface"
    ) {
        if d_operand_count(context, instruction) != 4 {
            function.code.ok = false; return true;
        }
        native_com_query_interface(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span, "win_com_add_ref_runtime", "ocw_com_add_ref"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_com_reference_call(context, function, instruction, result, 8);
        return true;
    }
    if native_runtime_name(
        call_span, "win_com_release_runtime", "ocw_com_release"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_com_reference_call(context, function, instruction, result, 16);
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_initialize_runtime", "ocw_winrt_initialize"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_winrt_initialize(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_uninitialize_runtime", "ocw_winrt_uninitialize"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_winrt_uninitialize(context, function, instruction); return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_string_create_runtime", "ocw_winrt_string_create"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_winrt_string_create(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_string_delete_runtime", "ocw_winrt_string_delete"
    ) {
        if d_operand_count(context, instruction) != 1 {
            function.code.ok = false; return true;
        }
        native_winrt_string_delete(context, function, instruction);
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_factory_runtime", "ocw_winrt_activation_factory"
    ) {
        if d_operand_count(context, instruction) != 4 {
            function.code.ok = false; return true;
        }
        native_winrt_activation_factory(context, function, instruction, result);
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_activate_runtime", "ocw_winrt_activate_instance"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_winrt_inspectable_call(
            context, function, instruction, result, 48
        );
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_class_name_runtime", "ocw_winrt_runtime_class_name"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_winrt_inspectable_call(
            context, function, instruction, result, 32
        );
        return true;
    }
    if native_runtime_name(
        call_span, "win_winrt_trust_level_runtime", "ocw_winrt_trust_level"
    ) {
        if d_operand_count(context, instruction) != 2 {
            function.code.ok = false; return true;
        }
        native_winrt_inspectable_call(
            context, function, instruction, result, 40
        );
        return true;
    }
    if native_runtime_name(call_span, "file.read_text", "system.file.read_text") ||
        native_runtime_name(call_span, "file.read_bytes", "system.file.read_bytes") {
        native_file_read(context, function, instruction, result, false); return true;
    }
    if native_runtime_name(call_span, "file.read_bytes_raw", "system.file.read_bytes_raw") {
        native_file_read(context, function, instruction, result, true); return true;
    }
    if native_runtime_name(call_span, "file.write_text", "system.file.write_text") {
        if d_operand_count(context, instruction) != 2 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, false, false); return true;
    }
    if native_runtime_name(call_span, "file.write_bytes", "system.file.write_bytes") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, true, false); return true;
    }
    if native_runtime_name(call_span, "cli_file_append_bytes", "cli_file_append_bytes") {
        if d_operand_count(context, instruction) != 3 { function.code.ok = false; return true; }
        native_file_write(context, function, instruction, result, true, true); return true;
    }
    if native_runtime_name(call_span, "cli_file_create_directory", "cli_file_create_directory") {
        if d_operand_count(context, instruction) != 1 { function.code.ok = false; return true; }
        native_create_directory(context, function, instruction, result); return true;
    }
    bool println = native_runtime_name(call_span, "io.println", "system.io.println");
    bool print = native_runtime_name(call_span, "io.print", "system.io.print");
    bool error_stream = native_runtime_name(call_span, "io.error", "system.io.error");
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
