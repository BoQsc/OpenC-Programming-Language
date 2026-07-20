module tests.tool_tests;

import openc.command : normalize;
import openc.tools.formatter : Formatter;
import openc.project : ProjectConfig;
import openc.tools.info : commandInfo;
import std.algorithm.searching : endsWith;

unittest {
    auto request = normalize(["check", "main", "--profile=strict", "--diagnostics-format", "jsonl"]);
    assert(request.ok);
    assert(request.value.command == "check");
    assert(request.value.positionals == ["main"]);
    assert(request.value.option("profile") == "strict");
    assert(request.value.option("diagnostics_format") == "jsonl");
}

unittest {
    auto target = commandInfo("--target", ProjectConfig.hostTarget());
    assert(target.object["pointer_bits"].integer > 0);
    assert(target.object["unsafe_fault_model"].str == "bounded-target-fault");
    auto limits = commandInfo("--limits", ProjectConfig.hostTarget());
    assert(limits.object["usize_bits"] == limits.object["isize_bits"]);
}

unittest {
    auto request = normalize(["check(file=\"main\", profile=\"strict\")"]);
    assert(request.ok);
    assert(request.value.command == "check");
    assert(request.value.option("file") == "main");
    assert(request.value.option("profile") == "strict");
}

unittest {
    auto formatted = new Formatter().format("i32 main(){i32 x=1;return x;}");
    assert(formatted.ok);
    assert(formatted.value.endsWith("\n"));
}
