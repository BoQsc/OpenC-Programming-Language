module openc.names;

import openc.ast : AstNode, NodeKind;
import openc.common : ScopeId, SymbolId, TypeId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.module_system : LogicalModule;
import openc.semantic_model : SemanticModel, ValueCategory;
import openc.symbol : Symbol, SymbolKind;
import openc.types : TypeKind;
import std.algorithm.searching : canFind;
import std.string : indexOf, lastIndexOf, split;

final class NameResolver {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    LogicalModule currentModule;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void resolve() {
        foreach (logical; model.modules.modules) {
            currentModule = logical;
            foreach (unit; logical.units) {
                foreach (node; unit.root.children) {
                    if (node.kind == NodeKind.functionDecl) resolveFunction(node);
                    else if (node.kind == NodeKind.moduleConstDecl && node.children.length > 1) resolveExpression(node.children[1], 0);
                    else if (node.kind == NodeKind.structDecl || node.kind == NodeKind.resourceDecl) resolveFieldDefaults(node);
                    else if (node.kind == NodeKind.whenDecl) resolveWhen(node);
                }
            }
        }
    }

private:
    void resolveFunction(AstNode functionNode) {
        auto functionScope = model.symbols.createScope(0);
        model.nodeScopes[functionNode.id] = functionScope;
        foreach (child; functionNode.children) {
            if (child.kind != NodeKind.parameter) continue;
            declareLocal(child, functionScope, SymbolKind.parameterSymbol, true);
        }
        auto functionBody = functionNode.children[$ - 1];
        resolveBlock(functionBody, functionScope);
    }

    void resolveFieldDefaults(AstNode aggregate) {
        auto scopeId = model.nodeScopes.get(aggregate.id, 0);
        foreach (field; aggregate.children) {
            if (field.children.length > 1) resolveExpression(field.children[1], scopeId);
        }
    }

    void resolveWhen(AstNode whenNode) {
        if (whenNode.children.length) resolveExpression(whenNode.children[0], 0);
        foreach (child; whenNode.children[1 .. $]) {
            if (child.kind == NodeKind.functionDecl) resolveFunction(child);
        }
    }

    void resolveBlock(AstNode block, ScopeId parent) {
        auto scopeId = model.symbols.createScope(parent);
        model.nodeScopes[block.id] = scopeId;
        foreach (item; block.children) {
            if (item is null) continue;
            if (item.kind == NodeKind.localDecl) {
                if (item.children.length > 1) resolveExpression(item.children[1], scopeId);
                declareLocal(item, scopeId, SymbolKind.variableSymbol, item.children.length > 1);
            } else resolveStatement(item, scopeId);
        }
    }

    void declareLocal(AstNode node, ScopeId scopeId, SymbolKind kind, bool initialized) {
        auto existing = model.symbols.local(scopeId, node.text);
        if (existing.length) {
            auto first = model.symbols.get(existing[0]);
            Diagnostic diagnostic;
            diagnostic.rule = "OPENC-NAME-DUPLICATE-001";
            diagnostic.category = "name.duplicate";
            diagnostic.severity = DiagnosticSeverity.error;
            diagnostic.phase = DiagnosticPhase.name;
            diagnostic.message = "duplicate name in the same scope: " ~ node.text;
            diagnostic.span = node.span;
            diagnostic.related ~= RelatedLocation(DiagnosticSeverity.note, "previous declaration", first.span);
            diagnostics.emit(diagnostic);
        }
        auto id = model.symbols.add(kind, node.text, node.span, scopeId);
        auto symbol = model.symbols.get(id);
        symbol.declaration = node;
        symbol.type = model.types.resolve(node.children[0], model.target);
        symbol.mutableValue = !node.children[0].flag("const");
        symbol.initialized = initialized || kind == SymbolKind.parameterSymbol;
        symbol.resource = model.types.get(symbol.type).resource || node.get("mode") == "own" || node.get("mode") == "out_own";
        model.nodeSymbols[node.id] = id;
        model.nodeScopes[node.id] = scopeId;
    }

    void resolveStatement(AstNode node, ScopeId scopeId) {
        model.nodeScopes[node.id] = scopeId;
        switch (node.kind) {
            case NodeKind.block: resolveBlock(node, scopeId); break;
            case NodeKind.ifStmt:
                resolveExpression(node.children[0], scopeId);
                resolveBlock(node.children[1], scopeId);
                if (node.children.length > 2) {
                    if (node.children[2].kind == NodeKind.ifStmt) resolveStatement(node.children[2], scopeId);
                    else resolveBlock(node.children[2], scopeId);
                }
                break;
            case NodeKind.whileStmt:
                resolveExpression(node.children[0], scopeId); resolveBlock(node.children[1], scopeId); break;
            case NodeKind.forStmt:
                resolveFor(node, scopeId); break;
            case NodeKind.switchStmt:
                resolveExpression(node.children[0], scopeId);
                foreach (child; node.children[1 .. $]) {
                    if (child.kind == NodeKind.switchCase) {
                        resolveExpression(child.children[0], scopeId); resolveBlock(child.children[1], scopeId);
                    } else if (child.kind == NodeKind.defaultCase) resolveBlock(child.children[0], scopeId);
                }
                break;
            case NodeKind.returnStmt:
            case NodeKind.expressionStmt:
            case NodeKind.scopeStmt:
                foreach (child; node.children) resolveExpression(child, scopeId);
                break;
            case NodeKind.unsafeStmt: resolveBlock(node.children[0], scopeId); break;
            case NodeKind.whenStmt:
                resolveExpression(node.children[0], scopeId); resolveBlock(node.children[1], scopeId); break;
            default: break;
        }
    }

    void resolveFor(AstNode node, ScopeId parent) {
        auto scopeId = model.symbols.createScope(parent);
        model.nodeScopes[node.id] = scopeId;
        foreach (index, child; node.children) {
            if (child is null) continue;
            if (index == 0 && child.kind == NodeKind.localDecl) {
                if (child.children.length > 1) resolveExpression(child.children[1], scopeId);
                declareLocal(child, scopeId, SymbolKind.variableSymbol, child.children.length > 1);
            } else if (child.kind == NodeKind.block) resolveBlock(child, scopeId);
            else resolveExpression(child, scopeId);
        }
    }

    void resolveExpression(AstNode node, ScopeId scopeId) {
        if (node is null) return;
        model.nodeScopes[node.id] = scopeId;
        if (node.kind == NodeKind.qualifiedName) {
            resolveNameNode(node, scopeId);
            return;
        }
        foreach (child; node.children) resolveExpression(child, scopeId);
    }

    void resolveNameNode(AstNode node, ScopeId scopeId) {
        auto text = node.text;
        if (text.indexOf('.') < 0) {
            auto local = model.symbols.lookup(scopeId, text);
            if (local.length) {
                model.nodeSymbols[node.id] = local[0];
                return;
            }
            auto qualified = currentModule.name ~ "." ~ text;
            auto moduleLocal = model.symbols.local(0, qualified);
            if (moduleLocal.length) {
                model.nodeSymbols[node.id] = moduleLocal[0];
                return;
            }
            SymbolId[] importedMatches;
            foreach (_, importName; currentModule.shortImports) {
                auto match = model.symbols.local(0, importName ~ "." ~ text);
                importedMatches ~= match;
            }
            if (importedMatches.length == 1) {
                model.nodeSymbols[node.id] = importedMatches[0];
                return;
            }
            if (importedMatches.length > 1) {
                diagnostics.error("OPENC-NAME-AMBIGUOUS-001", DiagnosticPhase.name,
                    "name.ambiguous", "name is provided by more than one imported module: " ~ text, node.span);
                return;
            }
        } else {
            if (resolveValuePath(node, scopeId)) return;
            if (resolveEnumItem(node)) return;
            auto direct = model.symbols.local(0, text);
            if (direct.length) {
                model.nodeSymbols[node.id] = direct[0];
                return;
            }
            auto firstDot = text.indexOf('.');
            auto prefix = text[0 .. firstDot];
            auto rest = text[firstDot + 1 .. $];
            string moduleName;
            if (prefix == currentModule.name) moduleName = currentModule.name;
            else if (auto imported = prefix in currentModule.shortImports) moduleName = *imported;
            else moduleName = text[0 .. text.lastIndexOf('.')];
            auto matches = model.symbols.local(0, moduleName ~ "." ~ rest);
            if (matches.length) {
                model.nodeSymbols[node.id] = matches[0];
                return;
            }
        }
        diagnostics.error("OPENC-NAME-UNKNOWN-001", DiagnosticPhase.name,
            "name.unknown", "unknown name: " ~ text, node.span);
    }

    bool resolveValuePath(AstNode node, ScopeId scopeId) {
        auto parts = node.text.split(".");
        if (parts.length < 2) return false;
        auto local = model.symbols.lookup(scopeId, parts[0]);
        if (local.length != 1) return false;

        auto base = model.symbols.get(local[0]);
        auto currentType = base.type;
        auto mutableValue = base.mutableValue;
        SymbolId currentSymbol = local[0];
        foreach (index; 1 .. parts.length) {
            auto info = model.types.get(currentType);
            if (info.kind == TypeKind.reference || info.kind == TypeKind.pointer) {
                mutableValue = mutableValue && !info.constQualified;
                currentType = info.element;
                info = model.types.get(currentType);
            }

            auto member = parts[index];
            if ((info.kind == TypeKind.fixedArray || info.kind == TypeKind.slice ||
                 info.kind == TypeKind.text) && member == "length") {
                if (index + 1 != parts.length) return false;
                model.setType(node, model.types.find("usize"));
                model.categories[node.id] = ValueCategory(false, false, true, false);
                return true;
            }
            if (info.kind == TypeKind.optional && member == "present") {
                if (index + 1 != parts.length) return false;
                model.setType(node, model.types.boolType);
                model.categories[node.id] = ValueCategory(false, false, true, false);
                return true;
            }
            if (info.kind == TypeKind.optional && member == "value") {
                currentType = info.element;
                if (index + 1 == parts.length) {
                    model.setType(node, currentType);
                    model.categories[node.id] = ValueCategory(true, mutableValue, true, false);
                    return true;
                }
                continue;
            }
            if (info.kind == TypeKind.status &&
                (member == "ok" || member == "code" || member == "message")) {
                if (index + 1 != parts.length) return false;
                auto memberType = member == "ok" ? model.types.boolType
                    : member == "code" ? model.types.find("i32") : model.types.textType;
                model.setType(node, memberType);
                model.categories[node.id] = ValueCategory(false, false, true, false);
                return true;
            }

            auto aggregate = findAggregate(info.name);
            if (aggregate is null || aggregate.declaration is null) return false;
            auto aggregateScope = model.nodeScopes.get(aggregate.declaration.id, 0);
            auto fields = model.symbols.local(aggregateScope, member);
            if (fields.length != 1) return false;
            currentSymbol = fields[0];
            auto field = model.symbols.get(currentSymbol);
            currentType = field.type;
            mutableValue = mutableValue && field.mutableValue;
        }
        model.nodeSymbols[node.id] = currentSymbol;
        return true;
    }

    bool resolveEnumItem(AstNode node) {
        auto parts = node.text.split(".");
        if (parts.length != 2) return false;
        auto enumSymbols = model.symbols.local(0, currentModule.name ~ "." ~ parts[0]);
        foreach (symbolId; enumSymbols) {
            auto symbol = model.symbols.get(symbolId);
            if (symbol.kind != SymbolKind.enumSymbol || symbol.declaration is null) continue;
            auto enumScope = model.nodeScopes.get(symbol.declaration.id, 0);
            auto items = model.symbols.local(enumScope, parts[1]);
            if (items.length == 1) {
                model.nodeSymbols[node.id] = items[0];
                return true;
            }
        }
        return false;
    }

    Symbol findAggregate(string name) {
        foreach (symbol; model.symbols.symbols) {
            if ((symbol.kind == SymbolKind.structSymbol || symbol.kind == SymbolKind.resourceSymbol) &&
                (symbol.name == name || symbol.qualifiedName == name)) return symbol;
        }
        return null;
    }
}
