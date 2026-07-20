module openc.tools.validator;

import openc.compiler : CompilationOptions, Compiler;
import openc.project : ProjectConfig, ProjectModule;
import std.algorithm : sort;
import std.file : exists, readText;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : absolutePath, baseName, buildNormalizedPath, buildPath, dirName;

final class FixtureRunner {
private:
    Compiler compiler;
    string repositoryRoot;

public:
    this(Compiler compiler, string repositoryRoot = ".") {
        this.compiler = compiler;
        this.repositoryRoot = findRepositoryRoot(repositoryRoot);
    }

    JSONValue run(string fixturePath) {
        auto absolute = buildNormalizedPath(absolutePath(fixturePath));
        auto fixture = parseJSON(readText(absolute));
        return runFixture(fixture, dirName(absolute));
    }

    JSONValue runManifest(string manifestPath) {
        auto absolute = buildNormalizedPath(absolutePath(manifestPath));
        auto manifest = parseJSON(readText(absolute));
        JSONValue[] results;
        size_t passed;
        size_t infrastructureFailures;
        foreach (entry; manifest.object["fixtures"].array) {
            JSONValue result;
            try {
                string fixtureFile;
                if (entry.type == JSONType.string) {
                    fixtureFile = buildPath(repositoryRoot, entry.str);
                } else {
                    auto path = entry.object.get("path", JSONValue("")).str;
                    fixtureFile = buildPath(repositoryRoot, path, "fixture.json");
                }
                result = run(fixtureFile);
            } catch (Exception error) {
                result["passed"] = false;
                result["infrastructure_error"] = error.msg;
            }
            if (result.object.get("passed", JSONValue(false)).boolean) ++passed;
            if ("infrastructure_error" in result.object) ++infrastructureFailures;
            results ~= result;
        }
        JSONValue report;
        report["schema"] = "openc.conformance_result.v2";
        report["evidence_state"] = "EXECUTED";
        report["total"] = cast(long) results.length;
        report["passed"] = cast(long) passed;
        report["failed"] = cast(long) (results.length - passed - infrastructureFailures);
        report["infrastructure_failures"] = cast(long) infrastructureFailures;
        report["implementation"] = compiler.compilerVersion.toJson();
        report["results"] = JSONValue(results);
        return report;
    }

private:
    JSONValue runFixture(JSONValue fixture, string fixtureRoot) {
        auto object = fixture.object;
        auto expectedRecord = object.get("expected", JSONValue());
        auto nestedExpected = expectedRecord.type == JSONType.object
            ? expectedRecord.object.get("expected", JSONValue())
            : JSONValue();
        auto expected = nestedExpected.type == JSONType.object
            ? nestedExpected.object.get("result", JSONValue("accept")).str
            : "accept";
        auto expectedRule = nestedExpected.type == JSONType.object
            ? nestedExpected.object.get("rule", JSONValue("")).str
            : "";
        auto fixtureKind = expectedRecord.type == JSONType.object
            ? expectedRecord.object.get("fixture_kind", object.get("kind", JSONValue("source"))).str
            : object.get("kind", JSONValue("source")).str;

        auto project = projectForFixture(fixture, fixtureRoot);
        CompilationOptions options;
        options.stopAfterCheck = fixtureKind != "runtime";
        auto compiled = compiler.compile(project, options);

        JSONValue result;
        result["fixture"] = object.get("id", JSONValue(fixtureRoot)).str;
        result["fixture_kind"] = fixtureKind;
        result["expected"] = expected;
        result["expected_rule"] = expectedRule;
        result["implementation"] = compiler.compilerVersion.toJson();
        if (!compiled.ok) {
            result["passed"] = false;
            result["infrastructure_error"] = compiled.error;
            return result;
        }

        auto compilation = compiled.value;
        bool accepted = compilation.success();
        bool outcome = expected == "accept" ? accepted : !accepted;
        bool ruleMatched = !expectedRule.length;
        foreach (diagnostic; compilation.diagnostics.all()) {
            if (diagnostic.rule == expectedRule) ruleMatched = true;
        }
        result["accepted"] = accepted;
        result["rule_matched"] = ruleMatched;
        result["passed"] = outcome && ruleMatched;
        result["diagnostics"] = compilation.diagnostics.toJson(compilation.sources);
        if (fixtureKind == "runtime") {
            result["runtime_execution"] = "PENDING_TOOLCHAIN_EXECUTION";
            result["passed"] = false;
            result["infrastructure_error"] = "runtime fixture requires build-and-run provider integration";
        }
        return result;
    }

    ProjectConfig projectForFixture(JSONValue fixture, string fixtureRoot) {
        auto object = fixture.object;
        ProjectConfig config;
        config.path = buildPath(fixtureRoot, "fixture.json");
        config.root = repositoryRoot;
        config.edition = "1.0";
        auto expected = object.get("expected", JSONValue());
        if (expected.type == JSONType.object) {
            config.profile = expected.object.get("profile", JSONValue("standard")).str;
        }
        config.outputDirectory = buildPath(repositoryRoot, "build-output", "conformance");

        string[string] sourcesByLeaf;
        foreach (source; object.get("source_files", JSONValue(JSONValue[].init)).array) {
            auto path = buildNormalizedPath(repositoryRoot, source.str);
            sourcesByLeaf[baseName(path)] = path;
        }

        auto modulesValue = expected.type == JSONType.object
            ? expected.object.get("modules", JSONValue())
            : JSONValue();
        if (modulesValue.type == JSONType.object) {
            foreach (moduleName, sourceNames; modulesValue.object) {
                ProjectModule moduleConfig;
                moduleConfig.name = moduleName;
                foreach (sourceName; sourceNames.array) {
                    auto found = sourceName.str in sourcesByLeaf;
                    if (found is null) {
                        throw new Exception("fixture module source not found: " ~ sourceName.str);
                    }
                    moduleConfig.sources ~= *found;
                }
                config.modules ~= moduleConfig;
            }
        } else {
            ProjectModule moduleConfig;
            moduleConfig.name = "fixture.main";
            foreach (leaf, path; sourcesByLeaf) moduleConfig.sources ~= path;
            moduleConfig.sources.sort();
            config.modules ~= moduleConfig;
        }
        config.modules.sort!((a, b) => a.name < b.name);
        return config;
    }

    string findRepositoryRoot(string start) {
        auto current = buildNormalizedPath(absolutePath(start));
        while (current.length) {
            if (exists(buildPath(current, "AUTHORITY.md")) && exists(buildPath(current, "standard"))) {
                return current;
            }
            auto parent = dirName(current);
            if (parent == current) break;
            current = parent;
        }
        return buildNormalizedPath(absolutePath(start));
    }
}
