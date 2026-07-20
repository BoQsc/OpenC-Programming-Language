module openc.common;

import std.algorithm : sort;
import std.array : array;
import std.conv : to;
import std.json : JSONValue;
import std.string : join;

alias NodeId = size_t;
alias SymbolId = size_t;
alias TypeId = size_t;
alias ScopeId = size_t;
alias ModuleId = size_t;
alias BlockId = size_t;
alias ValueId = size_t;

enum EvidenceState : string {
    authored = "AUTHORED",
    structurallyChecked = "STRUCTURALLY_CHECKED",
    reviewed = "REVIEWED",
    executionPending = "EXECUTION_PENDING",
    executed = "EXECUTED",
    releaseReady = "RELEASE_READY",
    released = "RELEASED"
}

enum TargetOS : string {
    linux = "linux",
    windows = "windows",
    freestanding = "freestanding",
    unknown = "unknown"
}

enum TargetArch : string {
    x86_64 = "x86_64",
    aarch64 = "aarch64",
    unknown = "unknown"
}

struct TargetContext {
    TargetOS os = TargetOS.unknown;
    TargetArch arch = TargetArch.unknown;
    size_t pointerWidth = 0;
    string endian = "little";
    string abi = "openc";
    string[string] values;

    string qualifiedValue(string name) const {
        auto found = name in values;
        return found is null ? "" : *found;
    }

    JSONValue toJson() const {
        JSONValue result;
        result["os"] = cast(string) os;
        result["arch"] = cast(string) arch;
        result["pointer_width"] = pointerWidth;
        result["endian"] = endian;
        result["abi"] = abi;
        JSONValue map;
        foreach (key, value; values) {
            map[key] = value;
        }
        result["values"] = map;
        return result;
    }
}

struct CompilerVersion {
    string languageVersion = "1.0";
    string implementationVersion = "1.0.0-rc.1";
    string implementationName = "OpenC reference compiler";

    JSONValue toJson() const {
        JSONValue result;
        result["language_version"] = languageVersion;
        result["implementation_version"] = implementationVersion;
        result["implementation_name"] = implementationName;
        return result;
    }
}

string stableJoin(const string[] values, string separator = ",") {
    auto copy = values.dup;
    copy.sort();
    return copy.join(separator);
}

string stableKey(string[] parts) {
    return parts.join("::");
}

struct Result(T) {
    bool ok;
    T value;
    string error;

    static Result success(T value) {
        return Result(true, value, "");
    }

    static Result failure(string message) {
        T empty;
        return Result(false, empty, message);
    }
}
