module openc.runtime.checked;

import openc.runtime.types : i32, i64, isize, u32, u64, usize;
import std.conv : ConvException, to;
import std.exception : enforce;
import std.math : isFinite, isNaN, trunc;
import std.stdio : stderr, stdout;
import std.traits : isFloatingPoint, isIntegral, isSigned;

final class OpenCCheckedFailure : Exception {
    this(string message) { super(message); }
}

final class OpenCTargetFault : Exception {
    this(string message) { super(message); }
}

extern(C) noreturn opencCheckedFailure(const(char)[] message) {
    throw new OpenCCheckedFailure(message.idup);
}

extern(C) noreturn opencTargetFault(const(char)[] message) {
    throw new OpenCTargetFault(message.idup);
}

int reportOpenCFailure(OpenCCheckedFailure failure) {
    stdout.flush();
    stderr.writeln("OpenC checked failure: " ~ failure.msg);
    stderr.flush();
    return 70;
}

int reportOpenCFailure(OpenCTargetFault failure) {
    stdout.flush();
    stderr.writeln("OpenC target fault: " ~ failure.msg);
    stderr.flush();
    return 71;
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

T saturatingAdd(T)(T a, T b) if (__traits(isIntegral, T)) {
    static if (isSigned!T) {
        if (b > 0 && a > T.max - b) return T.max;
        if (b < 0 && a < T.min - b) return T.min;
    } else if (a > T.max - b) return T.max;
    return cast(T) (a + b);
}

T saturatingSub(T)(T a, T b) if (__traits(isIntegral, T)) {
    static if (isSigned!T) {
        if (b > 0 && a < T.min + b) return T.min;
        if (b < 0 && a > T.max + b) return T.max;
    } else if (a < b) return T.min;
    return cast(T) (a - b);
}

T saturatingMul(T)(T a, T b) if (__traits(isIntegral, T)) {
    if (a == 0 || b == 0) return 0;
    static if (!isSigned!T) {
        if (a > T.max / b) return T.max;
    } else if (a > 0) {
        if (b > 0 && a > T.max / b) return T.max;
        if (b < 0 && b < T.min / a) return T.min;
    } else {
        if (b > 0 && a < T.min / b) return T.min;
        if (b < 0 && b < T.max / a) return T.max;
    }
    return cast(T) (a * b);
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
