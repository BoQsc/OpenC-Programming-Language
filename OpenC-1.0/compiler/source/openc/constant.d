module openc.constant;

import openc.ast : AstNode, NodeKind;
import openc.common : Result, TargetContext, TypeId;
import openc.diagnostic : DiagnosticEngine, DiagnosticPhase;
import openc.semantic_model : SemanticModel;
import openc.symbol : SymbolKind;
import openc.types : TypeKind;
import std.algorithm : min, max;
import std.algorithm.searching : canFind;
import std.array : replace;
import std.conv : to;
import std.math : isFinite;

struct ConstantValue {
    TypeId type;
    bool valid;
    long signedValue;
    ulong unsignedValue;
    double floatValue;
    bool boolValue;
    string textValue;
}

final class ConstantEvaluator {
private:
    SemanticModel model;
    DiagnosticEngine diagnostics;

public:
    this(SemanticModel model, DiagnosticEngine diagnostics) {
        this.model = model;
        this.diagnostics = diagnostics;
    }

    ConstantValue evaluate(AstNode node) {
        if (node is null) return ConstantValue(model.types.errorType, false);
        switch (node.kind) {
            case NodeKind.integerLiteral: return integerLiteral(node);
            case NodeKind.floatLiteral: return floatLiteral(node);
            case NodeKind.textLiteral: return textLiteral(node);
            case NodeKind.boolLiteral: return boolLiteral(node);
            case NodeKind.unaryExpr: return unary(node);
            case NodeKind.binaryExpr: return binary(node);
            case NodeKind.typeQueryExpr: return typeQuery(node);
            default: return ConstantValue(model.types.errorType, false);
        }
    }

private:
    ConstantValue integerLiteral(AstNode node) {
        auto normalized = node.text.replace("_", "");
        int radix = 10;
        size_t start;
        if (normalized.length > 2 && normalized[0] == '0' && (normalized[1] == 'x' || normalized[1] == 'X')) { radix = 16; start = 2; }
        else if (normalized.length > 2 && normalized[0] == '0' && (normalized[1] == 'b' || normalized[1] == 'B')) { radix = 2; start = 2; }
        ulong value;
        try value = normalized[start .. $].to!ulong(radix);
        catch (Exception) {
            diagnostics.error("OPENC-LITERAL-RANGE-001", DiagnosticPhase.constant,
                "constant.integer", "integer literal is outside the supported constant range", node.span);
            return ConstantValue(model.types.errorType, false);
        }
        auto type = model.types.find("i32");
        if (value > int.max && value <= long.max) type = model.types.find("i64");
        else if (value > long.max) type = model.types.find("u64");
        ConstantValue result;
        result.type = type;
        result.valid = true;
        result.unsignedValue = value;
        result.signedValue = cast(long) value;
        model.integerConstants[node.id] = result.signedValue;
        model.setType(node, type);
        return result;
    }

    ConstantValue floatLiteral(AstNode node) {
        ConstantValue result;
        try result.floatValue = node.text.replace("_", "").to!double;
        catch (Exception) {
            diagnostics.error("OPENC-LITERAL-FLOAT-001", DiagnosticPhase.constant,
                "constant.float", "invalid floating literal", node.span);
            return ConstantValue(model.types.errorType, false);
        }
        result.type = model.types.find("f64");
        result.valid = true;
        model.setType(node, result.type);
        return result;
    }

    ConstantValue textLiteral(AstNode node) {
        ConstantValue result;
        result.type = model.types.textType;
        result.valid = true;
        result.textValue = node.text.length >= 2 ? node.text[1 .. $ - 1] : "";
        model.textConstants[node.id] = result.textValue;
        model.setType(node, result.type);
        return result;
    }

    ConstantValue boolLiteral(AstNode node) {
        ConstantValue result;
        result.type = model.types.boolType;
        result.valid = true;
        result.boolValue = node.text == "true";
        model.boolConstants[node.id] = result.boolValue;
        model.setType(node, result.type);
        return result;
    }

    ConstantValue unary(AstNode node) {
        auto value = evaluate(node.children[0]);
        if (!value.valid) return value;
        if (node.text == "!") {
            if (value.type != model.types.boolType) return typeError(node, "boolean negation requires bool");
            value.boolValue = !value.boolValue;
            return value;
        }
        if (node.text == "-") {
            if (!model.types.get(value.type).integer()) return typeError(node, "unary minus requires an integer");
            if (value.signedValue == long.min) return overflow(node);
            value.signedValue = -value.signedValue;
            value.unsignedValue = cast(ulong) value.signedValue;
            model.integerConstants[node.id] = value.signedValue;
            model.setType(node, value.type);
            return value;
        }
        if (node.text == "+") {
            model.integerConstants[node.id] = value.signedValue;
            model.setType(node, value.type);
            return value;
        }
        if (node.text == "~") {
            if (!model.types.get(value.type).integer()) return typeError(node, "bitwise complement requires an integer");
            value.signedValue = ~value.signedValue;
            value.unsignedValue = cast(ulong) value.signedValue;
            model.integerConstants[node.id] = value.signedValue;
            model.setType(node, value.type);
            return value;
        }
        return ConstantValue(model.types.errorType, false);
    }

    ConstantValue binary(AstNode node) {
        auto left = evaluate(node.children[0]);
        auto right = evaluate(node.children[1]);
        if (!left.valid || !right.valid) return ConstantValue(model.types.errorType, false);
        auto op = node.text;
        if (op == "&&" || op == "||") {
            if (left.type != model.types.boolType || right.type != model.types.boolType) return typeError(node, "logical operation requires bool operands");
            ConstantValue result;
            result.type = model.types.boolType; result.valid = true;
            result.boolValue = op == "&&" ? left.boolValue && right.boolValue : left.boolValue || right.boolValue;
            return result;
        }
        if (["==", "!=", "<", "<=", ">", ">="].canFind(op)) {
            ConstantValue result;
            result.type = model.types.boolType; result.valid = true;
            if (model.types.get(left.type).integer() && model.types.get(right.type).integer()) {
                if (op == "==") result.boolValue = left.signedValue == right.signedValue;
                else if (op == "!=") result.boolValue = left.signedValue != right.signedValue;
                else if (op == "<") result.boolValue = left.signedValue < right.signedValue;
                else if (op == "<=") result.boolValue = left.signedValue <= right.signedValue;
                else if (op == ">") result.boolValue = left.signedValue > right.signedValue;
                else result.boolValue = left.signedValue >= right.signedValue;
                return result;
            }
            return typeError(node, "constant comparison requires compatible scalar operands");
        }
        if (!model.types.get(left.type).integer() || !model.types.get(right.type).integer()) return typeError(node, "constant arithmetic requires integer operands");
        long resultValue;
        try {
            switch (op) {
                case "+": resultValue = checkedAdd(left.signedValue, right.signedValue, node); break;
                case "-": resultValue = checkedSub(left.signedValue, right.signedValue, node); break;
                case "*": resultValue = checkedMul(left.signedValue, right.signedValue, node); break;
                case "/":
                    if (right.signedValue == 0) return divideByZero(node);
                    if (left.signedValue == long.min && right.signedValue == -1) return overflow(node);
                    resultValue = left.signedValue / right.signedValue; break;
                case "%":
                    if (right.signedValue == 0) return divideByZero(node);
                    resultValue = left.signedValue % right.signedValue; break;
                case "<<":
                    if (right.signedValue < 0 || right.signedValue >= 64) return shiftError(node);
                    resultValue = checkedShift(left.signedValue, cast(uint) right.signedValue, node); break;
                case ">>":
                    if (right.signedValue < 0 || right.signedValue >= 64) return shiftError(node);
                    resultValue = left.signedValue >> right.signedValue; break;
                case "&": resultValue = left.signedValue & right.signedValue; break;
                case "|": resultValue = left.signedValue | right.signedValue; break;
                case "^": resultValue = left.signedValue ^ right.signedValue; break;
                default: return ConstantValue(model.types.errorType, false);
            }
        } catch (OverflowException) {
            return overflow(node);
        }
        ConstantValue result;
        result.type = left.type;
        result.valid = true;
        result.signedValue = resultValue;
        result.unsignedValue = cast(ulong) resultValue;
        return result;
    }

    ConstantValue typeQuery(AstNode node) {
        auto type = model.types.resolve(node.children[0], model.target);
        auto size = node.text == "align_of" ? alignOf(type) : sizeOf(type);
        ConstantValue result;
        result.type = model.types.find("usize");
        result.valid = size != 0;
        result.unsignedValue = size;
        result.signedValue = cast(long) size;
        model.integerConstants[node.id] = result.signedValue;
        model.setType(node, result.type);
        if (!result.valid) diagnostics.error("OPENC-TYPE-QUERY-INCOMPLETE-001", DiagnosticPhase.constant,
            "constant.type_query", "type size or alignment is not known in this context", node.span);
        return result;
    }

    size_t sizeOf(TypeId type) {
        auto info = model.types.get(type);
        if (info.constQualified && info.element != type) return sizeOf(info.element);
        if (info.bits) return info.bits / 8;
        if (info.kind == TypeKind.boolean || info.kind == TypeKind.byteType) return 1;
        if (info.kind == TypeKind.pointer || info.kind == TypeKind.reference ||
            info.name == "usize" || info.name == "isize") return model.target.pointerWidth / 8;
        if (info.kind == TypeKind.text || info.kind == TypeKind.slice) return 2 * model.target.pointerWidth / 8;
        if (info.kind == TypeKind.status) return alignUp(4, model.target.pointerWidth / 8) + 2 * model.target.pointerWidth / 8;
        if (info.kind == TypeKind.fixedArray) return info.length * sizeOf(info.element);
        if (info.kind == TypeKind.optional) {
            auto alignment = alignOf(info.element);
            return alignUp(1, alignment) + alignUp(sizeOf(info.element), alignment);
        }
        if (info.kind == TypeKind.storage) return alignUp(sizeOf(info.element), alignOf(info.element)) + 1;
        if (info.kind == TypeKind.named) {
            foreach (symbol; model.symbols.symbols) {
                if (symbol.type != type || symbol.declaration is null) continue;
                if (symbol.kind == SymbolKind.enumSymbol) return 4;
                if (symbol.kind != SymbolKind.structSymbol && symbol.kind != SymbolKind.resourceSymbol) continue;
                size_t offset;
                size_t maximumAlignment = 1;
                foreach (field; symbol.declaration.children) {
                    auto fieldId = field.id in model.nodeSymbols;
                    if (fieldId is null) continue;
                    auto fieldType = model.symbols.get(*fieldId).type;
                    auto alignment = alignOf(fieldType);
                    maximumAlignment = max(maximumAlignment, alignment);
                    offset = alignUp(offset, alignment) + sizeOf(fieldType);
                }
                return max(cast(size_t) 1, alignUp(offset, maximumAlignment));
            }
        }
        return 0;
    }

    size_t alignOf(TypeId type) {
        auto info = model.types.get(type);
        if (info.constQualified && info.element != type) return alignOf(info.element);
        if (info.kind == TypeKind.fixedArray || info.kind == TypeKind.optional ||
            info.kind == TypeKind.storage) return alignOf(info.element);
        if (info.kind == TypeKind.named) {
            size_t result = 1;
            foreach (symbol; model.symbols.symbols) {
                if (symbol.type != type || symbol.declaration is null) continue;
                if (symbol.kind == SymbolKind.enumSymbol) return 4;
                foreach (field; symbol.declaration.children) {
                    auto fieldId = field.id in model.nodeSymbols;
                    if (fieldId !is null) result = max(result, alignOf(model.symbols.get(*fieldId).type));
                }
                return result;
            }
        }
        auto size = sizeOf(type);
        return size ? min(size, model.target.pointerWidth / 8) : 0;
    }

    size_t alignUp(size_t value, size_t alignment) {
        if (!alignment) return value;
        return (value + alignment - 1) / alignment * alignment;
    }

    ConstantValue typeError(AstNode node, string message) {
        diagnostics.error("OPENC-CONSTANT-TYPE-001", DiagnosticPhase.constant,
            "constant.type", message, node.span);
        return ConstantValue(model.types.errorType, false);
    }
    ConstantValue overflow(AstNode node) {
        diagnostics.error("OPENC-ARITH-STATIC-OVERFLOW-001", DiagnosticPhase.constant,
            "constant.overflow", "constant expression overflows its integer domain", node.span);
        return ConstantValue(model.types.errorType, false);
    }
    ConstantValue divideByZero(AstNode node) {
        diagnostics.error("OPENC-ARITH-DIVZERO-001", DiagnosticPhase.constant,
            "constant.divide_by_zero", "division or remainder by zero", node.span);
        return ConstantValue(model.types.errorType, false);
    }
    ConstantValue shiftError(AstNode node) {
        diagnostics.error("OPENC-ARITH-SHIFT-RANGE-001", DiagnosticPhase.constant,
            "constant.shift", "shift amount is outside the type width", node.span);
        return ConstantValue(model.types.errorType, false);
    }

    long checkedAdd(long a, long b, AstNode node) {
        if ((b > 0 && a > long.max - b) || (b < 0 && a < long.min - b)) throw new OverflowException();
        return a + b;
    }
    long checkedSub(long a, long b, AstNode node) {
        if ((b < 0 && a > long.max + b) || (b > 0 && a < long.min + b)) throw new OverflowException();
        return a - b;
    }
    long checkedMul(long a, long b, AstNode node) {
        if (a == 0 || b == 0) return 0;
        if (a == -1 && b == long.min) throw new OverflowException();
        if (b == -1 && a == long.min) throw new OverflowException();
        auto result = a * b;
        if (result / b != a) throw new OverflowException();
        return result;
    }
    long checkedShift(long value, uint amount, AstNode node) {
        if (amount == 0) return value;
        if (value > (long.max >> amount) || value < (long.min >> amount)) throw new OverflowException();
        return value << amount;
    }
}

private final class OverflowException : Exception {
    this() { super("constant overflow"); }
}
