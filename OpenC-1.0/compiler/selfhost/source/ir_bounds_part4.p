import system.file;
import system.io;
import system.memory;
import system.path;
import system.text;

unsafe void ir_operand_empty(ref IrContext context, usize value) {
    ir_add_operand(context, value, 0, 0, 0);
}

unsafe void ir_operand_block(ref IrContext context, usize block) {
    ir_add_operand(context, 0, 1, block, 0);
}
