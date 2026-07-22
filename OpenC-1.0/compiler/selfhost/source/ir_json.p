import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_emit_text_value(
    ref IrContext context,
    usize kind,
    usize one,
    usize two
) {
    if kind == 0 { io.print("\"\""); }
    else if kind == 1 { ir_json_slice(context.source, one, two); }
    else if kind == 2 { ir_json_text(ir_static_text(one)); }
    else if kind == 3 { ir_json_symbol_identity(context, one); }
    else if kind == 4 {
        io.print("\"");
        io.print(one);
        io.print("\"");
    } else if kind == 5 {
        io.print("\"");
        io.print(project_slice(context.source, one, two));
        io.print(":address\"");
    } else if kind == 6 {
        io.print("\"-");
        io.print(project_slice(context.source, one, two));
        io.print("\"");
    } else if kind == 7 {
        io.print("\"system.");
        io.print(project_slice(context.source, one, two));
        io.print("\"");
    } else if kind == 8 {
        io.print("\"");
        io.print(project_slice(
            context.project_source,
            read_record_field(
                context.module_data, context.module_index, 0
            ),
            read_record_field(
                context.module_data, context.module_index, 1
            )
        ));
        io.print(".");
        io.print(project_slice(context.source, one, two));
        io.print("\"");
    } else { io.print("\"\""); }
}

unsafe void ir_emit_immediate(
    ref IrContext context,
    usize kind,
    usize one,
    usize two
) {
    if kind == 0 { io.print("\"\""); }
    else if kind == 1 {
        io.print("\""); io.print(one); io.print("\"");
    } else if kind == 2 { ir_json_slice(context.source, one, two); }
    else if kind == 3 { io.print("\"bind\""); }
    else if kind == 4 { io.print("\"deref\""); }
    else { io.print("\"\""); }
}

unsafe void ir_emit_instruction_json(
    ref IrContext context,
    usize instruction
) {
    usize packed = read_record_field(
        context.instruction_data, instruction, 4
    );
    io.print("{\"length\":");
    io.print(resolution_span_length(packed));
    io.print(",\"opcode\":");
    ir_json_text(ir_opcode_text(read_record_field(
        context.instruction_data, instruction, 2
    )));
    io.print(",\"operands\":[");
    usize first = read_record_field(
        context.instruction_detail, instruction, 3
    );
    usize count = read_record_field(
        context.instruction_detail, instruction, 4
    );
    usize index = 0;
    while index < count {
        if index != 0 { io.print(","); }
        usize operand = first + index;
        io.print("{\"immediate\":");
        ir_emit_immediate(
            context,
            read_record_field(context.operand_data, operand, 1),
            read_record_field(context.operand_data, operand, 2),
            read_record_field(context.operand_data, operand, 3)
        );
        io.print(",\"value\":");
        io.print(read_record_field(context.operand_data, operand, 0));
        io.print("}");
        index = index + 1;
    }
    io.print("],\"result\":");
    io.print(read_record_field(context.instruction_data, instruction, 1));
    io.print(",\"source\":");
    io.print(context.source_record);
    io.print(",\"start\":");
    io.print(resolution_span_start(packed));
    io.print(",\"text\":");
    ir_emit_text_value(
        context,
        read_record_field(context.instruction_detail, instruction, 0),
        read_record_field(context.instruction_detail, instruction, 1),
        read_record_field(context.instruction_detail, instruction, 2)
    );
    io.print(",\"type\":");
    io.print(read_record_field(context.instruction_data, instruction, 3));
    io.print("}");
}

