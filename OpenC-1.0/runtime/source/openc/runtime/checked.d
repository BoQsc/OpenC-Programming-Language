module openc.runtime.checked;

import openc.runtime.types : i32, i64, isize, u32, u64, usize;
import core.stdc.stdlib : abort;
import std.exception : enforce;
import std.stdio : stderr;

extern(C) noreturn opencCheckedFailure(const(char)[] message) {
    stderr.writeln("OpenC checked failure: " ~ message);
    abort();
}

extern(C) noreturn opencTargetFault(const(char)[] message) {
    stderr.writeln("OpenC target fault: " ~ message);
    abort();
}

T checkedAdd(T)(T a, T b) if (__traits(isIntegral, T)) {
    T result;
    if (__builtin_add_overflow(a, b, &result)) opencCheckedFailure("integer addition overflow");
    return result;
}

T checkedSub(T)(T a, T b) if (__traits(isIntegral, T)) {
    T result;
    if (__builtin_sub_overflow(a, b, &result)) opencCheckedFailure("integer subtraction overflow");
    return result;
}

T checkedMul(T)(T a, T b) if (__traits(isIntegral, T)) {
    T result;
    if (__builtin_mul_overflow(a, b, &result)) opencCheckedFailure("integer multiplication overflow");
    return result;
}

T checkedDiv(T)(T a, T b) if (__traits(isIntegral, T)) {
    if (b == 0) opencCheckedFailure("integer division by zero");
    static if (__traits(isSigned, T)) {
        if (a == T.min && b == -1) opencCheckedFailure("integer division overflow");
    }
    return a / b;
}

T checkedRem(T)(T a, T b) if (__traits(isIntegral, T)) {
    if (b == 0) opencCheckedFailure("integer remainder by zero");
    return a % b;
}

T checkedShiftLeft(T)(T value, usize amount) if (__traits(isIntegral, T)) {
    if (amount >= T.sizeof * 8) opencCheckedFailure("shift amount outside type width");
    auto result = cast(T)(value << amount);
    if ((result >> amount) != value) opencCheckedFailure("left shift overflow");
    return result;
}

T checkedShiftRight(T)(T value, usize amount) if (__traits(isIntegral, T)) {
    if (amount >= T.sizeof * 8) opencCheckedFailure("shift amount outside type width");
    return cast(T)(value >> amount);
}

T wrappingAdd(T)(T a, T b) if (__traits(isIntegral, T)) {
    return cast(T)(cast(typeof(cast(ulong) a + cast(ulong) b))(a) + b);
}

T saturatingAdd(T)(T a, T b) if (__traits(isIntegral, T)) {
    T result;
    if (!__builtin_add_overflow(a, b, &result)) return result;
    static if (__traits(isSigned, T)) return b > 0 ? T.max : T.min;
    else return T.max;
}
