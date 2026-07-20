module openc.module_system;

import openc.ast : AstNode, NodeKind, ParsedUnit;
import openc.common : ModuleId, Result;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase, RelatedLocation;
import openc.project : ProjectConfig, ProjectModule;
import openc.source : SourceId, SourceManager;
import std.algorithm : sort;

struct ModuleUnit {
    SourceId source;
    AstNode root;
    string[] imports;
}

final class LogicalModule {
    ModuleId id;
    string name;
    ModuleUnit[] units;
    string[string] shortImports;

    this(ModuleId id, string name) {
        this.id = id;
        this.name = name;
    }
}

final class ModuleGraph {
    LogicalModule[] modules;
    ModuleId[string] byName;

    LogicalModule get(ModuleId id) { return modules[id]; }
    const(LogicalModule) get(ModuleId id) const { return modules[id]; }
    LogicalModule find(string name) {
        auto found = name in byName;
        return found is null ? null : modules[*found];
    }
    const(LogicalModule) find(string name) const {
        auto found = name in byName;
        return found is null ? null : modules[*found];
    }
}

final class ModuleComposer {
private:
    DiagnosticEngine diagnostics;

public:
    this(DiagnosticEngine diagnostics) {
        this.diagnostics = diagnostics;
    }

    ModuleGraph compose(ProjectConfig project, ParsedUnit[SourceId] parsed, SourceManager sources) {
        auto graph = new ModuleGraph();
        foreach (projectModule; project.modules) {
            auto id = cast(ModuleId) graph.modules.length;
            auto logical = new LogicalModule(id, projectModule.name);
            graph.byName[projectModule.name] = id;
            graph.modules ~= logical;

            foreach (path; projectModule.sources) {
                SourceId sourceId;
                bool matched;
                foreach (source; sources.all()) {
                    if (source.path == path) {
                        sourceId = source.id;
                        matched = true;
                        break;
                    }
                }
                if (!matched) continue;
                auto unit = sourceId in parsed;
                if (unit is null) continue;
                ModuleUnit moduleUnit;
                moduleUnit.source = sourceId;
                moduleUnit.root = unit.root;
                foreach (child; unit.root.children) {
                    if (child.kind == NodeKind.importDecl) moduleUnit.imports ~= child.text;
                }
                logical.units ~= moduleUnit;
            }
        }

        foreach (name; [
            "system.io", "system.memory", "system.text",
            "system.process", "system.path", "system.file"
        ]) {
            if (graph.find(name) !is null) continue;
            auto id = cast(ModuleId) graph.modules.length;
            graph.byName[name] = id;
            graph.modules ~= new LogicalModule(id, name);
        }

        foreach (logical; graph.modules) {
            foreach (unit; logical.units) {
                foreach (importName; unit.imports) {
                    auto imported = graph.find(importName);
                    if (imported is null) {
                        diagnostics.error("OPENC-MODULE-IMPORT-MISSING-001", DiagnosticPhase.name,
                            "module.import", "imported module does not exist: " ~ importName,
                            unit.root.span);
                        continue;
                    }
                    auto shortName = lastSegment(importName);
                    auto existing = shortName in logical.shortImports;
                    if (existing !is null && *existing != importName) {
                        diagnostics.error("OPENC-MODULE-QUALIFIER-AMBIGUOUS-001", DiagnosticPhase.name,
                            "module.import", "short module qualifier is ambiguous: " ~ shortName,
                            unit.root.span);
                    } else {
                        logical.shortImports[shortName] = importName;
                    }
                }
            }
        }
        return graph;
    }

private:
    string lastSegment(string name) const {
        size_t index = name.length;
        while (index > 0 && name[index - 1] != '.') --index;
        return name[index .. $];
    }
}
