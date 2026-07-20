module openc.pointer;

import openc.ast : AstNode, NodeKind;
import openc.ast_util : walk;
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
}

final class PointerAnalyzer {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;
    PointerFact[NodeId] facts;
    size_t nextIdentity = 1;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    void analyzeFunction(AstNode functionNode) {
        walk(functionNode.children[$ - 1], (AstNode node) { analyzeNode(node); });
    }

    PointerFact fact(AstNode node) const {
        return facts.get(node.id, PointerFact(ProvenanceKind.none, 0, 0, 0, 0, model.types.errorType, false, false, false));
    }

private:
    void analyzeNode(AstNode node) {
        auto type = model.typeOf(node);
        if (model.types.get(type).kind != TypeKind.pointer && !(node.kind == NodeKind.unaryExpr && node.text == "*")) return;
        if (node.kind == NodeKind.unaryExpr && node.text == "&") {
            PointerFact value;
            value.provenance = ProvenanceKind.object;
            value.identity = nextIdentity++;
            value.offset = 0;
            value.extent = typeExtent(model.typeOf(node.children[0]));
            value.generation = 1;
            value.pointee = model.typeOf(node.children[0]);
            value.live = true;
            value.aligned = true;
            facts[node.id] = value;
        } else if (node.kind == NodeKind.binaryExpr && (node.text == "+" || node.text == "-")) {
            auto base = facts.get(node.children[0].id, PointerFact());
            auto amount = model.integerConstants.get(node.children[1].id, 0);
            if (node.text == "-") amount = -amount;
            base.offset += amount;
            base.onePast = base.extent != 0 && base.offset == cast(long) base.extent;
            if (base.extent != 0 && (base.offset < 0 || base.offset > cast(long) base.extent)) {
                diagnostics.error("OPENC-PTR-ARITH-BOUNDS-001", DiagnosticPhase.unsafePhase,
                    "pointer.provenance", "pointer arithmetic leaves its originating extent", node.span);
            }
            facts[node.id] = base;
        } else if (node.kind == NodeKind.unaryExpr && node.text == "*") {
            auto pointer = facts.get(node.children[0].id, PointerFact());
            if (!pointer.live) diagnostics.error("OPENC-PTR-LIFETIME-001", DiagnosticPhase.unsafePhase,
                "pointer.lifetime", "pointer does not refer to a live lifetime generation", node.span);
            if (pointer.onePast) diagnostics.error("OPENC-PTR-ONE-PAST-DEREF-001", DiagnosticPhase.unsafePhase,
                "pointer.bounds", "one-past pointer cannot be dereferenced", node.span);
            if (!pointer.aligned) diagnostics.error("OPENC-PTR-ALIGN-001", DiagnosticPhase.unsafePhase,
                "pointer.alignment", "pointer is not aligned for its pointee type", node.span);
        } else if (node.kind == NodeKind.castExpr || node.kind == NodeKind.reinterpretExpr) {
            auto source = node.children.length > 1 ? facts.get(node.children[1].id, PointerFact()) : PointerFact();
            source.pointee = model.types.get(type).kind == TypeKind.pointer ? model.types.get(type).element : source.pointee;
            source.aligned = false;
            facts[node.id] = source;
        } else if (node.kind == NodeKind.nullLiteral) {
            PointerFact value;
            value.provenance = ProvenanceKind.none;
            value.live = false;
            facts[node.id] = value;
        }
    }

    size_t typeExtent(TypeId type) const {
        auto info = model.types.get(type);
        if (info.bits) return info.bits / 8;
        if (info.kind == TypeKind.fixedArray) return info.length * typeExtent(info.element);
        if (info.kind == TypeKind.pointer || info.kind == TypeKind.reference) return model.target.pointerWidth / 8;
        return 0;
    }
}
