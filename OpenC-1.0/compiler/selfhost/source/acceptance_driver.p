import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

void acceptance_report_count(
    text category,
    usize source_record,
    usize count
) {
    if count == 0 { return; }
    io.print("ACCEPTANCE_ERROR ");
    io.print(category);
    io.print(" ");
    io.print(source_record);
    io.print(" ");
    io.println(count);
}

unsafe void acceptance_report_node(
    ref IrContext context,
    text category,
    text reason,
    usize node
) {
    io.print("ACCEPTANCE_DETAIL ");
    io.print(category);
    io.print(" ");
    io.print(reason);
    io.print(" ");
    io.print(context.source_record);
    io.print(" ");
    if node < context.syntax.length {
        io.print(read_record_field(context.syntax_data, node, 1));
        io.print(" ");
        io.println(read_record_field(context.syntax_data, node, 2));
    } else {
        io.println("0 0");
    }
}

unsafe void acceptance_mask_external_declarations(ref IrContext context) {
    usize declaration = 0;
    while declaration < context.syntax.length {
        if read_record_field(context.syntax_data, declaration, 0) == 2 {
            usize start = read_record_field(
                context.syntax_data, declaration, 1
            );
            if starts_with_ascii(context.source, start, "external") {
                usize child = 0;
                while child < context.syntax.length {
                    if child == declaration || semantic_node_contains(
                        context.syntax_data, declaration, child
                    ) {
                        write_record_field(
                            context.syntax_data, child, 0, 0
                        );
                    }
                    child = child + 1;
                }
            }
        }
        declaration = declaration + 1;
    }
}
