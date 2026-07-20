module openc.runtime.console;

import openc.runtime.types : OpenCText, Status, i32, usize;
import std.stdio : stdout, stderr;

Status writeStdout(OpenCText text) {
    try {
        stdout.write(text);
        stdout.flush();
        return Status.success();
    } catch (Exception error) {
        return Status.failure(1, error.msg.idup);
    }
}

Status writeStderr(OpenCText text) {
    try {
        stderr.write(text);
        stderr.flush();
        return Status.success();
    } catch (Exception error) {
        return Status.failure(1, error.msg.idup);
    }
}

Status writeLine(OpenCText text) {
    auto status = writeStdout(text);
    if (!status.ok) return status;
    return writeStdout("\n");
}
