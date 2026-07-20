module openc.std.system_process;

import openc.runtime.process : arguments, exitProcess;
import openc.runtime.types : OpenCText, i32;

OpenCText[] args() {
    return arguments();
}

noreturn exit(i32 code) {
    exitProcess(code);
}
