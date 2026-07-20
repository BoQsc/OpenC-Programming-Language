module app.main;

import openc.command : CommandRequest, normalize;
import openc.common : canonicalSourceExtension, CompilerVersion, Result;
import openc.compiler : CompilationOptions, CompilationResult, Compiler;
import openc.conformance : ConformanceAdapter;
import openc.project : ProjectConfig;
import openc.toolchain : DToolchain;
import openc.tools.explain : ExplanationDatabase;
import openc.tools.formatter : Formatter, FormatterConfig;
import openc.tools.info : projectInfo;
import openc.tools.live : LiveEvaluator;
import openc.tools.lsp : LanguageServer;
import openc.tools.runner : runExecutable;
import openc.tools.validator : FixtureRunner;
import std.algorithm.searching : endsWith;
import std.conv : to;
import std.file : readText, tempDir, write;
import std.json : JSONValue;
import std.path : buildPath;
import std.stdio : stderr, stdout;
import std.string : replace;

int main(string[] argv) {
    auto normalized = normalize(argv[1 .. $]);
    if (!normalized.ok) {
        stderr.writeln("openc: " ~ normalized.error);
        printUsage();
        return 2;
    }
    auto request = normalized.value;
    auto compiler = new Compiler();

    switch (request.command) {
        case "check": return runCheck(compiler, request);
        case "build": return runBuild(compiler, request);
        case "run": return runProgram(compiler, request);
        case "test": return runValidate(compiler, request);
        case "eval": return runEval(compiler, request);
        case "live": return new LiveEvaluator(compiler).run();
        case "ast": return runAst(compiler, request);
        case "ir": return runIr(compiler, request);
        case "fmt": return runFormat(request);
        case "info": return runInfo(compiler, request);
        case "explain": return runExplain(request);
        case "validate": return runValidate(compiler, request);
        case "lsp": return new LanguageServer(compiler).run();
        case "adapter": return runAdapter(compiler, request);
        case "version":
        case "--version":
            stdout.writeln(compiler.compilerVersion.implementationName ~ " " ~ compiler.compilerVersion.implementationVersion);
            return 0;
        default:
            stderr.writeln("openc: unknown command '" ~ request.command ~ "'");
            printUsage();
            return 2;
    }
}

int runCheck(Compiler compiler, CommandRequest request) {
    auto projectResult = loadProject(request);
    if (!projectResult.ok) { stderr.writeln(projectResult.error); return 2; }
    CompilationOptions options;
    options.stopAfterCheck = true;
    auto compiled = compiler.compile(projectResult.value, options);
    if (!compiled.ok) { stderr.writeln(compiled.error); return 2; }
    auto result = compiled.value;
    writeDiagnostics(result, request);
    return result.success() ? 0 : 1;
}

int runBuild(Compiler compiler, CommandRequest request) {
    auto built = buildProgram(compiler, request);
    if (!built.ok) { stderr.writeln(built.error); return 1; }
    if (built.value.length) stdout.writeln(built.value);
    return 0;
}

Result!string buildProgram(Compiler compiler, CommandRequest request) {
    auto projectResult = loadProject(request);
    if (!projectResult.ok) return Result!string.failure(projectResult.error);
    auto project = projectResult.value;
    CompilationOptions options;
    options.backend = request.option("backend", "d-source");
    options.outputDirectory = request.option("generated_output", buildPath(project.outputDirectory, "generated"));
    options.emitAst = request.flag("emit_ast");
    options.emitIr = request.flag("emit_ir");
    auto compiled = compiler.compile(project, options);
    if (!compiled.ok) return Result!string.failure(compiled.error);
    auto result = compiled.value;
    writeDiagnostics(result, request);
    if (!result.success()) return Result!string.failure("OpenC compilation failed");
    if (request.flag("emit_only") || options.backend != "d-source") {
        return Result!string.success(result.backendOutput.primarySource);
    }
    auto output = request.option("output", buildPath(project.outputDirectory, defaultExecutableName()));
    auto runtimeRoot = request.option(
        "runtime_root",
        project.runtimeDirectory.length ? buildPath(project.runtimeDirectory, "source") : "runtime/source");
    auto libraryRoot = request.option(
        "library_root",
        project.standardLibraryDirectory.length ? buildPath(project.standardLibraryDirectory, "source") : "standard_library/source");
    auto record = request.option("build_record", buildPath(project.outputDirectory, "openc-build-record.json"));
    auto toolchain = new DToolchain().build(result.backendOutput, project, runtimeRoot, libraryRoot, output, record);
    if (!toolchain.ok) return Result!string.failure(toolchain.error);
    return Result!string.success(toolchain.value.executable);
}

int runProgram(Compiler compiler, CommandRequest request) {
    auto built = buildProgram(compiler, request);
    if (!built.ok) { stderr.writeln(built.error); return 1; }
    auto programArguments = request.option("project").length
        ? request.positionals
        : request.positionals.length > 1 ? request.positionals[1 .. $] : [];
    auto result = runExecutable(built.value, programArguments);
    if (!result.ok) { stderr.writeln(result.error); return 2; }
    stdout.write(result.value.output.replace("\r\n", "\n"));
    return result.value.exitCode;
}

int runEval(Compiler compiler, CommandRequest request) {
    auto expression = request.option("code", request.positionals.length ? request.positionals[0] : "");
    if (!expression.length) { stderr.writeln("openc eval requires code"); return 2; }
    auto path = buildPath(tempDir(), "openc-eval-source" ~ canonicalSourceExtension);
    write(path, "i32 main() {\n    " ~ expression ~ (expression.endsWith(";") ? "" : ";") ~ "\n    return 0;\n}\n");
    CommandRequest buildRequest;
    buildRequest.command = "run";
    buildRequest.positionals = [path];
    buildRequest.options = request.options.dup;
    return runProgram(compiler, buildRequest);
}

int runAst(Compiler compiler, CommandRequest request) {
    auto projectResult = loadProject(request);
    if (!projectResult.ok) { stderr.writeln(projectResult.error); return 2; }
    CompilationOptions options;
    options.stopAfterCheck = true;
    options.emitAst = true;
    options.outputDirectory = request.option("output", "build/ast");
    auto compiled = compiler.compile(projectResult.value, options);
    if (!compiled.ok) { stderr.writeln(compiled.error); return 2; }
    writeDiagnostics(compiled.value, request);
    return compiled.value.success() ? 0 : 1;
}

int runIr(Compiler compiler, CommandRequest request) {
    auto projectResult = loadProject(request);
    if (!projectResult.ok) { stderr.writeln(projectResult.error); return 2; }
    CompilationOptions options;
    options.backend = "json-ir";
    options.outputDirectory = request.option("output", "build/ir");
    auto compiled = compiler.compile(projectResult.value, options);
    if (!compiled.ok) { stderr.writeln(compiled.error); return 2; }
    writeDiagnostics(compiled.value, request);
    return compiled.value.success() ? 0 : 1;
}

int runFormat(CommandRequest request) {
    if (!request.positionals.length) { stderr.writeln("openc fmt requires a source path"); return 2; }
    auto path = request.positionals[0];
    string source;
    try source = readText(path);
    catch (Exception error) { stderr.writeln(error.msg); return 2; }
    FormatterConfig config;
    config.indentWidth = request.option("indent", "4").to!size_t;
    config.targetWidth = request.option("width", "100").to!size_t;
    auto result = new Formatter(config).format(source);
    if (!result.ok) { stderr.writeln(result.error); return 1; }
    if (request.flag("check")) return result.value == source ? 0 : 1;
    if (request.flag("stdout")) stdout.write(result.value);
    else write(path, result.value);
    return 0;
}

int runInfo(Compiler compiler, CommandRequest request) {
    auto projectResult = loadProject(request);
    if (!projectResult.ok) { stderr.writeln(projectResult.error); return 2; }
    stdout.writeln(projectInfo(projectResult.value, compiler.compilerVersion).toPrettyString());
    return 0;
}

int runExplain(CommandRequest request) {
    auto id = request.option("rule", request.positionals.length ? request.positionals[0] : "");
    auto index = request.option("index", "standard/core/metadata/OpenC_Core_Rule_Index.json");
    if (!id.length) { stderr.writeln("openc explain requires a rule ID"); return 2; }
    auto database = ExplanationDatabase.load(index);
    if (!database.ok) { stderr.writeln(database.error); return 2; }
    auto result = database.value.find(id);
    if (!result.ok) { stderr.writeln(result.error); return 1; }
    stdout.write(result.value.render());
    return 0;
}

int runValidate(Compiler compiler, CommandRequest request) {
    auto manifest = request.option("manifest", request.positionals.length ? request.positionals[0] : "");
    if (!manifest.length) { stderr.writeln("openc validate requires a fixture manifest"); return 2; }
    auto report = new FixtureRunner(compiler).runManifest(manifest);
    auto output = request.option("output");
    if (output.length) write(output, report.toPrettyString() ~ "\n");
    else stdout.writeln(report.toPrettyString());
    return report.object["failed"].integer == 0 ? 0 : 1;
}

int runAdapter(Compiler compiler, CommandRequest request) {
    auto path = request.option("request", request.positionals.length ? request.positionals[0] : "");
    if (!path.length) { stderr.writeln("openc adapter requires a request file"); return 2; }
    auto result = new ConformanceAdapter(compiler).execute(path);
    if (!result.ok) { stderr.writeln(result.error); return 2; }
    auto output = request.option("output");
    if (output.length) write(output, result.value.toPrettyString() ~ "\n");
    else stdout.writeln(result.value.toPrettyString());
    return result.value.object.get("passed", JSONValue(false)).boolean ? 0 : 1;
}

Result!ProjectConfig loadProject(CommandRequest request) {
    auto projectPath = request.option("project");
    if (projectPath.length) return ProjectConfig.load(projectPath);
    if (request.positionals.length) {
        auto config = ProjectConfig.singleSource(request.positionals[0]);
        config.runtimeDirectory = request.option("runtime_directory", "runtime");
        config.standardLibraryDirectory = request.option("standard_library_directory", "standard_library");
        config.outputDirectory = request.option("output_directory", "build");
        return Result!ProjectConfig.success(config);
    }
    return Result!ProjectConfig.failure("command requires a project file or source path");
}

void writeDiagnostics(CompilationResult result, CommandRequest request) {
    if (request.option("diagnostics_format") == "json" || request.option("diagnostics_format") == "jsonl") {
        stdout.writeln(result.diagnostics.toJson(result.sources).toPrettyString());
    } else result.diagnostics.writeHuman(result.sources);
}

string defaultExecutableName() {
    version (Windows) return "openc-program.exe";
    else return "openc-program";
}

void printUsage() {
    auto version_ = CompilerVersion();
    stdout.writeln("OpenC " ~ version_.implementationVersion ~
        " reference compiler and tools (Windows x86-64 Hosted release candidate)");
    stdout.writeln("  openc check <source> [--diagnostics-format=json]");
    stdout.writeln("  openc build <source> [--output=PROGRAM] [--emit-only]");
    stdout.writeln("  openc run <source> [program arguments]");
    stdout.writeln("  openc test --manifest=fixtures.json");
    stdout.writeln("  openc eval 'expression;'");
    stdout.writeln("  openc live");
    stdout.writeln("  openc fmt <source> [--check|--stdout]");
    stdout.writeln("  openc info --project=openc.project.json");
    stdout.writeln("  openc explain RULE-ID [--index=rule-index.json]");
    stdout.writeln("  openc validate --manifest=fixtures.json");
    stdout.writeln("  openc lsp --stdio");
    stdout.writeln("  openc 'check(file=\"source/main.p\", diagnostics_format=\"json\")'");
}
