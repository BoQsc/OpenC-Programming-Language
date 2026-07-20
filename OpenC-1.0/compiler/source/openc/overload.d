module openc.overload;

import openc.ast : AstNode;
import openc.common : SymbolId, TypeId;
import openc.semantic_model : SemanticModel, ValueCategory;
import openc.symbol : SymbolKind;
import openc.types : TypeKind;

struct OverloadMatch {
    bool found;
    bool ambiguous;
    SymbolId symbol;
    size_t conversions;
}

final class OverloadResolver {
private:
    SemanticModel model;

public:
    this(SemanticModel model) { this.model = model; }

    OverloadMatch resolve(
        SymbolId[] candidates,
        TypeId[] arguments,
        string[] modes,
        AstNode[] argumentNodes = []
    ) {
        OverloadMatch result;
        size_t bestConversions = size_t.max;
        foreach (candidateId; candidates) {
            auto candidate = model.symbols.get(candidateId);
            if (candidate.kind != SymbolKind.functionSymbol) continue;
            if (candidate.signature.parameters.length != arguments.length) continue;
            bool valid = true;
            size_t conversions;
            foreach (index, parameterType; candidate.signature.parameters) {
                if (index < modes.length && candidate.signature.modes[index] != modes[index] &&
                    !(candidate.signature.modes[index] == "own" && modes[index] == "value")) {
                    valid = false; break;
                }
                if (parameterType == arguments[index]) continue;
                if (model.types.lossless(arguments[index], parameterType, model.target) ||
                    (index < argumentNodes.length && integerConstantFits(argumentNodes[index], parameterType)) ||
                    (index < argumentNodes.length && implicitReference(
                        argumentNodes[index], arguments[index], parameterType)) ||
                    implicitOptional(arguments[index], parameterType)) {
                    ++conversions;
                }
                else { valid = false; break; }
            }
            if (!valid) continue;
            if (!result.found || conversions < bestConversions) {
                result.found = true;
                result.ambiguous = false;
                result.symbol = candidateId;
                result.conversions = conversions;
                bestConversions = conversions;
            } else if (conversions == bestConversions) {
                result.ambiguous = true;
            }
        }
        return result;
    }

private:
    bool integerConstantFits(AstNode node, TypeId target) const {
        auto value = node.id in model.integerConstants;
        if (value is null) return false;
        auto info = model.types.get(target);
        if (!info.integer()) return false;
        auto bits = info.bits ? info.bits : model.target.pointerWidth;
        if (info.kind == TypeKind.signedInteger) {
            if (bits >= 64) return true;
            return *value >= -(1L << (bits - 1)) && *value <= (1L << (bits - 1)) - 1;
        }
        if (*value < 0) return false;
        return bits >= 63 || *value <= (1L << bits) - 1;
    }

    bool implicitReference(AstNode node, TypeId argument, TypeId parameter) const {
        auto expected = model.types.get(parameter);
        if (expected.kind != TypeKind.reference) return false;
        if (!model.types.lossless(argument, expected.element, model.target)) return false;
        auto category = model.categories.get(node.id, ValueCategory());
        return category.lvalue && (expected.constQualified || category.mutableValue);
    }

    bool implicitOptional(TypeId argument, TypeId parameter) const {
        auto expected = model.types.get(parameter);
        return expected.kind == TypeKind.optional &&
            model.types.lossless(argument, expected.element, model.target);
    }
}
