module openc.std.system_text;

import openc.runtime.types : OpenCByte, OpenCOptional, OpenCText, Status, u8, usize, u32;
import std.array : appender;
import std.string : strip;
import std.utf : UTFException, byDchar, encode, validate;

usize length(OpenCText text) {
    usize count;
    foreach (_; text.byDchar) ++count;
    return count;
}

pragma(inline, true)
usize byte_length(OpenCText text) {
    return text.length;
}

bool empty(OpenCText text) {
    return text.length == 0;
}

OpenCText trim(OpenCText text) {
    return text.strip;
}

Status scalar_at(OpenCText text, usize index, out u32 scalar) {
    usize current;
    foreach (value; text.byDchar) {
        if (current == index) {
            scalar = cast(u32) value;
            return Status.success();
        }
        ++current;
    }
    return Status.failure(9, "text scalar index out of bounds");
}

Status byte_at(OpenCText text, usize index, out u8 value) {
    if (index >= text.length) return Status.failure(9, "text byte index out of bounds");
    value = cast(u8) text[index];
    return Status.success();
}

pragma(inline, true)
u8 byte_at_unchecked(OpenCText text, usize index) {
    return cast(u8) text[index];
}

pragma(inline, true)
void copy_utf8_unchecked(void* destination, OpenCText text) {
    if (text.length != 0) {
        (cast(char*) destination)[0 .. text.length] = text[];
    }
}

pragma(inline, true)
void copy_utf8_slice_unchecked(
    void* destination,
    OpenCText text,
    usize start,
    usize length
) {
    if (length != 0) {
        (cast(char*) destination)[0 .. length] = text[start .. start + length];
    }
}

Status slice(OpenCText text, usize lower, usize upper, out OpenCText result) {
    if (lower > upper) return Status.failure(10, "invalid text range");
    auto output = appender!string();
    usize index;
    foreach (value; text.byDchar) {
        if (index >= lower && index < upper) {
            char[4] buffer;
            auto encoded = encode(buffer, value);
            output.put(buffer[0 .. encoded]);
        }
        ++index;
    }
    if (upper > index) return Status.failure(9, "text range out of bounds");
    result = output.data.idup;
    return Status.success();
}

OpenCByte[] utf8_encode(OpenCText text) {
    OpenCByte[] result;
    result.length = text.length;
    result[] = cast(const(OpenCByte)[]) text;
    return result;
}

Status utf8_decode(const(OpenCByte)[] bytes, out OpenCText text) {
    auto candidate = cast(string) bytes;
    try {
        validate(candidate);
    } catch (UTFException) {
        return Status.failure(11, "invalid UTF-8 byte sequence");
    }
    text = candidate.idup;
    return Status.success();
}

OpenCText concat(OpenCText left, OpenCText right) {
    return (left ~ right).idup;
}

OpenCText from_utf8(void* data, usize length) {
    if (data is null || length == 0) return "";
    return (cast(const(char)*) data)[0 .. length].idup;
}

bool equal(OpenCText left, OpenCText right) {
    return left == right;
}

unittest {
    u32 scalar;
    auto first = scalar_at("Aé", 0, scalar);
    assert(first.ok && scalar == cast(u32)'A');
    auto second = scalar_at("Aé", 1, scalar);
    assert(second.ok && scalar == 0xE9);
    auto missing = scalar_at("Aé", 2, scalar);
    assert(!missing.ok);
    assert(byte_length("Aé") == 3);
    u8 value;
    assert(byte_at("Aé", 1, value).ok && value == 0xC3);
    assert(!byte_at("Aé", 3, value).ok);
}
