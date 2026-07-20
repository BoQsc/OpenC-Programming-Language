module apps.info_main;

import openc.compiler : Compiler;
import openc.project : ProjectConfig;
import openc.tools.info : commandInfo, projectInfo;
import std.stdio : stderr, stdout;

int main(string[] argv) {
    if (argv.length > 1 && argv[1].length >= 2 && argv[1][0 .. 2] == "--") {
        auto target = ProjectConfig.hostTarget();
        stdout.writeln(commandInfo(argv[1], target).toPrettyString());
        return 0;
    }
    auto path = argv.length > 1 ? argv[1] : "openc.project.json";
    auto project = ProjectConfig.load(path);
    if (!project.ok) { stderr.writeln(project.error); return 2; }
    auto compiler = new Compiler();
    stdout.writeln(projectInfo(project.value, compiler.compilerVersion).toPrettyString());
    return 0;
}
