import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct NativeProcessPatches {
    usize pipe_failure_finished;
    usize inheritance_failure_finished;
    usize process_failure_finished;
    usize working_set_failure_finished;
    usize time_failure_finished;
    usize output_failure_finished;
}

unsafe void native_process_run(
    ref IrContext context, ref NativeFunction function, usize instruction,
    usize result
) {
    NativeProcessPatches patches = native_process_setup(
        context, function, instruction, result
    );
    native_process_supervise(function);
    native_process_results(context, function, instruction, result, patches);
    native_skip_end(function.code, patches.pipe_failure_finished);
    native_skip_end(function.code, patches.inheritance_failure_finished);
    native_skip_end(function.code, patches.process_failure_finished);
    native_skip_end(function.code, patches.working_set_failure_finished);
    native_skip_end(function.code, patches.time_failure_finished);
    native_skip_end(function.code, patches.output_failure_finished);
}
