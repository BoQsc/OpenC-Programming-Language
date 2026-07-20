module openc.semantic_model;

import openc.ast : AstNode;
import openc.common : ModuleId, NodeId, ScopeId, SymbolId, TargetContext, TypeId;
import openc.module_system : ModuleGraph;
import openc.symbol : SymbolTable;
import openc.types : TypeTable;

struct ValueCategory {
    bool lvalue;
    bool mutableValue;
    bool initialized;
    bool constantValue;
}

final class SemanticModel {
    ModuleGraph modules;
    SymbolTable symbols;
    TypeTable types;
    TargetContext target;
    TypeId[NodeId] nodeTypes;
    SymbolId[NodeId] nodeSymbols;
    ScopeId[NodeId] nodeScopes;
    ValueCategory[NodeId] categories;
    long[NodeId] integerConstants;
    string[NodeId] textConstants;
    bool[NodeId] boolConstants;
    string[] requiredCapabilities;

    this(ModuleGraph modules, TargetContext target) {
        this.modules = modules;
        this.target = target;
        symbols = new SymbolTable();
        types = new TypeTable();
    }

    void setType(AstNode node, TypeId type) {
        if (node !is null) nodeTypes[node.id] = type;
    }
    TypeId typeOf(AstNode node) const {
        auto found = node.id in nodeTypes;
        return found is null ? types.errorType : *found;
    }
}
