import system.file;
import system.memory;
import system.path;
import system.text;

unsafe void c_put_call_name(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    ptr byte value_types
) {
    usize kind = read_record_field(
        context.instruction_detail, instruction, 0
    );
    usize one = read_record_field(
        context.instruction_detail, instruction, 1
    );
    usize two = read_record_field(
        context.instruction_detail, instruction, 2
    );
    CExternalLinkSpan external_span = c_external_link_span(context, one);
    if kind == 3 && external_span.found {
        d_put_slice(
            buffer, context.source, external_span.start, external_span.length
        );
        return;
    }
    DCompilerCallSpan compiler = d_compiler_call_span(
        context, kind, one, two
    );
    bool compiler_name = compiler.found;
    text compiler_source = compiler.source;
    usize compiler_start = compiler.start;
    usize compiler_length = compiler.length;
    bool compiler_constant = d_compiler_call_prefix_is(
        context, kind, one, two, "ir_op_"
    );
    if !compiler_constant && d_compiler_call_prefix_is(
        context, kind, one, two, "flow_rule_"
    ) {
        compiler_constant = !(compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "flow_rule_text"
        ));
    }
    if !compiler_constant && d_compiler_call_prefix_is(
        context, kind, one, two, "flow_phase_"
    ) {
        compiler_constant = !(compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "flow_phase_text"
        ));
    }
    if !compiler_constant && d_compiler_call_prefix_is(
        context, kind, one, two, "resolution_symbol_"
    ) {
        compiler_constant = !(compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "resolution_symbol_name_equals"
        )) && !(compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "resolution_symbol_kind_name"
        ));
    }
    if compiler_constant {
        d_put(buffer, "ocb_compiler_");
        d_put_compiler_call_short_name(context, buffer, kind, one, two);
        return;
    }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_type_error"
        )) { d_put(buffer, "ocb_compiler_semantic_type_error"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_type_void"
        )) { d_put(buffer, "ocb_compiler_semantic_type_void"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_type_bool"
        )) { d_put(buffer, "ocb_compiler_semantic_type_bool"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_type_byte"
        )) { d_put(buffer, "ocb_compiler_semantic_type_byte"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_type_text"
        )) { d_put(buffer, "ocb_compiler_semantic_type_text"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_type_status"
        )) { d_put(buffer, "ocb_compiler_semantic_type_status"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_builtin_type"
        )) { d_put(buffer, "ocb_compiler_semantic_builtin_type"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_derived_type"
        )) { d_put(buffer, "ocb_compiler_semantic_derived_type"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "flow_statement_kind"
        )) { d_put(buffer, "ocb_compiler_flow_statement_kind"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "flow_expression_kind"
        )) { d_put(buffer, "ocb_compiler_flow_expression_kind"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "resolution_expression_kind"
        )) { d_put(buffer, "ocb_compiler_resolution_expression_kind"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "flow_node_operator"
        )) { d_put(buffer, "ocb_compiler_flow_node_operator"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_type_element"
        )) { d_put(buffer, "ocb_compiler_ir_type_element"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "acceptance_kind"
        )) { d_put(buffer, "ocb_compiler_acceptance_kind"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "acceptance_integer"
        )) { d_put(buffer, "ocb_compiler_acceptance_integer"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "d_put_byte"
        )) { d_put(buffer, "ocb_compiler_d_put_byte"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "d_put"
        )) { d_put(buffer, "ocb_compiler_d_put"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "d_put_slice"
        )) { d_put(buffer, "ocb_compiler_d_put_slice"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "d_put_mangled_slice"
        )) { d_put(buffer, "ocb_compiler_d_put_mangled_slice"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "d_put_usize"
        )) { d_put(buffer, "ocb_compiler_d_put_usize"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "record_stride"
        )) { d_put(buffer, "ocb_compiler_record_stride"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "read_usize"
        )) { d_put(buffer, "ocb_compiler_read_usize"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "write_usize"
        )) { d_put(buffer, "ocb_compiler_write_usize"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "read_record_field"
        )) { d_put(buffer, "ocb_compiler_read_record_field"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "write_record_field"
        )) { d_put(buffer, "ocb_compiler_write_record_field"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "byte_at_or_zero"
        )) { d_put(buffer, "ocb_compiler_byte_at_or_zero"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_node_contains"
        )) { d_put(buffer, "ocb_compiler_node_contains"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "starts_with_ascii"
        )) { d_put(buffer, "ocb_compiler_starts_with_ascii"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "span_equals_ascii"
        )) { d_put(buffer, "ocb_compiler_span_equals_ascii"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "semantic_spans_equal"
        )) { d_put(buffer, "ocb_compiler_semantic_spans_equal"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "flow_span_has_byte"
        )) { d_put(buffer, "ocb_compiler_flow_span_has_byte"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "project_slice"
        )) { d_put(buffer, "ocb_compiler_project_slice"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "resolution_pack_span"
        )) { d_put(buffer, "ocb_compiler_pack_span"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_add_block"
        )) { d_put(buffer, "ocb_compiler_ir_add_block"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_add_operand"
        )) { d_put(buffer, "ocb_compiler_ir_add_operand"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_operand_empty"
        )) { d_put(buffer, "ocb_compiler_ir_operand_empty"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_operand_block"
        )) { d_put(buffer, "ocb_compiler_ir_operand_block"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_emit_instruction"
        )) { d_put(buffer, "ocb_compiler_ir_emit_instruction"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_emit_value"
        )) { d_put(buffer, "ocb_compiler_ir_emit_value"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_emit_void"
        )) { d_put(buffer, "ocb_compiler_ir_emit_void"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_block_parent"
        )) { d_put(buffer, "ocb_compiler_ir_block_parent"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_control_parent"
        )) { d_put(buffer, "ocb_compiler_ir_control_parent"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_resolve_name"
        )) { d_put(buffer, "ocb_compiler_ir_resolve_name"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_select_call"
        )) { d_put(buffer, "ocb_compiler_ir_select_call"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_node_type"
        )) { d_put(buffer, "ocb_compiler_ir_node_type"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_left_expression"
        )) { d_put(buffer, "ocb_compiler_ir_left_expression"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_right_expression"
        )) { d_put(buffer, "ocb_compiler_ir_right_expression"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_root_in_bounds"
        )) { d_put(buffer, "ocb_compiler_ir_root_in_bounds"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "ir_first_name"
        )) { d_put(buffer, "ocb_compiler_ir_first_name"); return; }
    if (compiler_name && span_equals_ascii(
            compiler_source, compiler_start, compiler_length, "c_parallel_jobs"
        )) { d_put(buffer, "ocb_compiler_parallel_jobs"); return; }
    if kind == 3 {
        c_put_qualified_symbol(context, buffer, one);
        return;
    }
    if c_builtin_is(context, instruction, "io.print", "system.io.print") {
        c_put_io_name(context, buffer, instruction, value_types, false);
        return;
    }
    if c_builtin_is(context, instruction, "io.println", "system.io.println") {
        c_put_io_name(context, buffer, instruction, value_types, true);
        return;
    }
    if c_builtin_is(context, instruction, "io.error", "system.io.error") {
        d_put(buffer, "ocb_io_error"); return;
    }
    if c_builtin_is(context, instruction, "memory.alloc", "system.memory.alloc") {
        d_put(buffer, "ocb_memory_alloc"); return;
    }
    if c_builtin_is(context, instruction, "memory.free", "system.memory.free") {
        d_put(buffer, "ocb_memory_free"); return;
    }
    if c_builtin_is(context, instruction, "memory.load_usize", "system.memory.load_usize") {
        d_put(buffer, "ocb_memory_load_usize"); return;
    }
    if c_builtin_is(context, instruction, "memory.store_usize", "system.memory.store_usize") {
        d_put(buffer, "ocb_memory_store_usize"); return;
    }
    if c_builtin_is(context, instruction, "text.byte_length", "system.text.byte_length") {
        d_put(buffer, "ocb_text_byte_length"); return;
    }
    if c_builtin_is(context, instruction, "text.byte_at_unchecked", "system.text.byte_at_unchecked") {
        d_put(buffer, "ocb_text_byte_at_unchecked"); return;
    }
    if c_builtin_is(context, instruction, "text.copy_utf8_unchecked", "system.text.copy_utf8_unchecked") {
        d_put(buffer, "oc_text_copy_utf8_unchecked"); return;
    }
    if c_builtin_is(context, instruction, "text.copy_utf8_slice_unchecked", "system.text.copy_utf8_slice_unchecked") {
        d_put(buffer, "oc_text_copy_utf8_slice_unchecked"); return;
    }
    if c_builtin_is(context, instruction, "text.from_utf8", "system.text.from_utf8") {
        d_put(buffer, "ocb_text_from_utf8"); return;
    }
    if c_builtin_is(context, instruction, "text.slice", "system.text.slice") {
        d_put(buffer, "ocb_text_slice"); return;
    }
    if c_builtin_is(context, instruction, "text.equal", "system.text.equal") {
        d_put(buffer, "ocb_text_equal"); return;
    }
    if c_builtin_is(context, instruction, "text.compare", "system.text.compare") {
        d_put(buffer, "ocb_text_compare"); return;
    }
    if c_builtin_is(context, instruction, "file.read_text", "system.file.read_text") {
        d_put(buffer, "ocb_file_read_text"); return;
    }
    if c_builtin_is(context, instruction, "file.read_text_cached", "system.file.read_text_cached") {
        d_put(buffer, "ocb_file_read_text_cached"); return;
    }
    if c_builtin_is(context, instruction, "file.read_bytes", "system.file.read_bytes") {
        d_put(buffer, "ocb_file_read_bytes"); return;
    }
    if c_builtin_is(context, instruction, "file.read_bytes_raw", "system.file.read_bytes_raw") {
        d_put(buffer, "ocb_file_read_bytes_raw"); return;
    }
    if c_builtin_is(context, instruction, "file.write_text", "system.file.write_text") {
        d_put(buffer, "ocb_file_write_text"); return;
    }
    if c_builtin_is(context, instruction, "file.write_bytes", "system.file.write_bytes") {
        d_put(buffer, "ocb_file_write_bytes"); return;
    }
    if c_builtin_is(context, instruction, "path.join", "system.path.join") {
        d_put(buffer, "ocb_path_join"); return;
    }
    if c_builtin_is(context, instruction, "path.directory", "system.path.directory") {
        d_put(buffer, "ocb_path_directory"); return;
    }
    if c_builtin_is(context, instruction, "process.argument_count", "system.process.argument_count") {
        d_put(buffer, "ocb_process_argument_count"); return;
    }
    if c_builtin_is(context, instruction, "process.monotonic_milliseconds", "system.process.monotonic_milliseconds") {
        d_put(buffer, "ocb_process_monotonic_milliseconds"); return;
    }
    if c_builtin_is(context, instruction, "process.argument", "system.process.argument") {
        d_put(buffer, "ocb_process_argument"); return;
    }
    if c_builtin_is(context, instruction, "process.executable_directory", "system.process.executable_directory") {
        d_put(buffer, "ocb_process_executable_directory"); return;
    }
    if c_builtin_is(context, instruction, "process.executable_path", "system.process.executable_path") {
        d_put(buffer, "ocb_process_executable_path"); return;
    }
    if c_builtin_is(context, instruction, "process.run", "system.process.run") {
        d_put(buffer, "ocb_process_run"); return;
    }
    if kind == 3 {
        c_put_qualified_symbol(context, buffer, one);
    } else if kind == 8 {
        d_put(buffer, "oc_");
        d_put_module_name(context, buffer, context.module_index, true);
        d_put(buffer, "_");
        d_put_mangled_slice(buffer, context.source, one, two);
    } else {
        d_put(buffer, "oc_");
        d_put_mangled_slice(buffer, context.source, one, two);
    }
}

unsafe void c_put_lhs(ref DBuffer buffer, usize result) {
    d_put(buffer, "    v"); d_put_usize(buffer, result);
    d_put(buffer, " = ");
}
