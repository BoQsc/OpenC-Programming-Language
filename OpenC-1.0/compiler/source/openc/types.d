module openc.types;

import openc.ast : AstNode, NodeKind;
import openc.common : TargetContext, TypeId;
import std.algorithm.searching : canFind;
import std.conv : to;

enum TypeKind : string {
    errorType = "error",
    voidType = "void",
    signedInteger = "signed_integer",
    unsignedInteger = "unsigned_integer",
    floating = "floating",
    boolean = "bool",
    byteType = "byte",
    text = "text",
    status = "status",
    named = "named",
    fixedArray = "fixed_array",
    slice = "slice",
    reference = "ref",
    pointer = "ptr",
    optional = "optional",
    storage = "storage"
}

final class OpenCTypeInfo {
    TypeId id;
    TypeKind kind;
    string name;
    TypeId element;
    size_t length;
    size_t bits;
    bool constQualified;
    bool resource;
    bool complete = true;

    this(TypeId id, TypeKind kind, string name) {
        this.id = id;
        this.kind = kind;
        this.name = name;
    }

    string display(TypeTable table) const {
        switch (kind) {
            case TypeKind.reference: return "ref " ~ (constQualified ? "const " : "") ~ table.get(element).display(table);
            case TypeKind.pointer: return "ptr " ~ (constQualified ? "const " : "") ~ table.get(element).display(table);
            case TypeKind.optional: return (constQualified ? "const " : "") ~ "optional " ~ table.get(element).display(table);
            case TypeKind.storage: return "storage " ~ table.get(element).display(table);
            case TypeKind.fixedArray: return table.get(element).display(table) ~ "[" ~ length.to!string ~ "]";
            case TypeKind.slice: return table.get(element).display(table) ~ "[]";
            default: return (constQualified ? "const " : "") ~ name;
        }
    }

    bool integer() const {
        return kind == TypeKind.signedInteger || kind == TypeKind.unsignedInteger || kind == TypeKind.byteType;
    }
    bool numeric() const { return integer() || kind == TypeKind.floating; }
    bool scalar() const {
        return numeric() || kind == TypeKind.boolean || kind == TypeKind.pointer || kind == TypeKind.named;
    }
}

final class TypeTable {
private:
    OpenCTypeInfo[] types;
    TypeId[string] canonical;

public:
    TypeId errorType;
    TypeId voidType;
    TypeId boolType;
    TypeId byteType;
    TypeId textType;
    TypeId statusType;

    this() {
        errorType = add(TypeKind.errorType, "<error>");
        voidType = add(TypeKind.voidType, "void");
        boolType = add(TypeKind.boolean, "bool");
        byteType = addInteger(TypeKind.byteType, "byte", 8);
        textType = add(TypeKind.text, "text");
        statusType = add(TypeKind.status, "status");
        foreach (bits; [8, 16, 32, 64]) {
            addInteger(TypeKind.signedInteger, "i" ~ bits.to!string, bits);
            addInteger(TypeKind.unsignedInteger, "u" ~ bits.to!string, bits);
        }
        addInteger(TypeKind.signedInteger, "isize", 0);
        addInteger(TypeKind.unsignedInteger, "usize", 0);
        addFloat("f32", 32);
        addFloat("f64", 64);
    }

    OpenCTypeInfo get(TypeId id) { return types[id]; }
    const(OpenCTypeInfo) get(TypeId id) const { return types[id]; }
    TypeId find(string name) const {
        auto found = name in canonical;
        return found is null ? errorType : *found;
    }

    TypeId declareNamed(string name, bool resource = false) {
        auto existing = name in canonical;
        if (existing !is null) return *existing;
        auto id = add(TypeKind.named, name);
        get(id).resource = resource;
        return id;
    }

    TypeId reference(TypeId element, bool constQualified) {
        return derived(TypeKind.reference, element, 0, constQualified);
    }
    TypeId pointer(TypeId element, bool constQualified) {
        return derived(TypeKind.pointer, element, 0, constQualified);
    }
    TypeId optional(TypeId element, bool constQualified) {
        return derived(TypeKind.optional, element, 0, constQualified);
    }
    TypeId storage(TypeId element) {
        return derived(TypeKind.storage, element, 0, false);
    }
    TypeId fixedArray(TypeId element, size_t length, bool constQualified = false) {
        return derived(TypeKind.fixedArray, element, length, constQualified);
    }
    TypeId slice(TypeId element, bool constQualified = false) {
        return derived(TypeKind.slice, element, 0, constQualified);
    }

    bool same(TypeId a, TypeId b) const { return a == b; }

    bool lossless(TypeId source, TypeId target, const(TargetContext) context) const {
        if (source == target) return true;
        auto from = get(source);
        auto toType = get(target);
        if (from.kind == TypeKind.reference && toType.kind == TypeKind.reference &&
            from.element == toType.element && !from.constQualified && toType.constQualified) return true;
        if (from.kind == TypeKind.fixedArray && toType.kind == TypeKind.slice && from.element == toType.element) return true;
        if (from.kind == TypeKind.signedInteger && toType.kind == TypeKind.signedInteger) return effectiveBits(from, context) <= effectiveBits(toType, context);
        if ((from.kind == TypeKind.unsignedInteger || from.kind == TypeKind.byteType) &&
            toType.kind == TypeKind.unsignedInteger) return effectiveBits(from, context) <= effectiveBits(toType, context);
        if (from.kind == TypeKind.floating && toType.kind == TypeKind.floating) return from.bits <= toType.bits;
        return false;
    }

    TypeId resolve(AstNode node, TargetContext context) {
        if (node is null || node.kind != NodeKind.typeRef) return errorType;
        auto base = find(node.get("base", node.text));
        if (base == errorType) base = declareNamed(node.get("base", node.text));
        auto constructor = node.get("constructor", "value");
        bool constQualified = node.flag("const");
        TypeId result = base;
        if (constructor == "ref") result = reference(base, constQualified);
        else if (constructor == "ptr") result = pointer(base, constQualified);
        else if (constructor == "optional") result = optional(base, constQualified);
        else if (constructor == "storage") result = storage(base);
        else if (constQualified) result = derived(get(base).kind, base, 0, true, true);

        auto suffix = node.get("suffix");
        if (suffix == "slice") result = slice(result);
        else if (suffix == "array") {
            size_t length;
            if (node.children.length) {
                try length = node.children[$ - 1].text.to!size_t;
                catch (Exception) length = 0;
            }
            result = fixedArray(result, length);
        }
        return result;
    }

private:
    TypeId add(TypeKind kind, string name) {
        auto id = cast(TypeId) types.length;
        auto info = new OpenCTypeInfo(id, kind, name);
        types ~= info;
        canonical[name] = id;
        return id;
    }
    TypeId addInteger(TypeKind kind, string name, size_t bits) {
        auto id = add(kind, name); get(id).bits = bits; return id;
    }
    TypeId addFloat(string name, size_t bits) {
        auto id = add(TypeKind.floating, name); get(id).bits = bits; return id;
    }
    TypeId derived(TypeKind kind, TypeId element, size_t length, bool constQualified, bool preserveName = false) {
        auto key = (cast(string) kind) ~ ":" ~ element.to!string ~ ":" ~ length.to!string ~ ":" ~ (constQualified ? "1" : "0");
        auto found = key in canonical;
        if (found !is null) return *found;
        auto id = add(kind, key);
        auto info = get(id);
        info.element = element;
        info.length = length;
        info.constQualified = constQualified;
        if (preserveName) info.name = get(element).name;
        return id;
    }
    size_t effectiveBits(const(OpenCTypeInfo) type, const(TargetContext) context) const {
        return type.bits ? type.bits : context.pointerWidth;
    }
}
