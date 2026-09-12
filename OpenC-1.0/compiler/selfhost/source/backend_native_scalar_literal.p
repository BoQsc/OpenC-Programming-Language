import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe u64 native_f64_bits(f64 value) {
    ptr byte data = reinterpret(ptr byte, &value);
    u64 result = cast(u64, 0); usize index = 0;
    while index < 8 {
        result = result | (cast(u64, cast(u8, *(data + index))) << (index * 8));
        index = index + 1;
    }
    return result;
}

unsafe u64 native_f32_bits(f32 value) {
    ptr byte data = reinterpret(ptr byte, &value);
    u64 result = cast(u64, 0); usize index = 0;
    while index < 4 {
        result = result | (cast(u64, cast(u8, *(data + index))) << (index * 8));
        index = index + 1;
    }
    return result;
}

unsafe NativeFloat native_float_bits(text literal, usize bits) {
    usize index = 0; bool negative = false;
    if byte_at_or_zero(literal, 0) == 45 { negative = true; index = 1; }
    f64 value = 0.0; f64 divisor = 1.0; bool fraction = false;
    usize digits = 0; i32 exponent = 0; bool exponent_negative = false;
    while index < literal.length {
        u8 octet = byte_at_or_zero(literal, index);
        if octet == 95 { index = index + 1; continue; }
        if octet == 46 && !fraction { fraction = true; index = index + 1; continue; }
        if octet == 101 || octet == 69 { index = index + 1; break; }
        if octet < 48 || octet > 57 {
            return NativeFloat{ value = cast(u64, 0), valid = false };
        }
        value = value * 10.0 + cast(f64, octet - 48);
        if fraction { divisor = divisor * 10.0; }
        digits = digits + 1; index = index + 1;
    }
    if index < literal.length && (byte_at_or_zero(literal, index) == 43 ||
        byte_at_or_zero(literal, index) == 45) {
        exponent_negative = byte_at_or_zero(literal, index) == 45; index = index + 1;
    }
    usize exponent_digits = 0;
    while index < literal.length {
        u8 octet = byte_at_or_zero(literal, index); index = index + 1;
        if octet == 95 { continue; }
        if octet < 48 || octet > 57 || exponent > 1000 {
            return NativeFloat{ value = cast(u64, 0), valid = false };
        }
        exponent = exponent * 10 + cast(i32, octet - 48); exponent_digits = exponent_digits + 1;
    }
    if exponent_negative { exponent = -exponent; }
    value = value / divisor;
    while exponent > 0 { value = value * 10.0; exponent = exponent - 1; }
    while exponent < 0 { value = value / 10.0; exponent = exponent + 1; }
    if negative { value = -value; }
    if digits == 0 || (exponent_digits == 0 &&
        (byte_at_or_zero(literal, literal.length - 1) == 101 ||
         byte_at_or_zero(literal, literal.length - 1) == 69)) {
        return NativeFloat{ value = cast(u64, 0), valid = false };
    }
    if bits == 32 {
        f32 narrowed = cast(f32, value);
        return NativeFloat{ value = native_f32_bits(narrowed), valid = true };
    }
    if bits == 64 { return NativeFloat{ value = native_f64_bits(value), valid = true }; }
    return NativeFloat{ value = cast(u64, 0), valid = false };
}

NativeInteger native_integer_bits(text literal) {
    usize index = 0;
    bool negative = false;
    if byte_at_or_zero(literal, 0) == 45 { negative = true; index = 1; }
    u64 radix = cast(u64, 10);
    if byte_at_or_zero(literal, index) == 48 {
        u8 marker = byte_at_or_zero(literal, index + 1);
        if marker == 120 || marker == 88 { radix = cast(u64, 16); index = index + 2; }
        else if marker == 98 || marker == 66 { radix = cast(u64, 2); index = index + 2; }
    }
    usize digits = 0;
    u64 value = cast(u64, 0);
    u64 maximum = ~cast(u64, 0);
    while index < literal.length {
        u8 octet = byte_at_or_zero(literal, index);
        index = index + 1;
        if octet == 95 { continue; }
        u64 digit = cast(u64, 16);
        if octet >= 48 && octet <= 57 { digit = cast(u64, octet - 48); }
        else if octet >= 65 && octet <= 70 { digit = cast(u64, octet - 65 + 10); }
        else if octet >= 97 && octet <= 102 { digit = cast(u64, octet - 97 + 10); }
        if digit >= radix || value > (maximum - digit) / radix {
            return NativeInteger{ value = cast(u64, 0), valid = false };
        }
        value = value * radix + digit;
        digits = digits + 1;
    }
    if negative {
        if value > (cast(u64, 1) << cast(usize, 63)) {
            return NativeInteger{ value = cast(u64, 0), valid = false };
        }
        if value != cast(u64, 0) { value = (~value) + cast(u64, 1); }
    }
    return NativeInteger{ value = value, valid = digits != 0 };
}
