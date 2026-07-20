module openc.pointer;

import openc.ast : AstNode, NodeKind;
import openc.common : NodeId, SymbolId, TypeId;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.semantic_model : SemanticModel;
import openc.types : TypeKind;

enum ProvenanceKind : string {
    none = "none",
    object = "object",
    allocation = "allocation",
    storage = "storage",
    foreign = "foreign",
    unknown = "unknown"
}

struct PointerFact {
    ProvenanceKind provenance;
    size_t identity;
    long offset;
    size_t extent;
    size_t generation;
    TypeId pointee;
    bool onePast;
    bool live;
    bool aligned;
    TypeId liveType;
}

final class PointerAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    PointerFact[NodeId] facts;
    PointerFact[SymbolId] symbolFacts;
    size_t nextIdentity = 1;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void analyzeFunction(AstNode functionNode) {
        foreach (parameter; functionNode.children) {
            if (parameter.kind != NodeKind.parameter) continue;
            auto symbolId = parameter.id in model.nodeSymbols;
            if (symbolId is null) continue;
            auto type = model.symbols.get(*symbolId).type;
            auto info = model.types.get(type);
            if (info.kind != TypeKind.pointer) continue;
            PointerFact value;
            value.provenance = ProvenanceKind.foreign;
            value.identity = nextIdentity++;
            value.pointee = info.element;
            value.liveType = info.element;
            value.live = true;
            value.aligned = true;
            symbolFacts[*symbolId] = value;
        }
        analyzeTree(functionNode.children[$ - 1]);
    }

    PointerFact fact(AstNode node) const {
        return facts.get(node.id, PointerFact(ProvenanceKind.none, 0, 0, 0, 0, model.types.errorType, false, false, false));
    }

private:
    void analyzeTree(AstNode node) {
        if (node is null) return;
        foreach (child; node.children) analyzeTree(child);
        analyzeNode(node);
    }

    void analyzeNode(AstNode node) {
        auto type = model.typeOf(node);
        auto typeInfo = model.types.get(type);

        if (node.kind == NodeKind.localDecl || node.kind == NodeKind.assignmentExpr) {
            auto destination = node.kind == NodeKind.localDecl ? node : node.children[0];
            auto symbolId = destination.id in model.nodeSymbols;
            auto value = node.kind == NodeKind.localDecl
                ? (node.children.length > 1 ? node.children[1] : null)
                : node.children[1];
            if (symbolId !is null && value !is null &&
                model.types.get(model.symbols.get(*symbolId).type).kind == TypeKind.pointer) {
                symbolFacts[*symbolId] = facts.get(value.id, unknownPointer(model.symbols.get(*symbolId).type));
            }
            return;
        }
        if (node.kind == NodeKind.qualifiedName && typeInfo.kind == TypeKind.pointer) {
            auto symbolId = node.id in model.nodeSymbols;
            facts[node.id] = symbolId is null
                ? unknownPointer(type)
                : symbolFacts.get(*symbolId, unknownPointer(type));
            return;
        }
        if (node.kind == NodeKind.callExpr && typeInfo.kind == TypeKind.pointer) {
            PointerFact value = unknownPointer(type);
            auto target = node.id in model.nodeSymbols;
            if (target !is null && model.symbols.get(*target).qualifiedName == "system.memory.alloc") {
                value.provenance = ProvenanceKind.allocation;
                value.identity = nextIdentity++;
                value.extent = node.children.length > 1
                    ? cast(size_t) model.integerConstants.get(node.children[1].id, 0)
                    : 0;
                value.pointee = typeInfo.element;
                value.liveType = model.types.byteType;
                value.live = true;
                value.aligned = true;
            }
            facts[node.id] = value;
            return;
        }
        if (node.kind == NodeKind.binaryExpr && node.text == "-" &&
            model.types.get(model.typeOf(node.children[0])).kind == TypeKind.pointer &&
            model.types.get(model.typeOf(node.children[1])).kind == TypeKind.pointer) {
            auto left = facts.get(node.children[0].id, unknownPointer(model.typeOf(node.children[0])));
            auto right = facts.get(node.children[1].id, unknownPointer(model.typeOf(node.children[1])));
            if (left.identity == 0 || right.identity == 0 || left.identity != right.identity) {
                model.pointerTargetFaults[node.id] = true;
            }
            return;
        }
        if (typeInfo.kind != TypeKind.pointer &&
            !(node.kind == NodeKind.unaryExpr && node.text == "*")) return;
        if (node.kind == NodeKind.unaryExpr && node.text == "&") {
            PointerFact value;
            value.provenance = ProvenanceKind.object;
            value.identity = nextIdentity++;
            value.offset = 0;
            value.extent = typeExtent(model.typeOf(node.children[0]));
            if (node.children[0].kind == NodeKind.indexExpr) {
                auto aggregate = model.types.get(model.typeOf(node.children[0].children[0]));
                if (aggregate.kind == TypeKind.fixedArray) {
                    auto index = model.integerConstants.get(node.children[0].children[1].id, 0);
                    if (index >= 0 && index <= cast(long) aggregate.length) {
                        value.extent = (aggregate.length - cast(size_t) index) * typeExtent(aggregate.element);
                    }
                }
            }
            value.generation = 1;
            value.pointee = model.typeOf(node.children[0]);
            value.liveType = value.pointee;
            value.live = true;
            value.aligned = true;
            facts[node.id] = value;
        } else if (node.kind == NodeKind.binaryExpr && (node.text == "+" || node.text == "-")) {
            auto base = facts.get(node.children[0].id, unknownPointer(model.typeOf(node.children[0])));
            auto amount = model.integerConstants.get(node.children[1].id, 0);
            if (node.text == "-") amount = -amount;
            auto stride = typeExtent(base.pointee);
            if (!stride) stride = 1;
            base.offset += amount * cast(long) stride;
            base.onePast = base.extent != 0 && base.offset == cast(long) base.extent;
            if (base.extent != 0 && (base.offset < 0 || base.offset > cast(long) base.extent)) {
                model.pointerTargetFaults[node.id] = true;
            }
            facts[node.id] = base;
        } else if (node.kind == NodeKind.unaryExpr && node.text == "*") {
            auto pointerType = model.typeOf(node.children[0]);
            auto pointer = facts.get(node.children[0].id, unknownPointer(pointerType));
            if (pointer.onePast) diagnostics.error("OPENC-PTR-ONEPAST-001", DiagnosticPhase.unsafePhase,
                "pointer.bounds", "one-past pointer cannot be dereferenced", node.span);
            auto pointee = model.types.get(pointerType).kind == TypeKind.pointer
                ? model.types.get(pointerType).element : model.types.errorType;
            bool byteView = pointee == model.types.byteType;
            bool lifetimeMatches = pointer.liveType == pointee || byteView;
            if (!pointer.onePast && (!pointer.live || !pointer.aligned || !lifetimeMatches ||
                (pointer.extent && (pointer.offset < 0 || pointer.offset + cast(long) typeExtent(pointee) > pointer.extent)))) {
                model.pointerTargetFaults[node.id] = true;
            }
        } else if (node.kind == NodeKind.castExpr || node.kind == NodeKind.reinterpretExpr) {
            auto source = node.children.length > 1
                ? facts.get(node.children[1].id, unknownPointer(type))
                : unknownPointer(type);
            source.pointee = model.types.get(type).kind == TypeKind.pointer ? model.types.get(type).element : source.pointee;
            auto alignment = typeExtent(source.pointee);
            source.aligned = source.aligned && (!alignment || source.offset % cast(long) alignment == 0);
            facts[node.id] = source;
        } else if (node.kind == NodeKind.nullLiteral) {
            PointerFact value;
            value.provenance = ProvenanceKind.none;
            value.live = false;
            facts[node.id] = value;
        }
    }

    PointerFact unknownPointer(TypeId pointerType) {
        PointerFact value;
        auto info = model.types.get(pointerType);
        value.provenance = ProvenanceKind.unknown;
        value.identity = nextIdentity++;
        value.pointee = info.kind == TypeKind.pointer ? info.element : model.types.errorType;
        value.liveType = value.pointee;
        value.live = true;
        value.aligned = true;
        return value;
    }

    size_t typeExtent(TypeId type) const {
        auto info = model.types.get(type);
        if (info.bits) return info.bits / 8;
        if (info.kind == TypeKind.fixedArray) return info.length * typeExtent(info.element);
        if (info.kind == TypeKind.pointer || info.kind == TypeKind.reference) return model.target.pointerWidth / 8;
        return 0;
    }
}
