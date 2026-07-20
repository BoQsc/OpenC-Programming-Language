module openc.std.system_text;

import openc.runtime.types : OpenCByte, OpenCOptional, OpenCText, Status, usize, u32;
import std.array : appender;
import std.string : strip;
import std.utf : UTFException, byDchar, encode, validate;

usize length(OpenCText text) {
    usize count;
    foreach (_; text.byDchar) ++count;
    return count;
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

bool equal(OpenCText left, OpenCText right) {
    return left == right;
}
