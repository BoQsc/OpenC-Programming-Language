module openc.overload;

import openc.common : SymbolId, TypeId;
import openc.semantic_model : SemanticModel;
import openc.symbol : SymbolKind;

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

    OverloadMatch resolve(SymbolId[] candidates, TypeId[] arguments, string[] modes) {
        OverloadMatch result;
        size_t bestConversions = size_t.max;
        foreach (candidateId; candidates) {
            auto candidate = model.symbols.get(candidateId);
            if (candidate.kind != SymbolKind.functionSymbol) continue;
            if (candidate.signature.parameters.length != arguments.length) continue;
            bool valid = true;
            size_t conversions;
            foreach (index, parameterType; candidate.signature.parameters) {
                if (index < modes.length && candidate.signature.modes[index] != modes[index]) {
                    valid = false; break;
                }
                if (parameterType == arguments[index]) continue;
                if (model.types.lossless(arguments[index], parameterType, model.target)) ++conversions;
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
}
