module apps.info_main;

import openc.compiler : Compiler;
import openc.project : ProjectConfig;
import openc.tools.info : projectInfo;
import std.stdio : stderr, stdout;

int main(string[] argv) {
    auto path = argv.length > 1 ? argv[1] : "openc.project.json";
    auto project = ProjectConfig.load(path);
    if (!project.ok) { stderr.writeln(project.error); return 2; }
    auto compiler = new Compiler();
    stdout.writeln(projectInfo(project.value, compiler.compilerVersion).toPrettyString());
    return 0;
}
