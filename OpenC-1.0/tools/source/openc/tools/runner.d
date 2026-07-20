module openc.tools.runner;

import openc.common : Result;
import std.process : execute;

struct RunResult {
    int exitCode;
    string output;
}

Result!RunResult runExecutable(string executable, string[] arguments = []) {
    string[] command = [executable];
    command ~= arguments;
    try {
        auto result = execute(command);
        return Result!RunResult.success(RunResult(result.status, result.output));
    } catch (Exception error) {
        return Result!RunResult.failure("cannot execute program: " ~ error.msg);
    }
}
