import system.file;
import system.memory;
import system.path;
import system.text;

unsafe void d_emit_header(
    ref IrContext context,
    ref DBuffer buffer,
    text module_name
) {
    d_put(buffer, "module generated.");
    d_put_mangled_slice(buffer, module_name, 0, text.byte_length(module_name));
    d_put(buffer, ";\n\n");
    d_put(buffer, "import openc.runtime.types;\n");
    d_put(buffer, "import openc.runtime.checked;\n");
    d_put(buffer, "import openc.runtime.process : initializeArguments;\n");
    d_put(buffer, "import openc.std.system_file;\n");
    d_put(buffer, "import openc.std.system_io;\n");
    d_put(buffer, "import openc.std.system_memory;\n");
    d_put(buffer, "import openc.std.system_path;\n");
    d_put(buffer, "import openc.std.system_process;\n");
    d_put(buffer, "import openc.std.system_text;\n\n");
}

unsafe bool d_write_buffer(
    text output_directory,
    text module_name,
    ref DBuffer buffer
) {
    if !buffer.ok { return false; }
    DBuffer name = d_buffer_create(text.byte_length(module_name) + 4);
    d_put_mangled_slice(name, module_name, 0, text.byte_length(module_name));
    d_put(name, ".d");
    text file_name = d_buffer_text(name);
    text output_path = path.join(output_directory, file_name);
    status written = file.write_text(output_path, d_buffer_text(buffer));
    d_buffer_destroy(name);
    return written.ok;
}

unsafe bool d_emit_builtin_module(
    ref IrContext context,
    text output_directory,
    text module_name
) {
    if project_find_module(
        context.project_source, context.module_data,
        context.modules, module_name
    ) >= 0 { return true; }
    DBuffer buffer = d_buffer_create(2048);
    d_emit_header(context, buffer, module_name);
    bool written = d_write_buffer(output_directory, module_name, buffer);
    d_buffer_destroy(buffer);
    return written;
}
