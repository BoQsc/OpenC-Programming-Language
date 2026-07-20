module apps.validate_main;

import openc.compiler : Compiler;
import openc.tools.validator : FixtureRunner;
import std.algorithm.searching : endsWith;
import std.file : write;
import std.json : JSONValue;
import std.stdio : stderr, stdout;

int main(string[] argv) {
    if (argv.length < 2 || argv.length > 3) {
        stderr.writeln("usage: openc-validate <fixture-or-manifest.json> [report.json]");
        return 2;
    }
    auto runner = new FixtureRunner(new Compiler());
    auto report = argv[1].endsWith("MANIFEST.json")
        ? runner.runManifest(argv[1])
        : runner.run(argv[1]);
    auto text = report.toPrettyString() ~ "\n";
    if (argv.length == 3) write(argv[2], text);
    else stdout.write(text);
    if ("failed" in report.object) return report.object["failed"].integer == 0 ? 0 : 1;
    return report.object.get("passed", JSONValue(false)).boolean ? 0 : 1;
}
