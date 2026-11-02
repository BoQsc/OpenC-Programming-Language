import system.text;

export usize count_lines(text input) {
    usize length = text.byte_length(input);
    usize lines = 0;
    usize index = 0;
    while index < length {
        u8 value = text.byte_at_unchecked(input, index);
        if value == 10 { lines = lines + 1; }
        index = index + 1;
    }
    if length != 0 {
        u8 last = text.byte_at_unchecked(input, length - 1);
        if last != 10 { lines = lines + 1; }
    }
    return lines;
}

export usize count_digits(text input) {
    usize digits = 0;
    usize index = 0;
    while index < text.byte_length(input) {
        u8 value = text.byte_at_unchecked(input, index);
        if value >= 48 && value <= 57 { digits = digits + 1; }
        index = index + 1;
    }
    return digits;
}

export usize count_warnings(text input) {
    usize warnings = 0;
    usize index = 0;
    usize length = text.byte_length(input);
    while index + 4 <= length {
        u8 first = text.byte_at_unchecked(input, index);
        u8 second = text.byte_at_unchecked(input, index + 1);
        u8 third = text.byte_at_unchecked(input, index + 2);
        u8 fourth = text.byte_at_unchecked(input, index + 3);
        if first == 87 && second == 65 && third == 82 && fourth == 78 {
            warnings = warnings + 1;
        }
        index = index + 1;
    }
    return warnings;
}
