module openc.backend_d;

import openc.backend : Backend, BackendOutput;
import openc.common : Result, TypeId;
import openc.ir : IrBlock, IrFunction, IrInstruction, IrModule, IrOpcode, IrOperand, IrProgram;
import openc.semantic_model : SemanticModel;
import openc.source : SourceManager;
import openc.types : TypeKind;
import std.array : Appender, appender;
import std.conv : to;
import std.file : mkdirRecurse, write;
import std.path : buildPath;
import std.string : lastIndexOf, replace, startsWith;

final class DSourceBackend : Backend {
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
        output.put("import openc.std.system_io;\n");
        output.put("import openc.std.system_memory;\n\n");
        foreach (functionValue; moduleValue.functions) emitFunction(output, functionValue, model, program);
        return output.data;
    }

    void emitFunction(ref Appender!string output, IrFunction functionValue, SemanticModel model, IrProgram program) {
        auto shortName = functionValue.name;
        auto dot = shortName.lastIndexOf('.');
        if (dot >= 0) shortName = shortName[dot + 1 .. $];
        auto returnType = dType(functionValue.result, model);
        bool entry = shortName == program.entryFunction && functionValue.name.startsWith(program.entryModule ~ ".");
        if (entry) output.put("extern(C) ");
        output.put(returnType ~ " " ~ shortName ~ "(");
        foreach (index, type; functionValue.parameters) {
            if (index) output.put(", ");
            auto mode = functionValue.parameterModes[index];
            if (mode == "out") output.put("out ");
            else if (mode == "own") output.put("ref ");
            else if (mode == "out_own") output.put("out ");
            output.put(dType(type, model) ~ " " ~ functionValue.parameterNames[index]);
        }
        output.put(") {\n");
        foreach (block; functionValue.blocks) {
            output.put("    // IR block " ~ block.name ~ "\n");
            foreach (instruction; block.instructions) emitInstruction(output, instruction, model);
        }
        if (returnType == "void") output.put("    return;\n");
        output.put("}\n\n");
    }

    void emitInstruction(ref Appender!string output, IrInstruction instruction, SemanticModel model) {
        string lhs = instruction.result ? "    auto v" ~ instruction.result.to!string ~ " = " : "    ";
        switch (instruction.opcode) {
            case IrOpcode.constantInteger:
            case IrOpcode.constantFloat:
            case IrOpcode.constantBool:
                output.put(lhs ~ instruction.text ~ ";\n"); break;
            case IrOpcode.constantText:
                output.put(lhs ~ instruction.text ~ ";\n"); break;
            case IrOpcode.allocateLocal:
                output.put("    " ~ dType(instruction.type, model) ~ " v" ~ instruction.result.to!string ~ "; // " ~ instruction.text ~ "\n"); break;
            case IrOpcode.load:
                output.put(lhs ~ "v" ~ instruction.operands[0].value.to!string ~ ";\n"); break;
            case IrOpcode.store:
                output.put("    v" ~ instruction.operands[0].value.to!string ~ " = v" ~ instruction.operands[1].value.to!string ~ ";\n"); break;
            case IrOpcode.unary:
            case IrOpcode.addressOf:
                output.put(lhs ~ instruction.text ~ "v" ~ instruction.operands[0].value.to!string ~ ";\n"); break;
            case IrOpcode.binary:
            case IrOpcode.compare:
                output.put(lhs ~ "v" ~ instruction.operands[0].value.to!string ~ " " ~ instruction.text ~ " v" ~ instruction.operands[1].value.to!string ~ ";\n"); break;
            case IrOpcode.call:
                output.put(lhs ~ mangleFunction(instruction.text) ~ "(");
                foreach (index, operand; instruction.operands) {
                    if (index) output.put(", ");
                    output.put("v" ~ operand.value.to!string);
                }
                output.put(");\n");
                break;
            case IrOpcode.returnValue:
                output.put("    return v" ~ instruction.operands[0].value.to!string ~ ";\n"); break;
            case IrOpcode.returnVoid:
                output.put("    return;\n"); break;
            case IrOpcode.scopeRegister:
                output.put("    scope(exit) { /* cleanup value v" ~ instruction.operands[0].value.to!string ~ " */ }\n"); break;
            case IrOpcode.statusCreate:
                string code = "0";
                string message = "\"\"";
                foreach (operand; instruction.operands) {
                    if (operand.immediate == "code") code = "v" ~ operand.value.to!string;
                    else if (operand.immediate == "message") message = "v" ~ operand.value.to!string;
                }
                output.put(lhs ~ "Status(" ~ code ~ ", " ~ message ~ ");\n"); break;
            case IrOpcode.checkedFailure:
                output.put("    opencCheckedFailure(" ~ quote(instruction.text) ~ ");\n"); break;
            case IrOpcode.targetFault:
                output.put("    opencTargetFault(" ~ quote(instruction.text) ~ ");\n"); break;
            default:
                output.put("    // " ~ cast(string) instruction.opcode ~ " " ~ instruction.text ~ "\n"); break;
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
            case TypeKind.reference: return (type.constQualified ? "const " : "ref ") ~ dType(type.element, model);
            case TypeKind.pointer: return dType(type.element, model) ~ "*";
            case TypeKind.optional: return "OpenCOptional!(" ~ dType(type.element, model) ~ ")";
            case TypeKind.storage: return "OpenCStorage!(" ~ dType(type.element, model) ~ ")";
            case TypeKind.fixedArray: return dType(type.element, model) ~ "[" ~ type.length.to!string ~ "]";
            case TypeKind.slice: return dType(type.element, model) ~ "[]";
            case TypeKind.named: return mangleType(type.name);
            default: return "void";
        }
    }

    string mangleModule(string name) { return name.replace(".", "_"); }
    string mangleFunction(string name) { return name.replace(".", "_"); }
    string mangleType(string name) { auto dot = name.lastIndexOf('.'); return dot >= 0 ? name[dot + 1 .. $] : name; }
    string quote(string value) { return "\"" ~ value.replace("\\", "\\\\").replace("\"", "\\\"") ~ "\""; }
}
