module openc.platform.freestanding.startup;

import openc.runtime.freestanding : FreestandingHooks, installHooks;

extern(C) int openc_program_main();

extern(C) int openc_freestanding_start(FreestandingHooks hooks) {
    installHooks(hooks);
    return openc_program_main();
}
