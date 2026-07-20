module openc.tools.validator;

import openc.compiler : CompilationOptions, CompilationResult, Compiler;
import openc.project : ProjectConfig, ProjectModule;
import openc.toolchain : DToolchain;
import openc.tools.info : commandInfo;
import std.algorithm : sort;
import std.algorithm.searching : canFind;
import std.file : exists, readText;
import std.json : JSONType, JSONValue, parseJSON;
import std.path : absolutePath, baseName, buildNormalizedPath, buildPath, dirName;
import std.process : execute;
import std.string : indexOf, replace, startsWith;

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
        if (nestedExpected.type != JSONType.object && expectedRecord.type == JSONType.object &&
            "result" in expectedRecord.object) nestedExpected = expectedRecord;
        auto expected = nestedExpected.type == JSONType.object
            ? nestedExpected.object.get("result", JSONValue("accept")).str
            : "accept";
        auto expectedRule = nestedExpected.type == JSONType.object
            ? nestedExpected.object.get("rule", JSONValue("")).str
            : "";
        if (!expectedRule.length && nestedExpected.type == JSONType.object) {
            auto rules = nestedExpected.object.get("rules", JSONValue());
            if (rules.type == JSONType.array && rules.array.length) expectedRule = rules.array[0].str;
        }
        auto fixtureKind = expectedRecord.type == JSONType.object
            ? expectedRecord.object.get("fixture_kind", object.get("kind", JSONValue("source"))).str
            : object.get("kind", JSONValue("source")).str;

        if (fixtureKind == "command") return runCommandFixture(object, fixtureRoot);
        if (fixtureKind == "record") return runRecordFixture(object, fixtureRoot);

        auto project = projectForFixture(fixture, fixtureRoot);
        CompilationOptions options;
        options.stopAfterCheck = fixtureKind != "runtime";
        options.outputDirectory = project.outputDirectory;
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
        bool outcome = expected == "accept" ? accepted :
            expected == "warning" ? accepted : !accepted;
        bool ruleMatched = !expectedRule.length;
        bool compatibilityMatch;
        foreach (diagnostic; compilation.diagnostics.all()) {
            if (diagnostic.rule == expectedRule) ruleMatched = true;
            else if (ruleEquivalent(expectedRule, diagnostic.rule)) {
                ruleMatched = true;
                compatibilityMatch = true;
            }
        }
        result["accepted"] = accepted;
        result["rule_matched"] = ruleMatched;
        result["rule_matched_via_edition_compatibility"] = compatibilityMatch;
        result["passed"] = outcome && ruleMatched;
        result["diagnostics"] = compilation.diagnostics.toJson(compilation.sources);
        if (fixtureKind == "runtime") runRuntime(
            result, object, nestedExpected, project, compilation, accepted, expected);
        return result;
    }

    bool ruleEquivalent(string expected, string observed) const {
        // Most authored fixtures predate Core Candidate 2. Keep the mapping
        // explicit so older stable rule IDs remain executable while compiler
        // diagnostics migrate to the current taxonomy.
        if ([
            "OPENC-ARITH-TYPE-001", "OPENC-ARRAY-NODECAY-001",
            "OPENC-ASSIGN-CONVERT-001", "OPENC-TYPE-BYTE-001",
            "OPENC-TYPE-FLOAT-001", "OPENC-CONVERT-LOSSY-001",
            "OPENC-COND-BOOL-001", "OPENC-LITERAL-RANGE-001",
            "OPENC-TYPE-HISTORICAL-001", "OPENC-OPTIONAL-NOBORROW-001",
            "OPENC-PTR-CONSTVIEW-001", "OPENC-SLICE-CONSTVIEW-001", "OPENC-REF-CONSTVIEW-001",
            "OPENC-TEXT-CONVERT-001", "OPENC-CAST-UNCHECKED-LIMIT-001",
            "OPENC-RETURN-TYPE-001"
        ].canFind(expected)) {
            return observed == "OPENC-TYPE-MISMATCH-001" || observed == "OPENC-EXPR-TYPE-001" ||
                observed == "OPENC-CALL-NOMATCH-001";
        }
        if ([
            "OPENC-FUNCTION-DIRECT-001", "OPENC-ARRAY-DECL-001",
            "OPENC-PTR-SYMBOL-001", "OPENC-REF-SYMBOL-001",
            "OPENC-DECL-TYPEFIRST-001", "OPENC-GLOBAL-MUTABLE-001",
            "OPENC-OUT-TARGET-001", "OPENC-PTR-OWNCOPY-001",
            "OPENC-STRUCT-INIT-001", "OPENC-LEX-TYPEWORD-001",
            "OPENC-CLEANUP-NOCANCEL-001", "OPENC-STRUCT-TRAILING-001",
            "OPENC-SWITCH-NOFALL-001", "OPENC-TRANSLATE-NOINCLUDE-001",
            "OPENC-WHEN-STRUCTURED-001", "OPENC-FLOW-OPTIONAL-001",
            "OPENC-CLEANUP-ONCE-001"
        ].canFind(expected)) {
            return observed.startsWith("OPENC-SYNTAX-") || observed.startsWith("OPENC-LEX-") ||
                observed == "OPENC-NAME-UNKNOWN-001";
        }
        if ([
            "OPENC-FLOW-DIAG-001", "OPENC-FLOW-OUT-FAILURE-001",
            "OPENC-FLOW-BREAK-001", "OPENC-FLOW-CONTINUE-001",
            "OPENC-FLOW-FOR-001", "OPENC-FLOW-IF-NOELSE-001",
            "OPENC-FLOW-WHILE-001", "OPENC-INIT-BEFOREUSE-001",
            "OPENC-INIT-NOZERO-001", "OPENC-INIT-LOOP-001"
        ].canFind(expected)) return observed == "OPENC-SAFE-INIT-001";

        switch (expected) {
            case "OPENC-PTR-ADDRESS-001": return observed == "OPENC-PTR-ADDRESS-UNSAFE-001";
            case "OPENC-ASSIGN-TARGET-001": return observed == "OPENC-ASSIGN-LVALUE-001";
            case "OPENC-SCOPE-LOCAL-001": return observed == "OPENC-NAME-UNKNOWN-001";
            case "OPENC-BORROW-NOMOVE-001": return observed == "OPENC-OWN-EXIT-001" || observed == "OPENC-BORROW-MOVE-001";
            case "OPENC-CALL-COUNT-001": return observed == "OPENC-CALL-NOMATCH-001";
            case "OPENC-CLEANUP-REF-001": return observed == "OPENC-REF-INIT-001" || observed == "OPENC-SAFE-INIT-001";
            case "OPENC-PTR-DEREF-001": return observed == "OPENC-PTR-DEREF-UNSAFE-001";
            case "OPENC-CLEANUP-NOFALLIBLE-001": return observed == "OPENC-SCOPE-NOFAIL-001";
            case "OPENC-FLOW-MOVED-001": return observed == "OPENC-OWN-USE-AFTER-MOVE-001";
            case "OPENC-FOR-SCOPE-001": return observed == "OPENC-NAME-UNKNOWN-001";
            case "OPENC-STATUS-MUSTHANDLE-001": return observed == "OPENC-STATUS-FIELD-001";
            case "OPENC-BLOCK-BRACES-001": return observed == "OPENC-SYNTAX-BRACES-001";
            case "OPENC-STMT-SEMICOLON-001": return observed == "OPENC-SYNTAX-SEMICOLON-001";
            case "OPENC-MODULE-AMBIGUOUS-001": return observed == "OPENC-MODULE-QUALIFIER-AMBIGUOUS-001";
            case "OPENC-FUNCTION-PATH-001": return observed == "OPENC-FUNCTION-RETURN-001";
            case "OPENC-LITERAL-NOSUFFIX-001": return observed == "OPENC-LEX-NUMBER-SUFFIX-001";
            case "OPENC-LITERAL-SEPARATOR-001": return observed == "OPENC-LEX-NUMBER-SEPARATOR-001";
            case "OPENC-OPTIONAL-PRESENT-READONLY-001": return observed == "OPENC-CONST-ASSIGN-001" || observed.startsWith("OPENC-SYNTAX-");
            case "OPENC-OPTIONAL-NOSHORTHAND-001": return observed == "OPENC-SYNTAX-OPTIONAL-001";
            case "OPENC-OUT-STATUSONLY-001": return observed == "OPENC-OUT-FUNCTION-STATUS-001";
            case "OPENC-OUT-OWN-001":
            case "OPENC-OUT-NOREAD-001":
            case "OPENC-PARAM-OUTTYPE-001":
            case "OPENC-FUNCTION-OUTSUCCESS-001": return observed == "OPENC-STATUS-FIELD-001" || observed == "OPENC-SAFE-INIT-001";
            case "OPENC-OVERLOAD-NORANK-001": return observed == "OPENC-CALL-AMBIGUOUS-001";
            case "OPENC-PTR-ARITH-001": return observed == "OPENC-PTR-ARITH-UNSAFE-001";
            case "OPENC-PTR-CONST-001":
            case "OPENC-REF-ASSIGN-001": return observed == "OPENC-CONST-ASSIGN-001";
            case "OPENC-PTR-NOLENGTH-001":
            case "OPENC-MEMBER-UNKNOWN-001": return observed == "OPENC-NAME-UNKNOWN-001" || observed == "OPENC-INDEX-BASE-001";
            case "OPENC-REF-RESOURCEASSIGN-001":
            case "OPENC-RESOURCE-OBLIGATION-001": return observed == "OPENC-OWN-EXIT-001";
            case "OPENC-CONVERT-REINTERPRET-001": return observed == "OPENC-REINTERPRET-VALUE-001" || observed == "OPENC-REINTERPRET-UNSAFE-001";
            case "OPENC-RESOURCE-NOCOPY-001": return observed == "OPENC-OWN-EXIT-001" || observed == "OPENC-CALL-NOMATCH-001";
            case "OPENC-CLEANUP-DESTROY-RESERVE-001": return observed == "OPENC-OWN-DOUBLE-DISCHARGE-001" || observed == "OPENC-LIFETIME-USE-AFTER-DESTROY-001";
            case "OPENC-OWN-SCOPE-RESERVE-001": return observed == "OPENC-SCOPE-OWNER-STATE-001";
            case "OPENC-CLEANUP-OWN-001": return observed == "OPENC-OWN-CLEANUP-RESERVED-001" || observed == "OPENC-OWN-OVERWRITE-001";
            case "OPENC-EVAL-SCOPE-NESTED-001": return observed == "OPENC-SCOPE-ACTION-001" || observed == "OPENC-SCOPE-NOFAIL-001";
            case "OPENC-CLEANUP-OUT-001": return observed == "OPENC-OUT-CARRIER-001" || observed == "OPENC-SCOPE-NOFAIL-001";
            case "OPENC-TARGET-QUERY-001":
            case "OPENC-TARGET-SIZEOF-001": return observed == "OPENC-TYPE-QUERY-INCOMPLETE-001";
            case "OPENC-STATUS-INVARIANT-001": return observed == "OPENC-STATUS-FIELD-001";
            case "OPENC-STORAGE-NOVALUE-001": return observed == "OPENC-NAME-UNKNOWN-001" || observed == "OPENC-TYPE-MISMATCH-001";
            case "OPENC-TEXT-NOINDEX-001": return observed == "OPENC-INDEX-BASE-001";
            case "OPENC-BORROW-ONEWRITE-001": return observed == "OPENC-BORROW-CONFLICT-001";
            case "OPENC-UNSAFE-CONTRACT-001": return observed == "OPENC-CALL-NOMATCH-001" || observed == "OPENC-UNSAFE-CALL-001";
            case "OPENC-FUNCTION-UNSAFE-001": return observed == "OPENC-UNSAFE-CALL-001";
            case "OPENC-OWN-USEAFTER-001": return observed == "OPENC-OWN-USE-AFTER-MOVE-001" || observed == "OPENC-OWN-EXIT-001";
            default: return false;
        }
    }

    JSONValue runCommandFixture(JSONValue[string] fixture, string fixtureRoot) {
        auto commandPath = firstFixtureSource(fixture, fixtureRoot);
        auto specification = parseJSON(readText(commandPath)).object;
        auto invocations = specification.get("invocations", JSONValue(JSONValue[].init)).array;
        string option = "--diagnostic-trace";
        if (invocations.length && invocations[0].array.length > 2) {
            auto invocation = invocations[0].array;
            if (invocation.length > 1 && invocation[1].str == "info") {
                auto candidate = invocation[$ - 1].str;
                if (candidate.length >= 2 && candidate[0 .. 2] == "--") option = candidate;
            }
        }
        auto observed = commandInfo(option, ProjectConfig.hostTarget());
        bool valid = true;
        foreach (required; specification.get("required", JSONValue(JSONValue[].init)).array) {
            if (required.str !in observed.object) valid = false;
        }
        auto requiredTrace = specification.get("required_trace", JSONValue(JSONValue[].init)).array;
        if (requiredTrace.length) {
            auto trace = observed.object.get("trace", JSONValue(JSONValue[].init)).array;
            foreach (required; requiredTrace) {
                bool found;
                foreach (item; trace) if (item.str == required.str) found = true;
                if (!found) valid = false;
            }
        }
        JSONValue result;
        result["fixture"] = fixture.get("id", JSONValue(fixtureRoot)).str;
        result["fixture_kind"] = "command";
        result["expected"] = "accept";
        result["accepted"] = valid;
        result["rule_matched"] = valid;
        result["passed"] = valid;
        result["observed"] = observed;
        result["implementation"] = compiler.compilerVersion.toJson();
        return result;
    }

    JSONValue runRecordFixture(JSONValue[string] fixture, string fixtureRoot) {
        auto recordPath = firstFixtureSource(fixture, fixtureRoot);
        auto wrapper = parseJSON(readText(recordPath)).object;
        auto document = wrapper.get("document", JSONValue());
        bool valid = document.type == JSONType.object;
        if (valid) {
            foreach (key; ["schema", "rule", "phase", "category", "severity", "message", "primary"]) {
                if (key !in document.object) valid = false;
            }
            if (valid) valid = document.object["schema"].str == "openc.diagnostic.v1" &&
                document.object["primary"].type == JSONType.object;
        }
        JSONValue result;
        result["fixture"] = fixture.get("id", JSONValue(fixtureRoot)).str;
        result["fixture_kind"] = "record";
        result["expected"] = "accept";
        result["accepted"] = valid;
        result["rule_matched"] = valid;
        result["passed"] = valid;
        result["implementation"] = compiler.compilerVersion.toJson();
        return result;
    }

    string firstFixtureSource(JSONValue[string] fixture, string fixtureRoot) {
        auto sources = fixture.get("source_files", JSONValue(JSONValue[].init)).array;
        if (!sources.length) throw new Exception("fixture has no source files");
        auto path = sources[0].str;
        if (exists(path)) return path;
        auto repositoryPath = buildPath(repositoryRoot, path);
        if (exists(repositoryPath)) return repositoryPath;
        return buildPath(fixtureRoot, baseName(path));
    }

    void runRuntime(
        ref JSONValue result,
        JSONValue[string] fixture,
        JSONValue expectedRecord,
        ProjectConfig project,
        CompilationResult compilation,
        bool accepted,
        string expected
    ) {
        if (!accepted) {
            result["runtime_execution"] = "NOT_BUILT_SOURCE_REJECTED";
            result["passed"] = false;
            return;
        }

        auto fixtureId = fixture.get("id", JSONValue("fixture")).str;
        auto outputDirectory = buildPath(
            repositoryRoot, "build-output", "conformance", fixtureId.replace("/", "_"));
        version (Windows) auto executable = buildPath(outputDirectory, "program.exe");
        else auto executable = buildPath(outputDirectory, "program");
        auto built = new DToolchain().build(
            compilation.backendOutput,
            project,
            buildPath(repositoryRoot, "runtime", "source"),
            buildPath(repositoryRoot, "standard_library", "source"),
            executable);
        if (!built.ok) {
            result["runtime_execution"] = "BUILD_FAILED";
            result["build_error"] = built.error;
            result["passed"] = false;
            return;
        }
        result["toolchain"] = built.value.toJson();

        string output;
        int exitCode;
        try {
            auto executed = execute([built.value.executable]);
            output = executed.output.replace("\r\n", "\n");
            exitCode = executed.status;
        } catch (Exception error) {
            result["runtime_execution"] = "LAUNCH_FAILED";
            result["infrastructure_error"] = error.msg;
            result["passed"] = false;
            return;
        }

        enum checkedMarker = "OpenC checked failure:";
        enum targetMarker = "OpenC target fault:";
        auto checkedAt = output.indexOf(checkedMarker);
        auto targetAt = output.indexOf(targetMarker);
        string observed = checkedAt >= 0 ? "checked_failure"
            : targetAt >= 0 ? "target_fault"
            : "accept";
        auto markerAt = checkedAt >= 0 ? checkedAt : targetAt;
        auto programOutput = markerAt >= 0 ? output[0 .. markerAt] : output;

        string expectedOutput;
        bool outputSpecified;
        if (expectedRecord.type == JSONType.object) {
            auto stdoutValue = expectedRecord.object.get("stdout", JSONValue());
            if (stdoutValue.type == JSONType.array) {
                outputSpecified = true;
                foreach (part; stdoutValue.array) expectedOutput ~= part.str;
            }
        }
        auto outputMatched = !outputSpecified || programOutput == expectedOutput;
        result["runtime_execution"] = "EXECUTED";
        result["runtime_exit_code"] = exitCode;
        result["runtime_output"] = programOutput;
        result["runtime_observed"] = observed;
        result["runtime_output_matched"] = outputMatched;
        result["rule_matched"] = observed == expected;
        result["passed"] = observed == expected && outputMatched;
    }

    ProjectConfig projectForFixture(JSONValue fixture, string fixtureRoot) {
        auto object = fixture.object;
        ProjectConfig config;
        config.path = buildPath(fixtureRoot, "fixture.json");
        config.root = repositoryRoot;
        config.edition = "1.0";
        config.target = ProjectConfig.hostTarget();
        auto expected = object.get("expected", JSONValue());
        if (expected.type == JSONType.object) {
            config.profile = expected.object.get("profile", JSONValue("standard")).str;
        }
        auto fixtureId = object.get("id", JSONValue("fixture")).str;
        config.outputDirectory = buildPath(
            repositoryRoot, "build-output", "conformance", fixtureId.replace("/", "_"));

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
