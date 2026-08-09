import system.memory;

external(c, "oc_text_from_owned_bytes") status runtime_decode_utf8(ref const memory.Bytes bytes, out text value);
external(c, "oc_text_to_utf8") status runtime_encode_utf8(text value, out memory.Bytes bytes);
external(c, "oc_text_scalar_length") usize runtime_scalar_length(text value, u32 span_id);
external(c, "oc_text_scalar_at") status runtime_scalar_at(text value, usize index, out u32 scalar);
external(c, "oc_text_byte_length") usize runtime_byte_length(text value);
external(c, "oc_text_byte_at") status runtime_byte_at(text value, usize index, out u8 byte_value);
external(c, "oc_text_copy_utf8_unchecked") unsafe void copy_utf8_unchecked(ptr byte destination, text value);
external(c, "oc_text_copy_utf8_slice_unchecked") unsafe void copy_utf8_slice_unchecked(ptr byte destination, text value, usize start, usize length);
external(c, "oc_text_equal") bool runtime_equal(text left, text right);
external(c, "oc_text_compare") i32 runtime_compare(text left, text right);
external(c, "oc_text_from_utf8_view") unsafe text from_utf8(ptr byte data, usize length);

export status decode_utf8(ref const memory.Bytes bytes, out text value) {
    return runtime_decode_utf8(bytes, out value);
}

export status encode_utf8(text value, out memory.Bytes bytes) {
    return runtime_encode_utf8(value, out bytes);
}

export usize length(text value) {
    return runtime_scalar_length(value, 0);
}

export status scalar_at(text value, usize index, out u32 scalar) {
    return runtime_scalar_at(value, index, out scalar);
}

export usize byte_length(text value) {
    return runtime_byte_length(value);
}

export status byte_at(text value, usize index, out u8 byte_value) {
    return runtime_byte_at(value, index, out byte_value);
}

export bool equal(text left, text right) {
    return runtime_equal(left, right);
}

export i32 compare(text left, text right) {
    return runtime_compare(left, right);
}
