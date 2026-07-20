module openc.runtime.process;

import openc.runtime.types : OpenCText, i32, usize;
import core.stdc.stdlib : exit;

private string[] cachedArguments;

void initializeArguments(string[] arguments) {
    cachedArguments = arguments.dup;
}

OpenCText[] arguments() {
    OpenCText[] result;
    foreach (argument; cachedArguments) result ~= argument.idup;
    return result;
}

noreturn exitProcess(i32 code) {
    exit(code);
}
