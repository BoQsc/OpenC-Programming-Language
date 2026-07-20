module openc.conformance;

import openc.common : Result;
import openc.compiler : CompilationOptions, Compiler;
import openc.project : ProjectConfig;
import std.file : mkdirRecurse, readText, tempDir, write;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : buildPath;

final class ConformanceAdapter {
private:
    Compiler compiler;

public:
    this(Compiler compiler) {
        this.compiler = compiler;
    }

    Result!JSONValue execute(string requestPath) {
        JSONValue request;
        try request = parseJSON(readText(requestPath));
        catch (Exception error) return Result!JSONValue.failure("cannot read conformance request: " ~ error.msg);
        if (request.type != JSONType.object) {
            return Result!JSONValue.failure("conformance request must be a JSON object");
        }
        auto object = request.object;
        auto kind = object.get("kind", JSONValue("source")).str;
        auto expected = object.get("expected", JSONValue("accept")).str;
        auto expectedRule = object.get("expected_rule", JSONValue("")).str;
        auto projectResult = projectForRequest(object);
        if (!projectResult.ok) return Result!JSONValue.failure(projectResult.error);

        CompilationOptions options;
        options.stopAfterCheck = kind != "runtime";
        options.backend = object.get("backend", JSONValue("d-source")).str;
        options.outputDirectory = object.get("output_directory", JSONValue("build-output/adapter")).str;
        auto compiled = compiler.compile(projectResult.value, options);
        if (!compiled.ok) return Result!JSONValue.failure(compiled.error);

        auto result = compiled.value;
        bool accepted = result.success();
        bool outcome = expected == "accept" ? accepted : !accepted;
        bool ruleMatched = !expectedRule.length;
        foreach (diagnostic; result.diagnostics.all()) {
            if (diagnostic.rule == expectedRule) ruleMatched = true;
        }

        JSONValue response;
        response["schema"] = "openc.adapter_result.v2";
        response["kind"] = kind;
        response["expected"] = expected;
        response["expected_rule"] = expectedRule;
        response["accepted"] = accepted;
        response["rule_matched"] = ruleMatched;
        response["passed"] = outcome && ruleMatched && kind != "runtime";
        response["implementation"] = compiler.compilerVersion.toJson();
        response["diagnostics"] = result.diagnostics.toJson(result.sources);
        if (kind == "runtime") {
            response["runtime_execution"] = "PENDING_TOOLCHAIN_EXECUTION";
            response["passed"] = false;
        }
        return Result!JSONValue.success(response);
    }

private:
    Result!ProjectConfig projectForRequest(JSONValue[string] object) {
        auto projectPath = object.get("project", JSONValue("")).str;
        if (projectPath.length) return ProjectConfig.load(projectPath);

        auto sourcePath = object.get("source_path", JSONValue("")).str;
        if (sourcePath.length) {
            return Result!ProjectConfig.success(ProjectConfig.singleSource(
                sourcePath,
                object.get("module", JSONValue("fixture.main")).str));
        }

        auto source = object.get("source", JSONValue("")).str;
        if (!source.length) return Result!ProjectConfig.failure("request must contain project, source_path, or source");
        auto directory = buildPath(tempDir(), "openc-conformance-adapter");
        try mkdirRecurse(directory);
        catch (Exception error) return Result!ProjectConfig.failure(error.msg);
        auto path = buildPath(directory, "source");
        try write(path, source);
        catch (Exception error) return Result!ProjectConfig.failure(error.msg);
        return Result!ProjectConfig.success(ProjectConfig.singleSource(
            path,
            object.get("module", JSONValue("fixture.main")).str));
    }
}
