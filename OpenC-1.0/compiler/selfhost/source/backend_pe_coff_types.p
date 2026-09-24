import system.text;

struct NativeArtifactOptions {
    usize kind;
    usize subsystem;
    usize source_chunks;
    text manifest_path;
    text resource_path;
    text dll_name;
    text interface_report_path;
    bool stable_coff_symbols;
}
usize native_artifact_executable() { return 0; }
usize native_artifact_coff_object() { return 1; }
usize native_artifact_dll() { return 2; }
usize native_artifact_static_library() { return 3; }
usize native_artifact_import_library() { return 4; }

NativeArtifactOptions native_artifact_default_options() {
    return NativeArtifactOptions{
        kind = 0,
        subsystem = 3,
        source_chunks = 0,
        manifest_path = "",
        resource_path = "",
        dll_name = "",
        interface_report_path = "",
        stable_coff_symbols = false
    };
}

unsafe void pe_coff_put_i16(ref DBuffer output, i64 value) {
    usize encoded = 0;
    if value < 0 {
        encoded = cast(usize, 65536) - cast(usize, 0 - value);
    } else {
        encoded = cast(usize, value);
    }
    pe32_put_u16(output, encoded);
}

unsafe void pe_coff_put_i32(ref DBuffer output, i64 value) {
    u64 encoded = 0;
    if value < 0 {
        encoded = cast(u64, 4294967296) - cast(u64, 0 - value);
    } else {
        encoded = cast(u64, value);
    }
    pe32_put_u32(output, cast(usize, encoded));
}

unsafe void pe_coff_patch_u16(
    ref DBuffer output,
    usize offset,
    usize value
) {
    if offset > output.length || output.length - offset < 2 {
        output.ok = false;
        return;
    }
    *(output.data + offset) = cast_unchecked(byte, cast(u8, value & 255));
    *(output.data + offset + 1) = cast_unchecked(
        byte, cast(u8, (value >> 8) & 255)
    );
}

unsafe usize pe_coff_read_u16(
    ptr byte data,
    usize length,
    usize offset,
    ref bool valid
) {
    if offset > length || length - offset < 2 {
        valid = false;
        return 0;
    }
    return cast(usize, cast(u8, *(data + offset))) |
        (cast(usize, cast(u8, *(data + offset + 1))) << 8);
}

unsafe usize pe_coff_read_u32(
    ptr byte data,
    usize length,
    usize offset,
    ref bool valid
) {
    if offset > length || length - offset < 4 {
        valid = false;
        return 0;
    }
    usize value = 0;
    usize index = 0;
    while index < 4 {
        value = value |
            (cast(usize, cast(u8, *(data + offset + index))) << (index * 8));
        index = index + 1;
    }
    return value;
}

unsafe void pe_coff_put_decimal_field(
    ref DBuffer output,
    usize value,
    usize width
) {
    DBuffer digits = d_buffer_create(32);
    d_put_usize(digits, value);
    usize index = 0;
    while index < width {
        u8 octet = 32;
        if index < digits.length {
            octet = cast(u8, *(digits.data + index));
        }
        d_put_byte(output, octet);
        index = index + 1;
    }
    if digits.length > width { output.ok = false; }
    d_buffer_destroy(digits);
}

unsafe void pe_coff_put_big_u32(ref DBuffer output, usize value) {
    d_put_byte(output, cast(u8, (value >> 24) & 255));
    d_put_byte(output, cast(u8, (value >> 16) & 255));
    d_put_byte(output, cast(u8, (value >> 8) & 255));
    d_put_byte(output, cast(u8, value & 255));
}
