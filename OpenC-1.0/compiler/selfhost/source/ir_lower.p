import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe usize ir_lower_node(
    ref IrContext context,
    usize node,
    usize expected,
    usize mode
) {
    if node >= context.syntax.length { return 0; }
    usize kind = read_record_field(context.syntax_data, node, 0);
    usize start = read_record_field(context.syntax_data, node, 1);
    usize length = read_record_field(context.syntax_data, node, 2);
    if mode != 0 {
        return ir_lower_mode(
            context, node, expected, mode, kind, start, length
        );
    }
    usize type_id = ir_node_type(context, node, expected);
    if kind <= 35 {
        return ir_lower_primary(
            context, node, expected, kind, start, length, type_id
        );
    }
    if kind <= 37 {
        return ir_lower_binary(
            context, node, expected, kind, start, length, type_id
        );
    }
    if kind <= 41 {
        return ir_lower_call_range(
            context, node, expected, kind, start, length, type_id
        );
    }
    if kind <= 47 {
        return ir_lower_conversion(
            context, node, expected, kind, start, length, type_id
        );
    }
    return ir_lower_construct(
        context, node, expected, kind, start, length, type_id
    );
}
