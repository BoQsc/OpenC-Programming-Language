module openc.symbol;

import openc.ast : AstNode, NodeKind;
import openc.common : ModuleId, ScopeId, SymbolId, TypeId;
import openc.source : SourceSpan;
import std.algorithm : sort;

enum SymbolKind : string {
    moduleSymbol = "module",
    functionSymbol = "function",
    structSymbol = "struct",
    resourceSymbol = "resource",
    enumSymbol = "enum",
    enumItemSymbol = "enum_item",
    fieldSymbol = "field",
    parameterSymbol = "parameter",
    variableSymbol = "variable",
    constantSymbol = "constant"
}

enum Visibility : string {
    privateVisibility = "private",
    exported = "exported"
}

struct FunctionSignature {
    TypeId result;
    TypeId[] parameters;
    string[] modes;
    bool unsafeFunction;
    bool owningResult;
}

final class Symbol {
    SymbolId id;
    SymbolKind kind;
    string name;
    string qualifiedName;
    ModuleId moduleId;
    ScopeId scopeId;
    TypeId type;
    Visibility visibility;
    SourceSpan span;
    AstNode declaration;
    FunctionSignature signature;
    bool mutableValue;
    bool initialized;
    bool resource;

    this(SymbolId id, SymbolKind kind, string name, SourceSpan span) {
        this.id = id;
        this.kind = kind;
        this.name = name;
        this.span = span;
    }
}

final class Scope {
    ScopeId id;
    ScopeId parent;
    bool hasParent;
    SymbolId[][string] entries;

    this(ScopeId id, ScopeId parent, bool hasParent) {
        this.id = id;
        this.parent = parent;
        this.hasParent = hasParent;
    }
}

final class SymbolTable {
    Symbol[] symbols;
    Scope[] scopes;

    this() {
        scopes ~= new Scope(0, 0, false);
    }

    ScopeId createScope(ScopeId parent) {
        auto id = cast(ScopeId) scopes.length;
        scopes ~= new Scope(id, parent, true);
        return id;
    }

    SymbolId add(SymbolKind kind, string name, SourceSpan span, ScopeId scopeId = 0) {
        auto id = cast(SymbolId) symbols.length;
        auto symbol = new Symbol(id, kind, name, span);
        symbol.scopeId = scopeId;
        symbols ~= symbol;
        scopes[scopeId].entries[name] ~= id;
        return id;
    }

    Symbol get(SymbolId id) { return symbols[id]; }
    const(Symbol) get(SymbolId id) const { return symbols[id]; }

    SymbolId[] local(ScopeId scopeId, string name) const {
        auto found = name in scopes[scopeId].entries;
        return found is null ? [] : (*found).dup;
    }

    SymbolId[] lookup(ScopeId scopeId, string name) const {
        auto current = scopeId;
        while (true) {
            auto found = name in scopes[current].entries;
            if (found !is null) return (*found).dup;
            if (!scopes[current].hasParent) break;
            current = scopes[current].parent;
        }
        return [];
    }
}
