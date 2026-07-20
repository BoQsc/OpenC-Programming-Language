module openc.compiler;

import openc.ast : AstArena, ParsedUnit;
import openc.backend : BackendOutput;
import openc.backend_d : DSourceBackend;
import openc.backend_ir : JsonIrBackend;
import openc.common : CompilerVersion, Result;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.ir : IrProgram;
import openc.lexer : Lexer;
import openc.lowerer : Lowerer;
import openc.parser : Parser;
import openc.project : ProjectConfig, ProjectModule;
import openc.semantic_model : SemanticModel;
import openc.semantic_pipeline : SemanticPipeline;
import openc.source : SourceId, SourceManager, SourceSpan;
import std.algorithm : sort;
import std.file : mkdirRecurse, write;
import std.json : JSONValue;
import std.path : buildPath;
import std.file : exists;
import std.string : startsWith;

struct CompilationOptions {
    string backend = "d-source";
    string outputDirectory = "build";
    bool emitAst;
    bool emitIr;
    bool stopAfterCheck;
}

final class CompilationResult {
    SourceManager sources;
    DiagnosticEngine diagnostics;
    ParsedUnit[SourceId] parsed;
    SemanticModel semantic;
    IrProgram ir;
    BackendOutput backendOutput;
    CompilerVersion compilerVersion;

    bool success() const { return diagnostics !is null && !diagnostics.hasErrors(); }

    JSONValue toJson() {
        JSONValue result;
        result["schema"] = "openc.compilation_result.v1";
        result["implementation"] = compilerVersion.toJson();
        result["success"] = success();
        result["diagnostics"] = diagnostics.toJson(sources);
        JSONValue[] files;
        foreach (path; backendOutput.files) files ~= JSONValue(path);
        result["outputs"] = JSONValue(files);
        return result;
    }
}

final class Compiler {
    CompilerVersion compilerVersion;

    this() {
        compilerVersion = CompilerVersion();
    }

    Result!CompilationResult compile(ProjectConfig project, CompilationOptions options) {
        auto result = new CompilationResult();
        result.compilerVersion = compilerVersion;
        result.sources = new SourceManager();
        result.diagnostics = new DiagnosticEngine();
        AstArena arena = new AstArena();

        auto moduleSet = resolvedModules(project);
        if (!moduleSet.ok) return Result!CompilationResult.failure(moduleSet.error);
        foreach (moduleConfig; moduleSet.value) {
            foreach (path; moduleConfig.sources) {
                auto loaded = result.sources.load(path, moduleConfig.name);
                if (!loaded.ok) {
                    if (loaded.error.startsWith("source file is not valid UTF-8:")) {
                        auto source = result.sources.addVirtual(path, "");
                        result.diagnostics.error(
                            "OPENC-SOURCE-INVALID-001",
                            DiagnosticPhase.source,
                            "source.encoding",
                            "source file is not valid UTF-8",
                            SourceSpan(source, 0, 0));
                        continue;
                    }
                    return Result!CompilationResult.failure(loaded.error);
                }
            }
        }

        foreach (source; result.sources.all()) {
            auto tokens = new Lexer(source, result.diagnostics).lex();
            auto parsed = new Parser(tokens, result.diagnostics, arena).parse();
            result.parsed[source.id] = parsed;
        }

        if (result.diagnostics.hasErrors()) return Result!CompilationResult.success(result);

        result.semantic = new SemanticPipeline(result.sources, result.diagnostics).run(project, result.parsed);
        if (result.diagnostics.hasErrors() || options.stopAfterCheck) return Result!CompilationResult.success(result);

        result.ir = new Lowerer(result.semantic).lower();
        if (options.emitAst) emitAst(result, options.outputDirectory);
        if (options.emitIr || options.backend == "json-ir") {
            auto emitted = new JsonIrBackend().emit(result.ir, result.semantic, result.sources, options.outputDirectory);
            if (!emitted.ok) return Result!CompilationResult.failure(emitted.error);
            result.backendOutput = emitted.value;
            if (options.backend == "json-ir") return Result!CompilationResult.success(result);
        }
        if (options.backend == "d-source") {
            auto emitted = new DSourceBackend().emit(result.ir, result.semantic, result.sources, options.outputDirectory);
            if (!emitted.ok) return Result!CompilationResult.failure(emitted.error);
            result.backendOutput = emitted.value;
        } else if (options.backend != "json-ir") {
            return Result!CompilationResult.failure("unknown backend: " ~ options.backend);
        }
        return Result!CompilationResult.success(result);
    }

private:
    Result!(ProjectModule[]) resolvedModules(ProjectConfig project) {
        ProjectModule[] modules = project.modules.dup;
        if (!project.standardLibraryDirectory.length) {
            return Result!(ProjectModule[]).success(modules);
        }
        auto libraryProjectPath = buildPath(project.standardLibraryDirectory, "openc.project.json");
        if (!exists(libraryProjectPath)) {
            return Result!(ProjectModule[]).failure(
                "standard library project configuration not found: " ~ libraryProjectPath);
        }
        auto loaded = ProjectConfig.load(libraryProjectPath);
        if (!loaded.ok) return Result!(ProjectModule[]).failure(loaded.error);
        foreach (candidate; loaded.value.modules) {
            bool duplicate;
            foreach (existing; modules) {
                if (existing.name == candidate.name) {
                    duplicate = true;
                    break;
                }
            }
            if (duplicate) {
                return Result!(ProjectModule[]).failure(
                    "project module conflicts with standard library module: " ~ candidate.name);
            }
            modules ~= candidate;
        }
        return Result!(ProjectModule[]).success(modules);
    }

    void emitAst(CompilationResult result, string outputDirectory) {
        try mkdirRecurse(outputDirectory);
        catch (Exception) return;
        JSONValue[] units;
        foreach (source; result.sources.all()) {
            auto parsed = source.id in result.parsed;
            if (parsed is null) continue;
            JSONValue unit;
            unit["source"] = source.path;
            unit["ast"] = parsed.root.toJson();
            units ~= unit;
        }
        JSONValue root;
        root["schema"] = "openc.ast.v1";
        root["units"] = JSONValue(units);
        write(buildPath(outputDirectory, "program.openc-ast.json"), root.toPrettyString() ~ "\n");
    }
}
