module apps.run_main;

import openc.tools.runner : runExecutable;
import std.stdio : stderr, stdout;

int main(string[] argv) {
    if (argv.length < 2) {
        stderr.writeln("usage: openc-run <executable> [arguments...]");
        return 2;
    }
    auto result = runExecutable(argv[1], argv.length > 2 ? argv[2 .. $] : []);
    if (!result.ok) { stderr.writeln(result.error); return 2; }
    stdout.write(result.value.output);
    return result.value.exitCode;
}
