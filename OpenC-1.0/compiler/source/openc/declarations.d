module openc.declarations;

import openc.ast : AstNode, NodeKind;
import openc.common : ModuleId, ScopeId, SymbolId, TypeId;
import openc.diagnostic : Diagnostic, DiagnosticEngine, DiagnosticPhase, DiagnosticSeverity, RelatedLocation;
import openc.module_system : LogicalModule, ModuleGraph;
import openc.semantic_model : SemanticModel;
import openc.symbol : FunctionSignature, SymbolKind, Visibility;
import openc.source : SourceSpan;
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
        declareBuiltinModules();
        declareCoreBuiltins();
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

    void declareCoreBuiltins() {
        foreach (logical; model.modules.modules) {
            if (!logical.units.length) continue;
            foreach (operation; ["saturating_add", "saturating_sub", "saturating_mul"]) {
                foreach (typeName; [
                    "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64", "isize", "usize"
                ]) {
                    auto type = model.types.find(typeName);
                    addBuiltinFunction(logical, operation, type, [type, type]);
                }
            }
        }
    }

private:
    void declareBuiltinModules() {
        foreach (logical; model.modules.modules) {
            if (logical.name == "system.io") {
                foreach (typeName; [
                    "text", "bool", "i8", "i16", "i32", "i64",
                    "u8", "u16", "u32", "u64", "isize", "usize"
                ]) {
                    addBuiltinFunction(logical, "print", model.types.voidType,
                        [model.types.find(typeName)]);
                    addBuiltinFunction(logical, "println", model.types.voidType,
                        [model.types.find(typeName)]);
                }
                addBuiltinFunction(logical, "error", model.types.voidType,
                    [model.types.textType]);
            } else if (logical.name == "system.memory") {
                auto bytePointer = model.types.pointer(model.types.byteType, false);
                addBuiltinFunction(logical, "alloc", bytePointer,
                    [model.types.find("usize")], true);
                addBuiltinFunction(logical, "free", model.types.voidType,
                    [bytePointer]);
                addBuiltinFunction(logical, "load_usize", model.types.find("usize"),
                    [bytePointer], true);
                addBuiltinFunction(logical, "store_usize", model.types.voidType,
                    [bytePointer, model.types.find("usize")], true);
            } else if (logical.name == "system.text") {
                addBuiltinFunction(logical, "length", model.types.find("usize"),
                    [model.types.textType]);
                addBuiltinFunction(logical, "byte_length", model.types.find("usize"),
                    [model.types.textType]);
                addBuiltinFunction(logical, "trim", model.types.textType,
                    [model.types.textType]);
                addBuiltinFunction(logical, "scalar_at", model.types.statusType,
                    [model.types.textType, model.types.find("usize"), model.types.find("u32")],
                    false, ["value", "value", "out"]);
                addBuiltinFunction(logical, "byte_at", model.types.statusType,
                    [model.types.textType, model.types.find("usize"), model.types.find("u8")],
                    false, ["value", "value", "out"]);
                addBuiltinFunction(logical, "byte_at_unchecked", model.types.find("u8"),
                    [model.types.textType, model.types.find("usize")], true);
                addBuiltinFunction(logical, "concat", model.types.textType,
                    [model.types.textType, model.types.textType]);
                addBuiltinFunction(logical, "from_utf8", model.types.textType,
                    [model.types.pointer(model.types.byteType, false), model.types.find("usize")], true);
                addBuiltinFunction(logical, "equal", model.types.boolType,
                    [model.types.textType, model.types.textType]);
                addBuiltinFunction(logical, "compare", model.types.find("i32"),
                    [model.types.textType, model.types.textType]);
                addBuiltinFunction(logical, "slice", model.types.statusType,
                    [model.types.textType, model.types.find("usize"), model.types.find("usize"), model.types.textType],
                    false, ["value", "value", "value", "out"]);
            } else if (logical.name == "system.process") {
                addBuiltinFunction(logical, "argument_count", model.types.find("usize"), []);
                addBuiltinFunction(logical, "argument", model.types.textType,
                    [model.types.find("usize")]);
                addBuiltinFunction(logical, "current_directory", model.types.textType, []);
                addBuiltinFunction(logical, "run", model.types.statusType,
                    [model.types.textType, model.types.find("i32"), model.types.textType],
                    false, ["value", "out", "out"]);
            } else if (logical.name == "system.file") {
                addBuiltinFunction(logical, "read_text", model.types.statusType,
                    [model.types.textType, model.types.textType],
                    false, ["value", "out"]);
                addBuiltinFunction(logical, "read_text_cached", model.types.statusType,
                    [model.types.textType, model.types.textType],
                    false, ["value", "out"]);
                addBuiltinFunction(logical, "write_text", model.types.statusType,
                    [model.types.textType, model.types.textType]);
            } else if (logical.name == "system.path") {
                addBuiltinFunction(logical, "join", model.types.textType,
                    [model.types.textType, model.types.textType]);
                addBuiltinFunction(logical, "normalize", model.types.textType,
                    [model.types.textType]);
                addBuiltinFunction(logical, "directory", model.types.textType,
                    [model.types.textType]);
                addBuiltinFunction(logical, "absolute", model.types.boolType,
                    [model.types.textType]);
            }
        }
    }

    void addBuiltinFunction(
        LogicalModule logical,
        string name,
        TypeId result,
        TypeId[] parameters,
        bool owningResult = false,
        string[] modes = []
    ) {
        auto qualified = logical.name ~ "." ~ name;
        auto id = model.symbols.add(
            SymbolKind.functionSymbol, qualified, SourceSpan(), 0);
        auto symbol = model.symbols.get(id);
        symbol.name = name;
        symbol.qualifiedName = qualified;
        symbol.moduleId = logical.id;
        symbol.visibility = Visibility.exported;
        FunctionSignature signature;
        signature.result = result;
        signature.parameters = parameters.dup;
        if (modes.length) signature.modes = modes.dup;
        else {
            signature.modes.length = parameters.length;
            signature.modes[] = "value";
        }
        signature.owningResult = owningResult;
        symbol.signature = signature;
        symbol.type = result;
    }

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
