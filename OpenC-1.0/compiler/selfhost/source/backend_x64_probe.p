import system.file;

unsafe X64Code x64_probe_integer_six() {
    X64Code code = x64_code_create(64, 1);
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rcx());
    x64_add_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rdx());
    x64_add_r64_r64(code, win64_abi_register_rax(), win64_abi_register_r8());
    x64_add_r64_r64(code, win64_abi_register_rax(), win64_abi_register_r9());
    x64_add_r64_memory(
        code, win64_abi_register_rax(), win64_abi_register_rsp(), 40
    );
    x64_add_r64_memory(
        code, win64_abi_register_rax(), win64_abi_register_rsp(), 48
    );
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_float_four() {
    X64Code code = x64_code_create(32, 1);
    x64_addsd_xmm_xmm(code, 0, 1);
    x64_addsd_xmm_xmm(code, 0, 2);
    x64_addsd_xmm_xmm(code, 0, 3);
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_aggregate_pair() {
    X64Code code = x64_code_create(32, 1);
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rcx());
    x64_xor_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rdx());
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_indirect_aggregate() {
    X64Code code = x64_code_create(32, 1);
    x64_mov_r64_memory(
        code, win64_abi_register_rax(), win64_abi_register_rcx(), 0
    );
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_hidden_aggregate_return() {
    X64Code code = x64_code_create(32, 1);
    x64_mov_memory_r64(
        code, win64_abi_register_rcx(), 0, win64_abi_register_rdx()
    );
    x64_mov_r64_r64(
        code, win64_abi_register_rax(), win64_abi_register_rcx()
    );
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_callback_call() {
    X64Code code = x64_code_create(64, 1);
    x64_sub_rsp(code, 40);
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rcx());
    x64_mov_r64_r64(code, win64_abi_register_rcx(), win64_abi_register_rdx());
    x64_call_r64(code, win64_abi_register_rax());
    x64_add_rsp(code, 40);
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_stack_alignment() {
    X64Code code = x64_code_create(32, 1);
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rsp());
    x64_and_r64_imm8(code, win64_abi_register_rax(), 15);
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_nonvolatile_inner() {
    X64Code code = x64_code_create(64, 1);
    x64_push_r64(code, win64_abi_register_rbx());
    x64_mov_r64_r64(code, win64_abi_register_rbx(), win64_abi_register_rcx());
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rbx());
    x64_add_r64_imm8(code, win64_abi_register_rax(), 1);
    x64_pop_r64(code, win64_abi_register_rbx());
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_nonvolatile_outer() {
    X64Code code = x64_code_create(96, 1);
    x64_push_r64(code, win64_abi_register_rbx());
    x64_sub_rsp(code, 32);
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rcx());
    x64_mov_r64_imm64(
        code, win64_abi_register_rbx(),
        (cast(u64, 287454020) << cast(usize, 32)) |
            cast(u64, 1432778632)
    );
    x64_mov_r64_r64(code, win64_abi_register_rcx(), win64_abi_register_rdx());
    x64_call_r64(code, win64_abi_register_rax());
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rbx());
    x64_add_rsp(code, 32);
    x64_pop_r64(code, win64_abi_register_rbx());
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_variadic_float() {
    X64Code code = x64_code_create(64, 1);
    x64_movq_r64_xmm(code, win64_abi_register_rax(), 1);
    x64_cmp_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rdx());
    x64_set_equal_al(code);
    x64_zero_extend_al_eax(code);
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_nonvolatile_vector_inner() {
    X64Code code = x64_code_create(96, 1);
    x64_sub_rsp(code, 40);
    x64_movdqu_memory_xmm(
        code, win64_abi_register_rsp(), 16, 6
    );
    x64_movq_xmm_r64(code, 6, win64_abi_register_rcx());
    x64_movq_r64_xmm(code, win64_abi_register_rax(), 6);
    x64_movdqu_xmm_memory(
        code, 6, win64_abi_register_rsp(), 16
    );
    x64_add_rsp(code, 40);
    x64_ret(code);
    return code;
}

unsafe X64Code x64_probe_nonvolatile_vector_outer() {
    X64Code code = x64_code_create(128, 1);
    x64_sub_rsp(code, 40);
    x64_movdqu_memory_xmm(
        code, win64_abi_register_rsp(), 16, 6
    );
    x64_mov_r64_r64(code, win64_abi_register_rax(), win64_abi_register_rcx());
    x64_mov_r64_r64(code, win64_abi_register_rcx(), win64_abi_register_rdx());
    x64_mov_r64_imm64(
        code, win64_abi_register_rdx(),
        (cast(u64, 253635900) << cast(usize, 32)) |
            cast(u64, 1264216440)
    );
    x64_movq_xmm_r64(code, 6, win64_abi_register_rdx());
    x64_call_r64(code, win64_abi_register_rax());
    x64_movq_r64_xmm(code, win64_abi_register_rax(), 6);
    x64_movdqu_xmm_memory(
        code, 6, win64_abi_register_rsp(), 16
    );
    x64_add_rsp(code, 40);
    x64_ret(code);
    return code;
}

unsafe DBuffer x64_probe_callback_unwind() {
    X64UnwindBuilder builder = x64_unwind_create(4);
    x64_unwind_add_allocation(builder, 4, 40);
    DBuffer output = x64_unwind_encode(builder);
    x64_unwind_destroy(builder);
    return output;
}

unsafe DBuffer x64_probe_inner_unwind() {
    X64UnwindBuilder builder = x64_unwind_create(4);
    x64_unwind_add_push_nonvolatile(
        builder, 1, win64_abi_register_rbx()
    );
    DBuffer output = x64_unwind_encode(builder);
    x64_unwind_destroy(builder);
    return output;
}

unsafe DBuffer x64_probe_outer_unwind() {
    X64UnwindBuilder builder = x64_unwind_create(4);
    x64_unwind_add_push_nonvolatile(
        builder, 1, win64_abi_register_rbx()
    );
    x64_unwind_add_allocation(builder, 5, 32);
    DBuffer output = x64_unwind_encode(builder);
    x64_unwind_destroy(builder);
    return output;
}

unsafe DBuffer x64_probe_vector_unwind() {
    X64UnwindBuilder builder = x64_unwind_create(4);
    x64_unwind_add_allocation(builder, 4, 40);
    x64_unwind_add_saved_vector(builder, 10, 6, 16);
    DBuffer output = x64_unwind_encode(builder);
    x64_unwind_destroy(builder);
    return output;
}

unsafe void x64_report_bool(ref DBuffer report, bool value) {
    if value { d_put(report, "true"); }
    else { d_put(report, "false"); }
}

unsafe void x64_report_hex(ref DBuffer report, ref DBuffer bytes) {
    d_put(report, "\"");
    x64_put_hex(report, bytes);
    d_put(report, "\"");
}

unsafe void x64_report_location(
    ref DBuffer report,
    ref Win64AbiLocation location
) {
    d_put(report, "{\"kind\":\"");
    d_put(report, win64_location_kind_name(location.kind));
    d_put(report, "\",\"register\":\"");
    if location.kind == win64_abi_location_vector_register() {
        d_put(report, win64_vector_register_name(location.register_code));
    } else if location.kind == win64_abi_location_integer_register() {
        d_put(report, win64_integer_register_name(location.register_code));
    } else {
        d_put(report, "none");
    }
    d_put(report, "\",\"stack_offset\":");
    d_put_usize(report, location.stack_offset);
    d_put(report, ",\"indirect\":");
    x64_report_bool(report, location.indirect);
    d_put(report, ",\"duplicate_float_to_integer\":");
    x64_report_bool(report, location.duplicate_float_to_integer);
    d_put(report, "}");
}

unsafe void x64_report_field_layout(
    ref DBuffer report,
    ref Win64FieldLayout field
) {
    d_put(report, "{\"byte_offset\":");
    d_put_usize(report, field.byte_offset);
    d_put(report, ",\"bit_offset\":");
    d_put_usize(report, field.bit_offset);
    d_put(report, ",\"size\":");
    d_put_usize(report, field.size);
    d_put(report, ",\"alignment\":");
    d_put_usize(report, field.alignment);
    d_put(report, ",\"bit_width\":");
    d_put_usize(report, field.bit_width);
    d_put(report, ",\"ok\":");
    x64_report_bool(report, field.ok);
    d_put(report, "}");
}

unsafe void x64_report_code(
    ref DBuffer report,
    text name,
    ref X64Code code,
    bool trailing_comma
) {
    d_put(report, "    \""); d_put(report, name);
    d_put(report, "\": {\"bytes\": ");
    x64_report_hex(report, code.bytes);
    d_put(report, ", \"length\": ");
    d_put_usize(report, code.bytes.length);
    d_put(report, ", \"relocations\": ");
    d_put_usize(report, code.relocations.length);
    d_put(report, ", \"ok\": ");
    x64_report_bool(report, code.ok && code.bytes.ok);
    d_put(report, "}");
    if trailing_comma { d_put(report, ","); }
    d_put(report, "\n");
}

unsafe i32 emit_windows_x64_substrate_report(text output_path) {
    Win64AbiType integer = win64_abi_integer(8);
    Win64AbiType floating = win64_abi_float64();
    Win64AbiType aggregate8 = win64_abi_aggregate(8, 8, true);
    Win64AbiType aggregate12 = win64_abi_aggregate(12, 4, true);
    Win64AbiLocation mixed_zero = win64_abi_argument(
        integer, 0, false, false
    );
    Win64AbiLocation mixed_one = win64_abi_argument(
        floating, 1, false, false
    );
    Win64AbiLocation mixed_two = win64_abi_argument(
        aggregate12, 2, false, false
    );
    Win64AbiLocation mixed_three = win64_abi_argument(
        floating, 3, false, true
    );
    Win64AbiLocation mixed_four = win64_abi_argument(
        integer, 4, false, false
    );
    Win64ReturnLocation direct_return = win64_abi_return(aggregate8);
    Win64ReturnLocation hidden_return = win64_abi_return(aggregate12);
    Win64AbiLocation shifted_first = win64_abi_argument(
        integer, 0, hidden_return.shifts_arguments, false
    );
    Win64FrameLayout callback_frame = win64_abi_frame(0, 2, 0, 0, true);
    Win64FrameLayout outer_frame = win64_abi_frame(0, 2, 1, 0, true);

    Win64LayoutCursor structure = win64_layout_create(false, 0);
    Win64FieldLayout structure_tag = win64_layout_add_field(structure, 1, 1);
    Win64FieldLayout structure_pointer = win64_layout_add_field(structure, 8, 8);
    Win64FieldLayout structure_long = win64_layout_add_field(structure, 4, 4);
    usize structure_size = win64_layout_finish(structure);
    Win64LayoutCursor union_layout = win64_layout_create(true, 0);
    Win64FieldLayout union_u32 = win64_layout_add_field(union_layout, 4, 4);
    Win64FieldLayout union_u64 = win64_layout_add_field(union_layout, 8, 8);
    usize union_size = win64_layout_finish(union_layout);
    Win64LayoutCursor explicit_layout = win64_layout_create(false, 0);
    Win64FieldLayout explicit_tag = win64_layout_add_explicit_field(
        explicit_layout, 0, 1, 1
    );
    Win64FieldLayout explicit_value = win64_layout_add_explicit_field(
        explicit_layout, 4, 4, 4
    );
    usize explicit_size = win64_layout_finish(explicit_layout);
    Win64LayoutCursor bits = win64_layout_create(false, 0);
    Win64FieldLayout bits_a = win64_layout_add_bitfield(bits, 4, 3);
    Win64FieldLayout bits_b = win64_layout_add_bitfield(bits, 4, 5);
    Win64FieldLayout bits_c = win64_layout_add_bitfield(bits, 4, 10);
    usize bits_size = win64_layout_finish(bits);

    X64Code integer_code = x64_probe_integer_six();
    X64Code float_code = x64_probe_float_four();
    X64Code aggregate_code = x64_probe_aggregate_pair();
    X64Code indirect_aggregate_code = x64_probe_indirect_aggregate();
    X64Code hidden_return_code = x64_probe_hidden_aggregate_return();
    X64Code callback_code = x64_probe_callback_call();
    X64Code alignment_code = x64_probe_stack_alignment();
    X64Code inner_code = x64_probe_nonvolatile_inner();
    X64Code outer_code = x64_probe_nonvolatile_outer();
    X64Code variadic_code = x64_probe_variadic_float();
    X64Code vector_inner_code = x64_probe_nonvolatile_vector_inner();
    X64Code vector_outer_code = x64_probe_nonvolatile_vector_outer();
    DBuffer callback_unwind = x64_probe_callback_unwind();
    DBuffer inner_unwind = x64_probe_inner_unwind();
    DBuffer outer_unwind = x64_probe_outer_unwind();
    DBuffer vector_unwind = x64_probe_vector_unwind();
    DBuffer runtime_record = x64_runtime_function_record(
        0, callback_code.bytes.length, 32
    );

    X64Code relative = x64_code_create(32, 4);
    x64_call_symbol(relative, 7, -4);
    x64_ret(relative);
    DBuffer relative_unresolved = d_buffer_create(32);
    x64_copy_bytes(relative_unresolved, relative.bytes);
    bool relative_applied = x64_apply_relative32(relative, 0, 16);
    X64Code backward_relative = x64_code_create(32, 4);
    x64_call_symbol(backward_relative, 9, -4);
    x64_ret(backward_relative);
    bool backward_relative_applied = x64_apply_relative32(
        backward_relative, 0, 0
    );
    X64Code absolute = x64_code_create(32, 4);
    x64_mov_r64_symbol(absolute, win64_abi_register_rax(), 11, 0);
    x64_ret(absolute);
    DBuffer absolute_unresolved = d_buffer_create(32);
    x64_copy_bytes(absolute_unresolved, absolute.bytes);
    bool absolute_applied = x64_apply_absolute64(
        absolute, 0,
        (cast(u64, 287454020) << cast(usize, 32)) |
            cast(u64, 1432778632)
    );

    bool passed =
        mixed_zero.kind == win64_abi_location_integer_register() &&
        mixed_zero.register_code == win64_abi_register_rcx() &&
        mixed_one.kind == win64_abi_location_vector_register() &&
        mixed_one.register_code == 1 &&
        mixed_two.indirect && mixed_two.register_code == win64_abi_register_r8() &&
        mixed_three.duplicate_float_to_integer &&
        mixed_three.register_code == 3 &&
        mixed_four.kind == win64_abi_location_stack() &&
        mixed_four.stack_offset == 32 &&
        direct_return.register_code == win64_abi_register_rax() &&
        hidden_return.hidden_pointer && shifted_first.register_code ==
            win64_abi_register_rdx() &&
        callback_frame.fixed_allocation_bytes == 40 &&
        outer_frame.fixed_allocation_bytes == 32 &&
        structure_size == 24 && structure_pointer.byte_offset == 8 &&
        structure_long.byte_offset == 16 && union_size == 8 &&
        explicit_size == 8 && explicit_value.byte_offset == 4 &&
        bits_size == 4 && bits_a.bit_offset == 0 &&
        bits_b.bit_offset == 3 && bits_c.bit_offset == 8 &&
        integer_code.ok && float_code.ok && aggregate_code.ok &&
        indirect_aggregate_code.ok && hidden_return_code.ok &&
        callback_code.ok && alignment_code.ok && inner_code.ok &&
        outer_code.ok && variadic_code.ok &&
        vector_inner_code.ok && vector_outer_code.ok &&
        callback_unwind.ok && inner_unwind.ok && outer_unwind.ok &&
        vector_unwind.ok &&
        relative_applied && backward_relative_applied && absolute_applied &&
        x64_runtime_function_ordered(0, 17, 32, 40);

    DBuffer report = d_buffer_create(65536);
    d_put(report, "{\n  \"schema\": \"openc.windows_x64_substrate.v1\",\n");
    d_put(report, "  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAILED"); }
    d_put(report, "\",\n  \"target\": \"windows-x86_64-hosted\",\n");
    d_put(report, "  \"data_model\": {\"name\": \"LLP64\", \"pointer_bits\": 64, \"usize_bits\": 64, \"c_int_bits\": 32, \"c_long_bits\": 32, \"c_long_long_bits\": 64, \"wchar_bits\": 16},\n");
    d_put(report, "  \"calling_convention\": {\"name\": \"microsoft_x64\", \"shadow_space_bytes\": 32, \"stack_alignment_bytes\": 16, \"stack_argument_slot_bytes\": 8, \"integer_arguments\": [\"rcx\", \"rdx\", \"r8\", \"r9\"], \"float_arguments\": [\"xmm0\", \"xmm1\", \"xmm2\", \"xmm3\"], \"integer_return\": \"rax\", \"float_return\": \"xmm0\", \"volatile_integer\": [\"rax\", \"rcx\", \"rdx\", \"r8\", \"r9\", \"r10\", \"r11\"], \"nonvolatile_integer\": [\"rbx\", \"rbp\", \"rsi\", \"rdi\", \"rsp\", \"r12\", \"r13\", \"r14\", \"r15\"], \"volatile_vector_range\": \"xmm0-xmm5\", \"nonvolatile_vector_range\": \"xmm6-xmm15\"},\n");
    d_put(report, "  \"classification\": {\n    \"stack_offset_base\": \"caller_rsp_before_call\",\n    \"mixed_arguments\": [");
    x64_report_location(report, mixed_zero); d_put(report, ",");
    x64_report_location(report, mixed_one); d_put(report, ",");
    x64_report_location(report, mixed_two); d_put(report, ",");
    x64_report_location(report, mixed_three); d_put(report, ",");
    x64_report_location(report, mixed_four);
    d_put(report, "],\n    \"direct_aggregate_return\": {\"kind\": \"");
    d_put(report, win64_location_kind_name(direct_return.kind));
    d_put(report, "\", \"register\": \"");
    d_put(report, win64_integer_register_name(direct_return.register_code));
    d_put(report, "\"},\n    \"hidden_aggregate_return\": {\"kind\": \"");
    d_put(report, win64_location_kind_name(hidden_return.kind));
    d_put(report, "\", \"register\": \"");
    d_put(report, win64_integer_register_name(hidden_return.register_code));
    d_put(report, "\", \"shifts_arguments\": ");
    x64_report_bool(report, hidden_return.shifts_arguments);
    d_put(report, "},\n    \"first_argument_after_hidden_return\": ");
    x64_report_location(report, shifted_first);
    d_put(report, "\n  },\n");

    d_put(report, "  \"frames\": {\"callback\": {\"fixed_allocation_bytes\": ");
    d_put_usize(report, callback_frame.fixed_allocation_bytes);
    d_put(report, ", \"shadow_bytes\": ");
    d_put_usize(report, callback_frame.shadow_bytes);
    d_put(report, ", \"body_alignment\": 16, \"requires_unwind\": true}, \"saved_rbx_callback\": {\"fixed_allocation_bytes\": ");
    d_put_usize(report, outer_frame.fixed_allocation_bytes);
    d_put(report, ", \"saved_integer_registers\": 1, \"body_alignment\": 16, \"requires_unwind\": true}},\n");

    d_put(report, "  \"layouts\": {\n    \"structure\": {\"size\": ");
    d_put_usize(report, structure_size); d_put(report, ", \"alignment\": ");
    d_put_usize(report, structure.alignment); d_put(report, ", \"fields\": [");
    x64_report_field_layout(report, structure_tag); d_put(report, ",");
    x64_report_field_layout(report, structure_pointer); d_put(report, ",");
    x64_report_field_layout(report, structure_long); d_put(report, "]},\n");
    d_put(report, "    \"union\": {\"size\": "); d_put_usize(report, union_size);
    d_put(report, ", \"alignment\": "); d_put_usize(report, union_layout.alignment);
    d_put(report, ", \"fields\": [");
    x64_report_field_layout(report, union_u32); d_put(report, ",");
    x64_report_field_layout(report, union_u64); d_put(report, "]},\n");
    d_put(report, "    \"explicit\": {\"size\": "); d_put_usize(report, explicit_size);
    d_put(report, ", \"fields\": [");
    x64_report_field_layout(report, explicit_tag); d_put(report, ",");
    x64_report_field_layout(report, explicit_value); d_put(report, "]},\n");
    d_put(report, "    \"bitfields\": {\"size\": "); d_put_usize(report, bits_size);
    d_put(report, ", \"fields\": [");
    x64_report_field_layout(report, bits_a); d_put(report, ",");
    x64_report_field_layout(report, bits_b); d_put(report, ",");
    x64_report_field_layout(report, bits_c); d_put(report, "]}\n  },\n");

    d_put(report, "  \"machine_code\": {\n");
    x64_report_code(report, "integer_six", integer_code, true);
    x64_report_code(report, "float_four", float_code, true);
    x64_report_code(report, "aggregate_pair", aggregate_code, true);
    x64_report_code(report, "indirect_aggregate", indirect_aggregate_code, true);
    x64_report_code(report, "hidden_aggregate_return", hidden_return_code, true);
    x64_report_code(report, "callback_call", callback_code, true);
    x64_report_code(report, "stack_alignment", alignment_code, true);
    x64_report_code(report, "nonvolatile_inner", inner_code, true);
    x64_report_code(report, "nonvolatile_outer", outer_code, true);
    x64_report_code(report, "variadic_float_duplicate", variadic_code, true);
    x64_report_code(report, "nonvolatile_vector_inner", vector_inner_code, true);
    x64_report_code(report, "nonvolatile_vector_outer", vector_outer_code, false);
    d_put(report, "  },\n");

    d_put(report, "  \"relocations\": {\n    \"relative32\": {\"symbol\": 7, \"offset\": 1, \"width\": 4, \"addend\": -4, \"unresolved_bytes\": ");
    x64_report_hex(report, relative_unresolved);
    d_put(report, ", \"resolved_target_offset\": 16, \"resolved_bytes\": ");
    x64_report_hex(report, relative.bytes);
    d_put(report, ", \"backward_resolved_bytes\": ");
    x64_report_hex(report, backward_relative.bytes);
    d_put(report, "},\n    \"absolute64\": {\"symbol\": 11, \"offset\": 2, \"width\": 8, \"addend\": 0, \"unresolved_bytes\": ");
    x64_report_hex(report, absolute_unresolved);
    d_put(report, ", \"resolved_value\": \"0x1122334455667788\", \"resolved_bytes\": ");
    x64_report_hex(report, absolute.bytes);
    d_put(report, "}\n  },\n");

    d_put(report, "  \"unwind\": {\"version\": 1, \"runtime_function_bytes\": ");
    x64_report_hex(report, runtime_record);
    d_put(report, ", \"callback_xdata\": "); x64_report_hex(report, callback_unwind);
    d_put(report, ", \"inner_xdata\": "); x64_report_hex(report, inner_unwind);
    d_put(report, ", \"outer_xdata\": "); x64_report_hex(report, outer_unwind);
    d_put(report, ", \"vector_xdata\": "); x64_report_hex(report, vector_unwind);
    d_put(report, ", \"runtime_functions_sorted\": true},\n");
    d_put(report, "  \"dependencies\": {\"c_headers_required_by_substrate\": false, \"external_assembler_required\": false, \"external_linker_required\": false, \"tinycc_exit_milestone\": \"SH-19\"}\n}\n");

    status written = file.write_text(output_path, d_buffer_text(report));
    bool report_ok = report.ok && written.ok;
    d_buffer_destroy(report);
    d_buffer_destroy(runtime_record);
    d_buffer_destroy(vector_unwind);
    d_buffer_destroy(outer_unwind);
    d_buffer_destroy(inner_unwind);
    d_buffer_destroy(callback_unwind);
    d_buffer_destroy(absolute_unresolved);
    x64_code_destroy(absolute);
    d_buffer_destroy(relative_unresolved);
    x64_code_destroy(relative);
    x64_code_destroy(backward_relative);
    x64_code_destroy(variadic_code);
    x64_code_destroy(vector_outer_code);
    x64_code_destroy(vector_inner_code);
    x64_code_destroy(outer_code);
    x64_code_destroy(inner_code);
    x64_code_destroy(alignment_code);
    x64_code_destroy(callback_code);
    x64_code_destroy(aggregate_code);
    x64_code_destroy(hidden_return_code);
    x64_code_destroy(indirect_aggregate_code);
    x64_code_destroy(float_code);
    x64_code_destroy(integer_code);
    if !passed || !report_ok {
        io.error("OPENC-SH15-SUBSTRATE-FAILED\n");
        return 1;
    }
    return 0;
}
