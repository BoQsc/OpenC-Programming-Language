module openc.ir;

import openc.common : BlockId, TypeId, ValueId;
import openc.source : SourceSpan;
import std.json : JSONValue;

enum IrOpcode : string {
    nop = "nop",
    constantInteger = "const.integer",
    constantFloat = "const.float",
    constantText = "const.text",
    constantBool = "const.bool",
    allocateLocal = "local.alloc",
    load = "load",
    store = "store",
    unary = "unary",
    binary = "binary",
    compare = "compare",
    castValue = "cast",
    reinterpret = "reinterpret",
    addressOf = "address_of",
    pointerOffset = "pointer.offset",
    boundsCheck = "bounds.check",
    overflowCheck = "overflow.check",
    call = "call",
    branch = "branch",
    conditionalBranch = "branch.conditional",
    returnValue = "return",
    returnVoid = "return.void",
    aggregateCreate = "aggregate.create",
    aggregateField = "aggregate.field",
    arrayCreate = "array.create",
    sliceCreate = "slice.create",
    optionalNone = "optional.none",
    optionalSome = "optional.some",
    statusCreate = "status.create",
    resourceReserve = "resource.reserve",
    resourceCommit = "resource.commit",
    resourceMove = "resource.move",
    resourceDestroy = "resource.destroy",
    scopeRegister = "scope.register",
    scopeRun = "scope.run",
    storageCreate = "storage.create",
    objectConstruct = "object.construct",
    objectDestroy = "object.destroy",
    checkedFailure = "checked.failure",
    targetFault = "target.fault"
}

struct IrOperand {
    ValueId value;
    string immediate;
}

struct IrInstruction {
    ValueId result;
    IrOpcode opcode;
    TypeId type;
    IrOperand[] operands;
    string text;
    SourceSpan span;

    JSONValue toJson() const {
        JSONValue value;
        value["result"] = result;
        value["opcode"] = cast(string) opcode;
        value["type"] = type;
        value["text"] = text;
        value["source"] = span.source.value;
        value["start"] = span.start;
        value["length"] = span.length;
        JSONValue[] args;
        foreach (operand; operands) {
            JSONValue arg;
            arg["value"] = operand.value;
            arg["immediate"] = operand.immediate;
            args ~= arg;
        }
        value["operands"] = JSONValue(args);
        return value;
    }
}

final class IrBlock {
    BlockId id;
    string name;
    IrInstruction[] instructions;

    this(BlockId id, string name) {
        this.id = id;
        this.name = name;
    }
}

final class IrFunction {
    string name;
    TypeId result;
    TypeId[] parameters;
    string[] parameterNames;
    string[] parameterModes;
    IrBlock[] blocks;
    bool unsafeFunction;
    bool exported;

    IrBlock addBlock(string name) {
        auto block = new IrBlock(cast(BlockId) blocks.length, name);
        blocks ~= block;
        return block;
    }
}

final class IrModule {
    string name;
    IrFunction[] functions;
    string[] imports;

    JSONValue toJson() const {
        JSONValue root;
        root["module"] = name;
        JSONValue[] functionJson;
        foreach (functionValue; functions) {
            JSONValue f;
            f["name"] = functionValue.name;
            f["result"] = functionValue.result;
            f["unsafe"] = functionValue.unsafeFunction;
            f["exported"] = functionValue.exported;
            JSONValue[] blockJson;
            foreach (block; functionValue.blocks) {
                JSONValue b;
                b["id"] = block.id;
                b["name"] = block.name;
                JSONValue[] instructionJson;
                foreach (instruction; block.instructions) instructionJson ~= instruction.toJson();
                b["instructions"] = JSONValue(instructionJson);
                blockJson ~= b;
            }
            f["blocks"] = JSONValue(blockJson);
            functionJson ~= f;
        }
        root["functions"] = JSONValue(functionJson);
        return root;
    }
}

final class IrProgram {
    IrModule[] modules;
    string entryModule;
    string entryFunction;

    JSONValue toJson() const {
        JSONValue root;
        root["schema"] = "openc.core_ir.v1";
        root["entry_module"] = entryModule;
        root["entry_function"] = entryFunction;
        JSONValue[] moduleJson;
        foreach (moduleValue; modules) moduleJson ~= moduleValue.toJson();
        root["modules"] = JSONValue(moduleJson);
        return root;
    }
}
