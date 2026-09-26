import system.text;

export usize fingerprint(text input) {
    usize hash = 0;
    usize index = 0;
    while index < text.byte_length(input) {
        u8 value = text.byte_at_unchecked(input, index);
        hash = (hash * 31 + cast(usize, value)) % 65521;
        index = index + 1;
    }
    return hash;
}
