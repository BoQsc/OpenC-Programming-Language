module apps.explain_main;

import openc.tools.explain : ExplanationDatabase;
import std.stdio : stderr, stdout;

int main(string[] argv) {
    if (argv.length < 2 || argv.length > 3) {
        stderr.writeln("usage: openc-explain <RULE-ID> [rule-index.json]");
        return 2;
    }
    auto index = argv.length == 3
        ? argv[2]
        : "standard/core/metadata/OpenC_Core_Rule_Index.json";
    auto database = ExplanationDatabase.load(index);
    if (!database.ok) { stderr.writeln(database.error); return 2; }
    auto result = database.value.find(argv[1]);
    if (!result.ok) { stderr.writeln(result.error); return 1; }
    stdout.write(result.value.render());
    return 0;
}
