module openc.std.system_process;

import openc.runtime.process : arguments, exitProcess;
import openc.runtime.checked : opencTargetFault;
import openc.runtime.types : OpenCText, i32, usize;

OpenCText[] args() {
    return arguments();
}

usize argument_count() {
    return arguments().length;
}

OpenCText argument(usize index) {
    auto values = arguments();
    if (index >= values.length) opencTargetFault("process argument index out of bounds");
    return values[index];
}

OpenCText current_directory() {
    import std.file : getcwd;
    return getcwd().idup;
}

noreturn exit(i32 code) {
    exitProcess(code);
}
