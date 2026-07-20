module openc.declarations;

import openc.ast : AstNode, NodeKind;
import openc.common : ModuleId, ScopeId, SymbolId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.module_system : LogicalModule, ModuleGraph;
import openc.semantic_model : SemanticModel;
import openc.symbol : FunctionSignature, SymbolKind, Visibility;
import openc.types : TypeKind;
import std.algorithm.searching : canFind;

final class DeclarationCollector {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void collect() {
        foreach (logical; model.modules.modules) {
            predeclareTypes(logical);
        }
        foreach (logical; model.modules.modules) {
            foreach (unit; logical.units) {
                foreach (node; unit.root.children) {
                    if (node.kind == NodeKind.importDecl) continue;
                    collectTop(logical, node);
                }
            }
        }
    }

private:
    void predeclareTypes(LogicalModule logical) {
        foreach (unit; logical.units) {
            foreach (node; unit.root.children) {
                if (node.kind == NodeKind.structDecl || node.kind == NodeKind.resourceDecl || node.kind == NodeKind.enumDecl) {
                    auto qualified = logical.name ~ "." ~ node.text;
                    model.types.declareNamed(qualified, node.kind == NodeKind.resourceDecl);
                    model.types.declareNamed(node.text, node.kind == NodeKind.resourceDecl);
                }
            }
        }
    }

    void collectTop(LogicalModule logical, AstNode node) {
        switch (node.kind) {
            case NodeKind.functionDecl: collectFunction(logical, node); break;
            case NodeKind.structDecl: collectAggregate(logical, node, false); break;
            case NodeKind.resourceDecl: collectAggregate(logical, node, true); break;
            case NodeKind.enumDecl: collectEnum(logical, node); break;
            case NodeKind.moduleConstDecl: collectModuleConstant(logical, node); break;
            case NodeKind.whenDecl:
                foreach (child; node.children[1 .. $]) collectTop(logical, child);
                break;
            default: break;
        }
    }

    SymbolId addTop(LogicalModule logical, SymbolKind kind, AstNode node, bool allowOverload = false) {
        auto existing = model.symbols.local(0, logical.name ~ "." ~ node.text);
        if (existing.length && !allowOverload) {
            auto first = model.symbols.get(existing[0]);
            Diagnostic diagnostic;
            diagnostic.rule = "OPENC-NAME-DUPLICATE-001";
            diagnostic.category = "declaration.duplicate";
            diagnostic.severity = DiagnosticSeverity.error;
            diagnostic.phase = DiagnosticPhase.declaration;
            diagnostic.message = "duplicate top-level declaration: " ~ node.text;
            diagnostic.span = node.span;
            diagnostic.related ~= RelatedLocation(DiagnosticSeverity.note, "previous declaration", first.span);
            diagnostics.emit(diagnostic);
        }
        auto id = model.symbols.add(kind, logical.name ~ "." ~ node.text, node.span, 0);
        auto symbol = model.symbols.get(id);
        symbol.name = node.text;
        symbol.qualifiedName = logical.name ~ "." ~ node.text;
        symbol.moduleId = logical.id;
        symbol.visibility = node.flag("export") ? Visibility.exported : Visibility.privateVisibility;
        symbol.declaration = node;
        model.nodeSymbols[node.id] = id;
        return id;
    }

    void collectFunction(LogicalModule logical, AstNode node) {
        auto id = addTop(logical, SymbolKind.functionSymbol, node, true);
        auto symbol = model.symbols.get(id);
        FunctionSignature signature;
        signature.unsafeFunction = node.flag("unsafe");
        signature.owningResult = node.flag("own_result");
        if (node.children.length) signature.result = model.types.resolve(node.children[0], model.target);
        foreach (child; node.children[1 .. $]) {
            if (child.kind != NodeKind.parameter) continue;
            signature.modes ~= child.get("mode", "value");
            signature.parameters ~= model.types.resolve(child.children[0], model.target);
        }
        symbol.signature = signature;
        symbol.type = signature.result;
    }

    void collectAggregate(LogicalModule logical, AstNode node, bool resource) {
        auto id = addTop(logical, resource ? SymbolKind.resourceSymbol : SymbolKind.structSymbol, node);
        auto symbol = model.symbols.get(id);
        symbol.resource = resource;
        symbol.type = model.types.find(node.text);
        auto aggregateScope = model.symbols.createScope(0);
        model.nodeScopes[node.id] = aggregateScope;
        foreach (field; node.children) {
            if (field.kind != NodeKind.fieldDecl) continue;
            auto duplicates = model.symbols.local(aggregateScope, field.text);
            if (duplicates.length) {
                diagnostics.error("OPENC-NAME-DUPLICATE-001", DiagnosticPhase.declaration,
                    "declaration.field", "duplicate field: " ~ field.text, field.span);
            }
            auto fieldId = model.symbols.add(SymbolKind.fieldSymbol, field.text, field.span, aggregateScope);
            auto fieldSymbol = model.symbols.get(fieldId);
            fieldSymbol.type = model.types.resolve(field.children[0], model.target);
            fieldSymbol.mutableValue = true;
            fieldSymbol.resource = model.types.get(fieldSymbol.type).resource || field.flag("own");
            fieldSymbol.declaration = field;
            model.nodeSymbols[field.id] = fieldId;
        }
    }

    void collectEnum(LogicalModule logical, AstNode node) {
        auto id = addTop(logical, SymbolKind.enumSymbol, node);
        auto symbol = model.symbols.get(id);
        symbol.type = model.types.find(node.text);
        auto enumScope = model.symbols.createScope(0);
        model.nodeScopes[node.id] = enumScope;
        foreach (item; node.children) {
            if (item.kind != NodeKind.enumItem) continue;
            auto itemId = model.symbols.add(SymbolKind.enumItemSymbol, item.text, item.span, enumScope);
            auto itemSymbol = model.symbols.get(itemId);
            itemSymbol.type = symbol.type;
            itemSymbol.declaration = item;
            model.nodeSymbols[item.id] = itemId;
        }
    }

    void collectModuleConstant(LogicalModule logical, AstNode node) {
        auto id = addTop(logical, SymbolKind.constantSymbol, node);
        auto symbol = model.symbols.get(id);
        symbol.type = model.types.resolve(node.children[0], model.target);
        symbol.mutableValue = false;
        symbol.initialized = true;
    }
}
