module openc.project_observation;

import openc.ast : AstArena, NodeKind, ParsedUnit;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.lexer : Lexer;
import openc.module_system : ModuleComposer, ModuleGraph;
import openc.parser : Parser;
import openc.project : ProjectConfig;
import openc.source : SourceId, SourceManager;
import std.algorithm.searching : canFind;
import std.stdio : stderr, stdout;

private struct UnitObservation {
    size_t moduleIndex;
    size_t sourceIndex;
    SourceId source;
    string path;
    size_t nodeCount;
    string[] imports;
    bool loaded;
}

int observeProjectFrontend(string path) {
    stdout.writeln("OPENC-PROJECT-OBSERVATION 1");
    try {
        auto loaded = ProjectConfig.load(path);
        if (!loaded.ok) return projectFailure("OPENC-PROJECT-INVALID-001");
        return observeLoadedProject(loaded.value);
    } catch (Exception error) {
        stderr.writeln("openc project-observe: " ~ error.msg);
        return projectFailure("OPENC-PROJECT-INVALID-001");
    }
}

private int observeLoadedProject(ProjectConfig project) {
    auto sources = new SourceManager();
    auto diagnostics = new DiagnosticEngine();
    auto arena = new AstArena();
    ParsedUnit[SourceId] parsed;
    size_t[SourceId] nodeCounts;
    size_t projectErrors;

    foreach (moduleIndex, moduleConfig; project.modules) {
        foreach (sourceIndex, path; moduleConfig.sources) {
            auto loaded = sources.load(path, moduleConfig.name);
            if (!loaded.ok) {
                ++projectErrors;
            }
        }
    }

    foreach (source; sources.all()) {
        const before = arena.all().length;
        auto tokens = new Lexer(source, diagnostics).lex();
        parsed[source.id] = new Parser(tokens, diagnostics, arena).parse();
        nodeCounts[source.id] = arena.all().length - before;
    }

    UnitObservation[] units;
    foreach (moduleIndex, moduleConfig; project.modules) {
        foreach (sourceIndex, path; moduleConfig.sources) {
            foreach (source; sources.all()) {
                if (source.path != path) continue;
                UnitObservation unit;
                unit.moduleIndex = moduleIndex;
                unit.sourceIndex = sourceIndex;
                unit.source = source.id;
                unit.path = path;
                unit.nodeCount = nodeCounts.get(source.id, 0);
                unit.loaded = true;
                if (auto parsedUnit = source.id in parsed) {
                    foreach (child; parsedUnit.root.children) {
                        if (child.kind == NodeKind.importDecl) unit.imports ~= child.text;
                    }
                }
                units ~= unit;
                break;
            }
            bool matched;
            foreach (unit; units) {
                if (unit.moduleIndex == moduleIndex && unit.sourceIndex == sourceIndex) {
                    matched = true;
                    break;
                }
            }
            if (!matched) {
                UnitObservation unit;
                unit.moduleIndex = moduleIndex;
                unit.sourceIndex = sourceIndex;
                unit.path = path;
                units ~= unit;
            }
        }
    }

    ModuleGraph graph;
    if (!diagnostics.hasErrors() && projectErrors == 0) {
        graph = new ModuleComposer(diagnostics).compose(project, parsed, sources);
        addDirectCycleDiagnostics(graph, diagnostics);
    }

    size_t graphModules;
    if (graph !is null) {
        foreach (moduleIndex, logical; graph.modules) {
            stdout.write("MODULE ", moduleIndex, " ");
            writeHex(logical.name);
            stdout.writeln(" ", logical.units.length);
        }
        graphModules = graph.modules.length;
    } else {
        graphModules = writeModuleSkeleton(project);
    }

    size_t importCount;
    size_t nodeCount;
    foreach (unit; units) {
        stdout.write("UNIT ", unit.moduleIndex, " ", unit.sourceIndex, " ");
        writeHex(unit.path);
        stdout.writeln();
        if (!unit.loaded) {
            stdout.writeln(
                "PROJECT_ERROR OPENC-PROJECT-SOURCE-READ-001 ",
                unit.moduleIndex, " ", unit.sourceIndex,
            );
            continue;
        }
        auto source = sources.get(unit.source);
        stdout.writeln(
            "SOURCE ", unit.moduleIndex, " ", unit.sourceIndex, " ",
            source.text.length, " ", unit.nodeCount,
        );
        nodeCount += unit.nodeCount;
        foreach (importName; unit.imports) {
            stdout.write("IMPORT ", unit.moduleIndex, " ", unit.sourceIndex, " ");
            writeHex(importName);
            stdout.writeln();
            ++importCount;
        }
    }

    foreach (diagnostic; diagnostics.all()) {
        size_t moduleIndex;
        size_t sourceIndex;
        bool matched;
        foreach (unit; units) {
            if (unit.source != diagnostic.span.source) continue;
            moduleIndex = unit.moduleIndex;
            sourceIndex = unit.sourceIndex;
            matched = true;
            break;
        }
        if (!matched) continue;
        auto source = sources.get(diagnostic.span.source);
        auto position = source.position(diagnostic.span.start);
        stdout.writeln(
            "ERROR ", diagnostic.rule, " ", moduleIndex, " ", sourceIndex, " ",
            diagnostic.span.start, " ", diagnostic.span.length, " ",
            position.line, " ", position.column,
        );
    }

    const errorCount = diagnostics.errors() + projectErrors;
    stdout.writeln(
        "SUMMARY ", project.modules.length, " ", graphModules, " ",
        units.length, " ", importCount, " ", nodeCount, " ", errorCount,
    );
    return errorCount == 0 ? 0 : 1;
}

private void addDirectCycleDiagnostics(ModuleGraph graph, DiagnosticEngine diagnostics) {
    foreach (logical; graph.modules) {
        foreach (unit; logical.units) {
            foreach (importName; unit.imports) {
                auto imported = graph.find(importName);
                if (imported is null) continue;
                foreach (importedUnit; imported.units) {
                    if (!importedUnit.imports.canFind(logical.name)) continue;
                    diagnostics.error(
                        "OPENC-MODULE-CYCLE-001",
                        DiagnosticPhase.name,
                        "module.cycle",
                        "module import cycle detected",
                        unit.root.span,
                    );
                }
            }
        }
    }
}

private size_t writeModuleSkeleton(ProjectConfig project) {
    size_t count;
    foreach (moduleIndex, moduleConfig; project.modules) {
        stdout.write("MODULE ", moduleIndex, " ");
        writeHex(moduleConfig.name);
        stdout.writeln(" ", moduleConfig.sources.length);
        ++count;
    }
    foreach (name; [
        "system.io", "system.memory", "system.text",
        "system.process", "system.path", "system.file",
    ]) {
        bool exists;
        foreach (moduleConfig; project.modules) {
            if (moduleConfig.name == name) { exists = true; break; }
        }
        if (exists) continue;
        stdout.write("MODULE ", count, " ");
        writeHex(name);
        stdout.writeln(" 0");
        ++count;
    }
    return count;
}

private int projectFailure(string rule) {
    stdout.writeln("PROJECT_ERROR ", rule);
    stdout.writeln("SUMMARY 0 0 0 0 0 1");
    return 1;
}

private void writeHex(string value) {
    immutable digits = "0123456789abcdef";
    foreach (ubyte octet; cast(const(ubyte)[]) value) {
        stdout.write(digits[octet >> 4], digits[octet & 15]);
    }
}
