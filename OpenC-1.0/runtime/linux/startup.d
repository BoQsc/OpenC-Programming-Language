module openc.platform.linux.startup;

import openc.runtime.process : initializeArguments;

extern(C) int openc_program_main();

int main(string[] args) {
    initializeArguments(args);
    return openc_program_main();
}
