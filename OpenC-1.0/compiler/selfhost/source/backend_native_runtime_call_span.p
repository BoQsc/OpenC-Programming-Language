import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe DCompilerCallSpan native_runtime_call_span(
    ref IrContext context,
    usize kind,
    usize one,
    usize two
) {
    DCompilerCallSpan result = DCompilerCallSpan{
        found = false, source = "", start = 0, length = 0
    };
    if kind == 3 {
        if one >= context.symbols.length { return result; }
        result.source = d_symbol_source(context, one);
        if text.byte_length(result.source) == 0 { return result; }
        result.start = read_record_field(context.symbol_data, one, 2);
        result.length = read_record_field(context.symbol_data, one, 3);
        result.found = true;
        return result;
    }
    if kind == 2 {
        result.source = ir_static_text(one);
        result.length = text.byte_length(result.source);
        result.found = true;
        return result;
    }
    if kind != 1 && kind != 7 && kind != 8 { return result; }
    result.source = context.source;
    result.start = one;
    result.length = two;
    result.found = true;
    return result;
}
