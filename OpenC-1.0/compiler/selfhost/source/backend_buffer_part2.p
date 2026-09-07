import system.file;
import system.memory;
import system.path;
import system.text;

unsafe void d_put_value_type(
    ref IrContext context,
    ref DBuffer buffer,
    usize type_id
) {
    d_put_type(context, buffer, type_id);
    if type_id < context.types.length && read_record_field(
        context.type_data, type_id, 0
    ) == 12 { d_put(buffer, "*"); }
}

unsafe bool d_type_is_integer(ref IrContext context, usize type_id) {
    if type_id >= context.types.length { return false; }
    usize kind = read_record_field(context.type_data, type_id, 0);
    return kind == 2 || kind == 3 || kind == 6;
}

unsafe void d_put_instruction_text(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction
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
    if kind == 1 { d_put_slice(buffer, context.source, one, two); }
    else if kind == 2 { d_put(buffer, ir_static_text(one)); }
    else if kind == 3 { d_put_qualified_symbol(context, buffer, one, false); }
    else if kind == 4 { d_put_usize(buffer, one); }
    else if kind == 5 {
        d_put_slice(buffer, context.source, one, two);
        d_put(buffer, ":address");
    } else if kind == 6 {
        d_put(buffer, "-");
        d_put_slice(buffer, context.source, one, two);
    } else if kind == 7 {
        d_put(buffer, "system.");
        d_put_slice(buffer, context.source, one, two);
    } else if kind == 8 {
        d_put_module_name(context, buffer, context.module_index, false);
        d_put(buffer, ".");
        d_put_slice(buffer, context.source, one, two);
    }
}

unsafe bool d_instruction_text_is(
    ref IrContext context,
    usize instruction,
    text expected
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
    if kind == 1 || kind == 7 {
        return span_equals_ascii(context.source, one, two, expected);
    }
    if kind == 2 { return ir_static_text(one) == expected; }
    if kind == 3 { return d_symbol_name_is(context, one, expected); }
    return false;
}

unsafe bool d_instruction_address_field(
    ref IrContext context,
    usize instruction
) {
    usize kind = read_record_field(
        context.instruction_detail, instruction, 0
    );
    return kind == 5 || (kind == 2 && read_record_field(
        context.instruction_detail, instruction, 1
    ) == 4);
}

unsafe void d_put_call_name(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction
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
    if (kind == 3 && d_symbol_name_is(context, one, "saturating_add")) ||
        (kind != 3 && span_equals_ascii(
            context.source, one, two, "saturating_add"
        )) { d_put(buffer, "saturatingAdd"); return; }
    if (kind == 3 && d_symbol_name_is(context, one, "saturating_sub")) ||
        (kind != 3 && span_equals_ascii(
            context.source, one, two, "saturating_sub"
        )) { d_put(buffer, "saturatingSub"); return; }
    if (kind == 3 && d_symbol_name_is(context, one, "saturating_mul")) ||
        (kind != 3 && span_equals_ascii(
            context.source, one, two, "saturating_mul"
        )) { d_put(buffer, "saturatingMul"); return; }
    if kind == 7 {
        d_put(buffer, "openc.std.system_");
        d_put_slice(buffer, context.source, one, two);
        return;
    }
    if kind == 3 {
        d_put_qualified_symbol(context, buffer, one, true);
        return;
    }
    if kind == 8 {
        d_put_module_name(context, buffer, context.module_index, true);
        d_put(buffer, "_");
        d_put_mangled_slice(buffer, context.source, one, two);
        return;
    }
    if kind == 1 {
        d_put_mangled_slice(buffer, context.source, one, two);
    }
}

unsafe usize d_operand_first(ref IrContext context, usize instruction) {
    return read_record_field(context.instruction_detail, instruction, 3);
}

unsafe usize d_operand_count(ref IrContext context, usize instruction) {
    return read_record_field(context.instruction_detail, instruction, 4);
}

unsafe usize d_operand_value(
    ref IrContext context,
    usize instruction,
    usize index
) {
    return read_record_field(
        context.operand_data, d_operand_first(context, instruction) + index, 0
    );
}

unsafe bool d_operand_immediate_is(
    ref IrContext context,
    usize instruction,
    usize index,
    text expected
) {
    usize operand = d_operand_first(context, instruction) + index;
    usize kind = read_record_field(context.operand_data, operand, 1);
    if kind == 2 {
        return span_equals_ascii(
            context.source,
            read_record_field(context.operand_data, operand, 2),
            read_record_field(context.operand_data, operand, 3), expected
        );
    }
    if kind == 3 { return expected == "bind"; }
    if kind == 4 { return expected == "deref"; }
    return false;
}

unsafe void d_put_operand_immediate(
    ref IrContext context,
    ref DBuffer buffer,
    usize instruction,
    usize index
) {
    usize operand = d_operand_first(context, instruction) + index;
    usize kind = read_record_field(context.operand_data, operand, 1);
    if kind == 1 {
        d_put_usize(
            buffer, read_record_field(context.operand_data, operand, 2)
        );
    } else if kind == 2 || kind == 5 {
        d_put_slice(
            buffer, context.source,
            read_record_field(context.operand_data, operand, 2),
            read_record_field(context.operand_data, operand, 3)
        );
    } else if kind == 3 { d_put(buffer, "bind"); }
    else if kind == 4 { d_put(buffer, "deref"); }
}

unsafe bool d_parameter_owned(ref IrContext context, usize parameter) {
    return flow_parameter_own(
        context.project_source, context.project_root, context.source_data,
        context.symbol_data, context.detail_data, parameter
    );
}

unsafe usize d_parameter_count(ref IrContext context, usize function_symbol) {
    return ir_parameter_count(context, function_symbol);
}

unsafe usize d_parameter_at(
    ref IrContext context,
    usize function_symbol,
    usize requested
) {
    return ir_parameter_at(context, function_symbol, requested);
}

unsafe usize d_call_parameter_type(
    ref IrContext context,
    usize instruction,
    usize requested
) {
    if read_record_field(
        context.instruction_detail, instruction, 0
    ) != 3 { return semantic_type_error(); }
    usize function_symbol = read_record_field(
        context.instruction_detail, instruction, 1
    );
    usize parameter = d_parameter_at(context, function_symbol, requested);
    if parameter >= context.symbols.length { return semantic_type_error(); }
    return read_record_field(context.symbol_data, parameter, 4);
}
