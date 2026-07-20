module openc.backend_d;

import openc.ast : AstNode, NodeKind;
import openc.backend : Backend, BackendOutput;
import openc.common : Result, TypeId, ValueId;
import openc.ir : IrBlock, IrFunction, IrInstruction, IrModule, IrOpcode, IrOperand, IrProgram;
import openc.semantic_model : SemanticModel;
import openc.source : SourceManager;
import openc.symbol : Symbol, SymbolKind;
import openc.types : TypeKind;
import std.array : Appender, appender;
import std.algorithm.searching : canFind;
import std.conv : to;
import std.file : mkdirRecurse, write;
import std.path : buildPath;
import std.string : endsWith, lastIndexOf, replace, startsWith;

final class DSourceBackend : Backend {
private:
    ValueId[ValueId] referenceStorage;
    TypeId[ValueId] valueTypes;
    size_t nextScopeGuard;

public:
    string name() const { return "d-source"; }
    string description() const { return "Bootstrap backend that emits deterministic D source"; }

    Result!BackendOutput emit(IrProgram program, SemanticModel model, SourceManager sources, string outputDirectory) {
        try mkdirRecurse(outputDirectory);
        catch (Exception error) return Result!BackendOutput.failure("cannot create output directory: " ~ error.msg);

        BackendOutput output;
        foreach (moduleValue; program.modules) {
            auto path = buildPath(outputDirectory, mangleModule(moduleValue.name) ~ ".d");
            auto text = emitModule(moduleValue, model, program);
            try write(path, text);
            catch (Exception error) return Result!BackendOutput.failure("cannot write generated D source: " ~ error.msg);
            output.files ~= path;
            if (moduleValue.name == program.entryModule) output.primarySource = path;
        }
        if (!output.primarySource.length && output.files.length) output.primarySource = output.files[0];
        return Result!BackendOutput.success(output);
    }

private:
    string emitModule(IrModule moduleValue, SemanticModel model, IrProgram program) {
        auto output = appender!string();
        output.put("module generated." ~ mangleModule(moduleValue.name) ~ ";\n\n");
        output.put("import openc.runtime.types;\n");
        output.put("import openc.runtime.checked;\n");
        output.put("import openc.runtime.process : initializeArguments;\n");
        output.put("import openc.std.system_file;\n");
        output.put("import openc.std.system_io;\n");
        output.put("import openc.std.system_memory;\n");
        output.put("import openc.std.system_path;\n");
        output.put("import openc.std.system_process;\n");
        output.put("import openc.std.system_text;\n\n");
        emitTypeDeclarations(output, moduleValue.name, model);
        foreach (functionValue; moduleValue.functions) emitFunction(output, functionValue, model, program);
        if (moduleValue.name == program.entryModule) {
            output.put("int main(string[] args) {\n");
            output.put("    initializeArguments(args.length > 1 ? args[1 .. $] : []);\n");
            output.put("    try return cast(int) __openc_entry_main();\n");
            output.put("    catch (OpenCCheckedFailure failure) return reportOpenCFailure(failure);\n");
            output.put("    catch (OpenCTargetFault failure) return reportOpenCFailure(failure);\n");
            output.put("}\n");
        }
        return output.data;
    }

    void emitTypeDeclarations(ref Appender!string output, string moduleName, SemanticModel model) {
        auto logical = model.modules.find(moduleName);
        if (logical is null) return;
        foreach (symbol; model.symbols.symbols) {
            if (symbol.moduleId != logical.id || symbol.declaration is null) continue;
            if (symbol.kind == SymbolKind.structSymbol || symbol.kind == SymbolKind.resourceSymbol) {
                output.put("struct " ~ mangleType(symbol.qualifiedName) ~ " {\n");
                foreach (field; symbol.declaration.children) {
                    if (field.kind != NodeKind.fieldDecl) continue;
                    auto fieldId = field.id in model.nodeSymbols;
                    if (fieldId is null) continue;
                    output.put("    " ~ dType(model.symbols.get(*fieldId).type, model) ~
                        " " ~ field.text ~ ";\n");
                }
                output.put("}\n\n");
            } else if (symbol.kind == SymbolKind.enumSymbol) {
                auto underlying = symbol.declaration.get("underlying", "u32");
                if (!underlying.length) underlying = "u32";
                output.put("enum " ~ mangleType(symbol.qualifiedName) ~ " : " ~
                    dType(model.types.find(underlying), model) ~ " {\n");
                foreach (item; symbol.declaration.children) {
                    if (item.kind != NodeKind.enumItem) continue;
                    output.put("    " ~ item.text ~ " = " ~
                        model.integerConstants.get(item.id, 0).to!string ~ ",\n");
                }
                output.put("}\n\n");
            }
        }
    }

    void emitFunction(ref Appender!string output, IrFunction functionValue, SemanticModel model, IrProgram program) {
        referenceStorage = null;
        valueTypes = null;
        nextScopeGuard = 0;
        analyzeValues(functionValue, model);
        auto shortName = functionValue.name;
        auto dot = shortName.lastIndexOf('.');
        if (dot >= 0) shortName = shortName[dot + 1 .. $];
        auto returnType = dType(functionValue.result, model);
        bool entry = shortName == program.entryFunction && functionValue.name.startsWith(program.entryModule ~ ".");
        auto emittedName = entry ? "__openc_entry_main" : mangleFunction(functionValue.name);
        output.put(returnType ~ " " ~ emittedName ~ "(");
        foreach (index, type; functionValue.parameters) {
            if (index) output.put(", ");
            auto mode = functionValue.parameterModes[index];
            if (mode == "out") output.put("out ");
            else if (mode == "ref" || model.types.get(type).kind == TypeKind.reference) output.put("ref ");
            else if (mode == "own") output.put("ref ");
            else if (mode == "out_own") output.put("out ");
            output.put(dType(type, model) ~ " " ~ functionValue.parameterNames[index]);
        }
        output.put(") {\n");
        foreach (block; functionValue.blocks) {
            foreach (instruction; block.instructions) {
                if (!instruction.result ||
                    model.types.get(instruction.type).kind == TypeKind.voidType) continue;
                auto valueType = dValueType(instruction.type, model);
                if (instruction.opcode == IrOpcode.aggregateField &&
                    instruction.text.endsWith(":address")) valueType ~= "*";
                output.put("    " ~ valueType ~ " v" ~ instruction.result.to!string ~ ";\n");
            }
        }
        size_t guardIndex;
        foreach (block; functionValue.blocks) {
            foreach (instruction; block.instructions) {
                if (instruction.opcode != IrOpcode.scopeRegister) continue;
                output.put("    bool scope_active_" ~ guardIndex.to!string ~ ";\n");
                output.put("    scope(exit) { if (scope_active_" ~ guardIndex.to!string ~ ") { ");
                emitScopeAction(output, instruction);
                output.put("; } }\n");
                ++guardIndex;
            }
        }
        foreach (block; functionValue.blocks) {
            output.put("block_" ~ block.id.to!string ~ ":\n");
            if (!block.instructions.length) output.put("    ;\n");
            foreach (instruction; block.instructions) {
                emitInstruction(
                    output, instruction, model, returnType, functionValue.parameterNames);
            }
        }
        if (returnType == "void") output.put("    return;\n");
        else output.put("    openc.runtime.checked.opencCheckedFailure(\"function completed without a return\");\n");
        output.put("}\n\n");
    }

    void emitInstruction(
        ref Appender!string output,
        IrInstruction instruction,
        SemanticModel model,
        string returnType,
        string[] parameterNames
    ) {
        if (instruction.result) valueTypes[instruction.result] = instruction.type;
        auto producesValue = instruction.result &&
            model.types.get(instruction.type).kind != TypeKind.voidType;
        string lhs = producesValue ? "    v" ~ instruction.result.to!string ~ " = " : "    ";
        switch (instruction.opcode) {
            case IrOpcode.nop:
                if (instruction.text == "null") {
                    output.put(lhs ~ "cast(" ~ dType(instruction.type, model) ~ ") null;\n");
                } else if (producesValue) {
                    output.put(lhs ~ dType(instruction.type, model) ~ ".init;\n");
                }
                break;
            case IrOpcode.constantInteger:
                output.put(lhs ~ "cast(" ~ dType(instruction.type, model) ~ ") (" ~
                    instruction.text ~ ");\n"); break;
            case IrOpcode.constantFloat:
            case IrOpcode.constantBool:
                output.put(lhs ~ instruction.text ~ ";\n"); break;
            case IrOpcode.constantText:
                output.put(lhs ~ instruction.text ~ ";\n"); break;
            case IrOpcode.allocateLocal:
                if (parameterNames.canFind(instruction.text)) {
                    output.put("    v" ~ instruction.result.to!string ~
                        (model.types.get(instruction.type).kind == TypeKind.reference
                            ? " = &" ~ instruction.text
                            : " = " ~ instruction.text) ~ ";\n");
                }
                output.put("    // local " ~ instruction.text ~ "\n");
                break;
            case IrOpcode.load:
                auto source = instruction.operands[0].value;
                auto sourceType = valueTypes.get(source, model.types.errorType);
                auto preserveReference = model.types.get(instruction.type).kind == TypeKind.reference;
                output.put(lhs ~
                    (model.types.get(sourceType).kind == TypeKind.reference && !preserveReference
                        ? "*v" : "v") ~
                    source.to!string ~ ";\n");
                propagateReference(instruction.result, instruction.operands[0].value);
                break;
            case IrOpcode.store:
                auto destination = "v" ~ instruction.operands[0].value.to!string;
                auto destinationType = valueTypes.get(instruction.operands[0].value, model.types.errorType);
                bool assignReferent = model.types.get(destinationType).kind == TypeKind.reference &&
                    instruction.operands[0].immediate != "bind";
                auto target = assignReferent || instruction.operands[0].immediate == "deref"
                    ? "*" ~ destination : destination;
                output.put("    " ~ target ~ " = cast(typeof(" ~ target ~ ")) v" ~
                    instruction.operands[1].value.to!string ~ ";\n");
                propagateReference(instruction.operands[0].value, instruction.operands[1].value);
                break;
            case IrOpcode.unary:
                if (instruction.text == "-" && isInteger(instruction.type, model)) {
                    output.put(lhs ~ "checkedSub(cast(" ~ dType(instruction.type, model) ~ ") 0, v" ~
                        instruction.operands[0].value.to!string ~ ");\n");
                } else {
                    output.put(lhs ~ instruction.text ~ "v" ~ instruction.operands[0].value.to!string ~ ";\n");
                }
                break;
            case IrOpcode.addressOf:
                output.put(lhs ~ "&v" ~ instruction.operands[0].value.to!string ~ ";\n"); break;
            case IrOpcode.binary:
                auto left = "v" ~ instruction.operands[0].value.to!string;
                auto right = "v" ~ instruction.operands[1].value.to!string;
                if (isInteger(instruction.type, model)) {
                    string helper;
                    switch (instruction.text) {
                        case "+": helper = "checkedAdd"; break;
                        case "-": helper = "checkedSub"; break;
                        case "*": helper = "checkedMul"; break;
                        case "/": helper = "checkedDiv"; break;
                        case "%": helper = "checkedRem"; break;
                        case "<<": helper = "checkedShiftLeft"; break;
                        case ">>": helper = "checkedShiftRight"; break;
                        default: break;
                    }
                    if (helper.length) {
                        output.put(lhs ~ helper ~ "(" ~ left ~ ", " ~ right ~ ");\n");
                        break;
                    }
                }
                output.put(lhs ~ left ~ " " ~ instruction.text ~ " " ~ right ~ ";\n");
                break;
            case IrOpcode.shortCircuitBegin:
                auto left = "v" ~ instruction.operands[0].value.to!string;
                output.put("    v" ~ instruction.result.to!string ~ " = " ~ left ~ ";\n");
                output.put("    if (" ~ (instruction.text == "&&" ? left : "!" ~ left) ~ ") {\n");
                break;
            case IrOpcode.shortCircuitEnd:
                output.put("        v" ~ instruction.operands[0].value.to!string ~ " = v" ~
                    instruction.operands[1].value.to!string ~ ";\n");
                output.put("    }\n");
                break;
            case IrOpcode.compare:
                output.put(lhs ~ "v" ~ instruction.operands[0].value.to!string ~ " " ~ instruction.text ~ " v" ~ instruction.operands[1].value.to!string ~ ";\n"); break;
            case IrOpcode.castValue:
                output.put(lhs ~ "checkedCast!(" ~ dType(instruction.type, model) ~ ")(v" ~
                    instruction.operands[0].value.to!string ~ ");\n"); break;
            case IrOpcode.reinterpret:
                output.put(lhs ~ "cast(" ~ dType(instruction.type, model) ~ ") v" ~
                    instruction.operands[0].value.to!string ~ ";\n"); break;
            case IrOpcode.call:
                auto callName = emittedCallName(instruction.text);
                output.put(lhs);
                if (instruction.text == "system.memory.alloc") {
                    output.put("cast(" ~ dType(instruction.type, model) ~ ") ");
                }
                output.put(callName ~ "(");
                foreach (index, operand; instruction.operands) {
                    if (index) output.put(", ");
                    auto parameter = callParameterType(instruction.text, index, model);
                    output.put(model.types.get(parameter).kind == TypeKind.reference ? "*v" : "v");
                    output.put(operand.value.to!string);
                }
                output.put(");\n");
                break;
            case IrOpcode.branch:
                output.put("    goto block_" ~ instruction.operands[0].immediate ~ ";\n");
                break;
            case IrOpcode.conditionalBranch:
                output.put("    if (v" ~ instruction.operands[0].value.to!string ~
                    ") goto block_" ~ instruction.operands[1].immediate ~
                    "; else goto block_" ~ instruction.operands[2].immediate ~ ";\n");
                break;
            case IrOpcode.returnValue:
                output.put("    return cast(" ~ returnType ~ ") v" ~
                    instruction.operands[0].value.to!string ~ ";\n"); break;
            case IrOpcode.returnVoid:
                output.put("    return;\n"); break;
            case IrOpcode.scopeRegister:
                output.put("    scope_active_" ~ nextScopeGuard.to!string ~ " = true;\n");
                ++nextScopeGuard;
                break;
            case IrOpcode.objectConstruct:
                output.put("    v" ~ instruction.result.to!string ~ " = &v" ~
                    instruction.operands[0].value.to!string ~ ".construct(v" ~
                    instruction.operands[1].value.to!string ~ ");\n");
                referenceStorage[instruction.result] = instruction.operands[0].value;
                break;
            case IrOpcode.objectDestroy:
                auto source = instruction.operands[0].value;
                auto storage = source in referenceStorage;
                if (storage !is null) {
                    output.put("    v" ~ (*storage).to!string ~ ".destroyValue();\n");
                } else output.put("    destroy(v" ~ source.to!string ~ ");\n");
                break;
            case IrOpcode.statusCreate:
                string code = "0";
                string message = "\"\"";
                foreach (operand; instruction.operands) {
                    if (operand.immediate == "code") code = "v" ~ operand.value.to!string;
                    else if (operand.immediate == "message") message = "v" ~ operand.value.to!string;
                }
                output.put(lhs ~ "Status(" ~ code ~ ", " ~ message ~ ");\n"); break;
            case IrOpcode.aggregateCreate:
                emitAggregateCreate(output, instruction, model);
                break;
            case IrOpcode.arrayCreate:
                output.put("    v" ~ instruction.result.to!string ~ " = [");
                foreach (index, operand; instruction.operands) {
                    if (index) output.put(", ");
                    output.put("v" ~ operand.value.to!string);
                }
                output.put("];\n");
                break;
            case IrOpcode.aggregateField:
                auto address = instruction.text.endsWith(":address");
                auto field = address
                    ? instruction.text[0 .. $ - ":address".length]
                    : instruction.text;
                output.put(address ? "    v" ~ instruction.result.to!string ~ " = &" : lhs);
                output.put("v" ~ instruction.operands[0].value.to!string);
                if (field == "index") {
                    output.put("[v" ~ instruction.operands[1].value.to!string ~ "]");
                } else {
                    if (field == "present") field = "hasValue";
                    output.put("." ~ field);
                }
                output.put(";\n");
                break;
            case IrOpcode.optionalNone:
                output.put(lhs ~ dType(instruction.type, model) ~ ".none();\n");
                break;
            case IrOpcode.optionalSome:
                output.put(lhs ~ dType(instruction.type, model) ~ ".some(v" ~
                    instruction.operands[0].value.to!string ~ ");\n");
                break;
            case IrOpcode.boundsCheck:
                output.put("    if (v" ~ instruction.operands[1].value.to!string ~
                    " >= v" ~ instruction.operands[0].value.to!string ~
                    ".length) openc.runtime.checked.opencCheckedFailure(\"index out of bounds\");\n");
                break;
            case IrOpcode.checkedFailure:
                output.put("    opencCheckedFailure(" ~ quote(instruction.text) ~ ");\n"); break;
            case IrOpcode.targetFault:
                output.put("    opencTargetFault(" ~ quote(instruction.text) ~ ");\n"); break;
            default:
                output.put("    // " ~ cast(string) instruction.opcode ~ " " ~ instruction.text ~ "\n"); break;
        }
    }

    TypeId callParameterType(string qualifiedName, size_t index, SemanticModel model) {
        foreach (symbol; model.symbols.symbols) {
            if (symbol.kind == SymbolKind.functionSymbol && symbol.qualifiedName == qualifiedName &&
                index < symbol.signature.parameters.length) return symbol.signature.parameters[index];
        }
        return model.types.errorType;
    }

    void emitAggregateCreate(
        ref Appender!string output,
        IrInstruction instruction,
        SemanticModel model
    ) {
        auto typeName = dType(instruction.type, model);
        auto valueName = "v" ~ instruction.result.to!string;
        bool[string] explicitFields;
        foreach (operand; instruction.operands) {
            auto field = operand.immediate;
            if (field.endsWith(":own")) field = field[0 .. $ - ":own".length];
            explicitFields[field] = true;
            output.put("    " ~ valueName ~ "." ~ field ~ " = cast(typeof(" ~
                valueName ~ "." ~ field ~ ")) v" ~ operand.value.to!string ~ ";\n");
        }

        auto aggregate = aggregateSymbol(instruction.type, model);
        if (aggregate is null || aggregate.declaration is null) return;
        foreach (field; aggregate.declaration.children) {
            if (field.kind != NodeKind.fieldDecl || field.text in explicitFields ||
                field.children.length < 2) continue;
            output.put("    " ~ valueName ~ "." ~ field.text ~ " = cast(typeof(" ~
                valueName ~ "." ~ field.text ~ ")) (" ~
                emitExpression(field.children[1], model) ~ ");\n");
        }
    }

    Symbol aggregateSymbol(TypeId type, SemanticModel model) {
        foreach (symbol; model.symbols.symbols) {
            if ((symbol.kind == SymbolKind.structSymbol || symbol.kind == SymbolKind.resourceSymbol) &&
                symbol.type == type) return symbol;
        }
        return null;
    }

    string emitExpression(AstNode node, SemanticModel model) {
        if (node is null) return "0";
        switch (node.kind) {
            case NodeKind.integerLiteral:
                return "cast(" ~ dType(model.typeOf(node), model) ~ ") (" ~ node.text ~ ")";
            case NodeKind.floatLiteral:
            case NodeKind.textLiteral:
            case NodeKind.boolLiteral:
                return node.text;
            case NodeKind.nullLiteral:
                return "null";
            case NodeKind.qualifiedName:
                auto symbolId = node.id in model.nodeSymbols;
                if (symbolId !is null) {
                    auto symbol = model.symbols.get(*symbolId);
                    if (symbol.kind == SymbolKind.enumItemSymbol) return
                        mangleType(model.types.get(symbol.type).name) ~ "." ~ symbol.name;
                    return mangleFunction(symbol.qualifiedName);
                }
                return node.text.replace(".", "_");
            case NodeKind.callExpr:
                auto target = node.id in model.nodeSymbols;
                auto callName = target is null
                    ? emittedCallName(node.children[0].text)
                    : emittedCallName(model.symbols.get(*target).qualifiedName);
                string[] arguments;
                foreach (argument; node.children[1 .. $]) arguments ~= emitExpression(argument, model);
                import std.array : join;
                return callName ~ "(" ~ arguments.join(", ") ~ ")";
            case NodeKind.unaryExpr:
                return "(" ~ node.text ~ emitExpression(node.children[0], model) ~ ")";
            case NodeKind.binaryExpr:
                return "(" ~ emitExpression(node.children[0], model) ~ " " ~ node.text ~ " " ~
                    emitExpression(node.children[1], model) ~ ")";
            case NodeKind.castExpr:
                return "checkedCast!(" ~ dType(model.typeOf(node), model) ~ ")(" ~
                    emitExpression(node.children[1], model) ~ ")";
            default:
                return dType(model.typeOf(node), model) ~ ".init";
        }
    }

    void propagateReference(ValueId destination, ValueId source) {
        auto storage = source in referenceStorage;
        if (storage !is null) referenceStorage[destination] = *storage;
        else referenceStorage.remove(destination);
    }

    void analyzeValues(IrFunction functionValue, SemanticModel model) {
        foreach (block; functionValue.blocks) {
            foreach (instruction; block.instructions) {
                if (instruction.result) valueTypes[instruction.result] = instruction.type;
                switch (instruction.opcode) {
                    case IrOpcode.objectConstruct:
                        referenceStorage[instruction.result] = instruction.operands[0].value;
                        break;
                    case IrOpcode.load:
                        propagateReference(instruction.result, instruction.operands[0].value);
                        break;
                    case IrOpcode.store:
                        propagateReference(instruction.operands[0].value,
                            instruction.operands[1].value);
                        break;
                    default: break;
                }
            }
        }
    }

    void emitScopeAction(ref Appender!string output, IrInstruction instruction) {
        if (instruction.text == "destroy") {
            auto source = instruction.operands[0].value;
            auto storage = source in referenceStorage;
            if (storage !is null) output.put("v" ~ (*storage).to!string ~ ".destroyValue()");
            else output.put("destroy(v" ~ source.to!string ~ ")");
        } else if (instruction.text != "unsupported") {
            output.put(emittedCallName(instruction.text) ~ "(");
            foreach (index, operand; instruction.operands) {
                if (index) output.put(", ");
                output.put("v" ~ operand.value.to!string);
            }
            output.put(")");
        }
    }

    string dType(TypeId id, SemanticModel model) {
        auto type = model.types.get(id);
        switch (type.kind) {
            case TypeKind.voidType: return "void";
            case TypeKind.signedInteger:
                if (type.name == "i8") return "byte";
                if (type.name == "i16") return "short";
                if (type.name == "i32") return "int";
                if (type.name == "i64") return "long";
                if (type.name == "isize") return "ptrdiff_t";
                return "long";
            case TypeKind.unsignedInteger:
                if (type.name == "u8") return "ubyte";
                if (type.name == "u16") return "ushort";
                if (type.name == "u32") return "uint";
                if (type.name == "u64") return "ulong";
                if (type.name == "usize") return "size_t";
                return "ulong";
            case TypeKind.byteType: return "ubyte";
            case TypeKind.boolean: return "bool";
            case TypeKind.floating: return type.name == "f32" ? "float" : "double";
            case TypeKind.text: return "string";
            case TypeKind.status: return "Status";
            case TypeKind.reference: return type.constQualified
                ? "const(" ~ dType(type.element, model) ~ ")"
                : dType(type.element, model);
            case TypeKind.pointer: return dType(type.element, model) ~ "*";
            case TypeKind.optional: return "OpenCOptional!(" ~ dType(type.element, model) ~ ")";
            case TypeKind.storage: return "OpenCStorage!(" ~ dType(type.element, model) ~ ")";
            case TypeKind.fixedArray: return dType(type.element, model) ~ "[" ~ type.length.to!string ~ "]";
            case TypeKind.slice: return dType(type.element, model) ~ "[]";
            case TypeKind.named: return mangleType(type.name);
            default: return "void";
        }
    }

    string dValueType(TypeId id, SemanticModel model) {
        auto type = model.types.get(id);
        if (type.kind == TypeKind.reference) return dType(id, model) ~ "*";
        return dType(id, model);
    }

    bool isInteger(TypeId id, SemanticModel model) {
        auto kind = model.types.get(id).kind;
        return kind == TypeKind.signedInteger ||
            kind == TypeKind.unsignedInteger || kind == TypeKind.byteType;
    }

    string mangleModule(string name) { return name.replace(".", "_"); }
    string mangleFunction(string name) { return name.replace(".", "_"); }
    string emittedCallName(string name) {
        if (name.endsWith(".saturating_add")) return "saturatingAdd";
        if (name.endsWith(".saturating_sub")) return "saturatingSub";
        if (name.endsWith(".saturating_mul")) return "saturatingMul";
        foreach (moduleName; [
            "system.io.", "system.memory.", "system.text.",
            "system.process.", "system.path.", "system.file."
        ]) {
            if (name.startsWith(moduleName)) {
                auto modulePath = moduleName[0 .. $ - 1].replace(".", "_");
                return "openc.std." ~ modulePath ~ "." ~ name[moduleName.length .. $];
            }
        }
        return mangleFunction(name);
    }
    string mangleType(string name) { auto dot = name.lastIndexOf('.'); return dot >= 0 ? name[dot + 1 .. $] : name; }
    string quote(string value) { return "\"" ~ value.replace("\\", "\\\\").replace("\"", "\\\"") ~ "\""; }
}
