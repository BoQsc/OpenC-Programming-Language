module openc.runtime.freestanding;

import openc.runtime.types : OpenCText, Status, i32, usize;

alias WriteHook = Status function(OpenCText text);
alias AllocateHook = void* function(usize size);
alias FreeHook = void function(void* pointer);
alias FaultHook = noreturn function(OpenCText message);

struct FreestandingHooks {
    WriteHook write;
    AllocateHook allocate;
    FreeHook release;
    FaultHook checkedFailure;
    FaultHook targetFault;
}

private FreestandingHooks hooks;

void installHooks(FreestandingHooks value) {
    hooks = value;
}

ref const(FreestandingHooks) currentHooks() {
    return hooks;
}
