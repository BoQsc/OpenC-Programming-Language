module openc.runtime.checked;

import openc.runtime.types : i32, i64, isize, u32, u64, usize;
import core.stdc.stdlib : abort;
import std.conv : ConvException, to;
import std.exception : enforce;
import std.math : isFinite, isNaN, trunc;
import std.stdio : stderr;
import std.traits : isFloatingPoint, isIntegral, isSigned;

extern(C) noreturn opencCheckedFailure(const(char)[] message) {
    stderr.writeln("OpenC checked failure: " ~ message);
    stderr.flush();
    abort();
}

extern(C) noreturn opencTargetFault(const(char)[] message) {
    stderr.writeln("OpenC target fault: " ~ message);
    stderr.flush();
    abort();
}

T checkedAdd(T)(T a, T b) if (__traits(isIntegral, T)) {
    static if (isSigned!T) {
        if ((b > 0 && a > T.max - b) || (b < 0 && a < T.min - b)) {
            opencCheckedFailure("integer addition overflow");
        }
    } else if (a > T.max - b) {
        opencCheckedFailure("integer addition overflow");
    }
    return cast(T) (a + b);
}

T checkedSub(T)(T a, T b) if (__traits(isIntegral, T)) {
    static if (isSigned!T) {
        if ((b > 0 && a < T.min + b) || (b < 0 && a > T.max + b)) {
            opencCheckedFailure("integer subtraction overflow");
        }
    } else if (a < b) {
        opencCheckedFailure("integer subtraction overflow");
    }
    return cast(T) (a - b);
}

T checkedMul(T)(T a, T b) if (__traits(isIntegral, T)) {
    static if (isSigned!T) {
        bool overflow;
        if (a > 0) {
            overflow = b > 0 ? a > T.max / b : b < T.min / a;
        } else if (a < 0) {
            overflow = b > 0 ? a < T.min / b : b < T.max / a;
        }
        if (overflow) opencCheckedFailure("integer multiplication overflow");
    } else if (b != 0 && a > T.max / b) {
        opencCheckedFailure("integer multiplication overflow");
    }
    return cast(T) (a * b);
}

T checkedDiv(T)(T a, T b) if (__traits(isIntegral, T)) {
    if (b == 0) opencCheckedFailure("integer division by zero");
    static if (isSigned!T) {
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

To checkedCast(To, From)(From value)
if ((isIntegral!To || isFloatingPoint!To) &&
    (isIntegral!From || isFloatingPoint!From)) {
    static if (is(To == From)) {
        return value;
    } else static if (isIntegral!To && isIntegral!From) {
        try return value.to!To;
        catch (ConvException) opencCheckedFailure("integer cast is not exact");
    } else static if (isIntegral!To && isFloatingPoint!From) {
        if (!value.isFinite || value != value.trunc ||
            cast(real) value < cast(real) To.min ||
            cast(real) value > cast(real) To.max) {
            opencCheckedFailure("floating-to-integer cast is not exact");
        }
        return cast(To) value;
    } else static if (isFloatingPoint!To && isIntegral!From) {
        auto converted = cast(To) value;
        if (cast(real) converted != cast(real) value) {
            opencCheckedFailure("integer-to-floating cast is not exact");
        }
        return converted;
    } else {
        auto converted = cast(To) value;
        if (value.isNaN) {
            if (!converted.isNaN) opencCheckedFailure("floating cast is not exact");
        } else if (cast(From) converted != value) {
            opencCheckedFailure("floating cast is not exact");
        }
        return converted;
    }
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
