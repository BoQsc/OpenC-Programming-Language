module openc.std.system_process;

import openc.runtime.process : arguments, exitProcess;
import openc.runtime.checked : opencTargetFault;
import openc.runtime.types : OpenCText, Status, i32, usize;

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

OpenCText executable_directory() {
    import std.file : thisExePath;
    import std.path : dirName;
    return dirName(thisExePath()).idup;
}

Status run(OpenCText command, out i32 exitCode, out OpenCText output) {
    import std.process : executeShell;
    try {
        auto result = executeShell(command);
        exitCode = cast(i32) result.status;
        output = result.output.idup;
        return Status.success();
    } catch (Exception error) {
        exitCode = -1;
        output = error.msg.idup;
        return Status.failure(13, error.msg.idup);
    }
}

noreturn exit(i32 code) {
    exitProcess(code);
}
