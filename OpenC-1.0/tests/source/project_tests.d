module tests.project_tests;

import openc.project : ProjectConfig;
import std.file : tempDir, write;
import std.path : buildPath;

unittest {
    auto root = buildPath(tempDir(), "openc-project-source-test");
    auto source = buildPath(root, "main");
    auto project = buildPath(root, "openc.project.json");
    import std.file : mkdirRecurse;
    mkdirRecurse(root);
    write(source, "i32 main() { return 0; }\n");
    write(project,
        "{\n" ~
        "  \"edition\": \"1.0\",\n" ~
        "  \"profile\": \"standard\",\n" ~
        "  \"modules\": { \"app.main\": [\"main\"] }\n" ~
        "}\n");
    auto loaded = ProjectConfig.load(project);
    assert(loaded.ok);
    assert(loaded.value.modules.length == 1);
    assert(loaded.value.modules[0].name == "app.main");
    assert(loaded.value.outputDirectory == buildPath(root, "build"));
}
