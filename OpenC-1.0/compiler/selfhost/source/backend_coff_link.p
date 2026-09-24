import system.file;
import system.io;
import system.memory;
import system.text;

// Restricted reader for the exact five-section objects emitted by
// --kind=module-coff-set. It does not accept arbitrary third-party COFF.
struct CoffLinkSection {
    usize raw;
    usize size;
    usize reloc;
    usize count;
    bool ok;
}

struct CoffLinkName {
    usize offset;
    usize length;
    bool ok;
}

struct CoffLinkValue {
    usize value;
    bool ok;
}

struct CoffLinkCounts {
    usize objects;
    usize functions;
    bool ok;
}

struct CoffLinkSymbol {
    CoffLinkName name;
    usize value;
    usize section;
    usize storage_class;
    bool ok;
}

struct CoffLinkObject {
    CoffLinkSection code;
    CoffLinkSection constants;
    CoffLinkSection data;
    CoffLinkSection unwind_index;
    CoffLinkSection unwind_data;
    usize symbols;
    usize symbol_count;
    usize strings;
    usize strings_size;
    bool ok;
}

unsafe bool coff_link_name8(
    ref DBuffer object,
    usize offset,
    text expected
) {
    if offset > object.length || object.length - offset < 8 ||
        text.byte_length(expected) > 8 { return false; }
    usize index = 0;
    while index < 8 {
        u8 actual = cast(u8, *(object.data + offset + index));
        u8 wanted = 0;
        if index < text.byte_length(expected) {
            wanted = byte_at_or_zero(expected, index);
        }
        if actual != wanted { return false; }
        index = index + 1;
    }
    return true;
}

unsafe CoffLinkSection coff_link_section(
    ref DBuffer object,
    usize index,
    text expected_name,
    usize expected_raw
) {
    usize header = 20 + index * 40;
    bool valid = true;
    CoffLinkSection section = CoffLinkSection{
        raw = 0, size = 0, reloc = 0, count = 0, ok = false
    };
    if !coff_link_name8(object, header, expected_name) { valid = false; }
    section.size = pe_coff_read_u32(
        object.data, object.length, header + 16, valid
    );
    section.raw = pe_coff_read_u32(
        object.data, object.length, header + 20, valid
    );
    section.reloc = pe_coff_read_u32(
        object.data, object.length, header + 24, valid
    );
    section.count = pe_coff_read_u16(
        object.data, object.length, header + 32, valid
    );
    usize overflow = pe_coff_read_u16(
        object.data, object.length, header + 34, valid
    );
    if !valid || section.raw != expected_raw ||
        section.raw > object.length ||
        section.size > object.length - section.raw || overflow != 0 {
        valid = false;
    }
    section.ok = valid;
    return section;
}

unsafe CoffLinkObject coff_link_parse(ref DBuffer object) {
    CoffLinkSection empty = CoffLinkSection{
        raw = 0, size = 0, reloc = 0, count = 0, ok = false
    };
    CoffLinkObject result = CoffLinkObject{
        code = empty, constants = empty, data = empty,
        unwind_index = empty, unwind_data = empty,
        symbols = 0, symbol_count = 0, strings = 0,
        strings_size = 0, ok = false
    };
    bool valid = object.ok && object.length >= 224 &&
        object.length <= 8388608;
    if !valid { return result; }
    usize machine = pe_coff_read_u16(
        object.data, object.length, 0, valid
    );
    usize sections = pe_coff_read_u16(
        object.data, object.length, 2, valid
    );
    usize timestamp = pe_coff_read_u32(
        object.data, object.length, 4, valid
    );
    result.symbols = pe_coff_read_u32(
        object.data, object.length, 8, valid
    );
    result.symbol_count = pe_coff_read_u32(
        object.data, object.length, 12, valid
    );
    usize optional_header_size = pe_coff_read_u16(
        object.data, object.length, 16, valid
    );
    if !valid || machine != 34404 || sections != 5 ||
        timestamp != 0 || optional_header_size != 0 ||
        result.symbol_count < 7 + pe32_import_count() ||
        result.symbol_count > 8192 { return result; }
    result.code = coff_link_section(object, 0, ".text", 220);
    result.constants = coff_link_section(
        object, 1, ".rdata", result.code.raw + result.code.size
    );
    result.data = coff_link_section(
        object, 2, ".data",
        result.constants.raw + result.constants.size
    );
    result.unwind_index = coff_link_section(
        object, 3, ".pdata", result.data.raw + result.data.size
    );
    result.unwind_data = coff_link_section(
        object, 4, ".xdata",
        result.unwind_index.raw + result.unwind_index.size
    );
    if !result.code.ok || !result.constants.ok || !result.data.ok ||
        !result.unwind_index.ok || !result.unwind_data.ok ||
        result.code.size < 32 || result.data.size != 96 ||
        result.constants.count != 0 || result.data.count != 0 ||
        result.unwind_data.count != 0 ||
        result.constants.reloc != 0 || result.data.reloc != 0 ||
        result.unwind_data.reloc != 0 ||
        result.unwind_index.size % 12 != 0 ||
        result.unwind_index.count != result.unwind_index.size / 4 ||
        result.symbol_count < 7 + result.unwind_index.size / 12 +
            pe32_import_count() { return result; }
    usize text_relocations = result.unwind_data.raw +
        result.unwind_data.size;
    usize pdata_relocations = text_relocations +
        result.code.count * 10;
    usize symbols_at = pdata_relocations +
        result.unwind_index.count * 10;
    if result.code.reloc != text_relocations ||
        result.unwind_index.reloc != pdata_relocations ||
        result.symbols != symbols_at || symbols_at > object.length ||
        result.symbol_count > (object.length - symbols_at) / 18 {
        return result;
    }
    result.strings = symbols_at + result.symbol_count * 18;
    if result.strings > object.length ||
        object.length - result.strings < 4 { return result; }
    result.strings_size = pe_coff_read_u32(
        object.data, object.length, result.strings, valid
    );
    if !valid || result.strings_size < 4 ||
        result.strings_size != object.length - result.strings {
        return result;
    }
    usize byte_index = 0;
    while byte_index < result.data.size {
        if cast(u8, *(object.data + result.data.raw + byte_index)) != 0 {
            return result;
        }
        byte_index = byte_index + 1;
    }
    result.ok = true;
    return result;
}

unsafe CoffLinkName coff_link_symbol_name(
    ref DBuffer object,
    ref CoffLinkObject parsed,
    usize symbol_index
) {
    CoffLinkName name = CoffLinkName{
        offset = 0, length = 0, ok = false
    };
    if !parsed.ok || symbol_index >= parsed.symbol_count {
        return name;
    }
    usize symbol = parsed.symbols + symbol_index * 18;
    bool valid = true;
    usize first = pe_coff_read_u32(
        object.data, object.length, symbol, valid
    );
    if !valid { return name; }
    if first == 0 {
        usize offset = pe_coff_read_u32(
            object.data, object.length, symbol + 4, valid
        );
        if !valid || offset < 4 || offset >= parsed.strings_size {
            return name;
        }
        name.offset = parsed.strings + offset;
        while name.length <= 128 &&
            name.offset + name.length < object.length &&
            cast(u8, *(object.data + name.offset + name.length)) != 0 {
            name.length = name.length + 1;
        }
        name.ok = name.length != 0 && name.length <= 128 &&
            name.offset + name.length < object.length;
        return name;
    }
    name.offset = symbol;
    while name.length < 8 &&
        cast(u8, *(object.data + symbol + name.length)) != 0 {
        name.length = name.length + 1;
    }
    name.ok = name.length != 0;
    return name;
}

unsafe bool coff_link_bytes_equal(
    ptr byte left,
    usize left_length,
    ptr byte right,
    usize right_length
) {
    if left_length != right_length { return false; }
    usize index = 0;
    while index < left_length {
        if cast(u8, *(left + index)) != cast(u8, *(right + index)) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

unsafe bool coff_link_bytes_text(
    ptr byte bytes,
    usize length,
    text wanted
) {
    if length != text.byte_length(wanted) { return false; }
    usize index = 0;
    while index < length {
        if cast(u8, *(bytes + index)) != byte_at_or_zero(wanted, index) {
            return false;
        }
        index = index + 1;
    }
    return true;
}

unsafe bool coff_link_stable_name(ptr byte bytes, usize length) {
    if length != 71 ||
        !coff_link_bytes_text(bytes, 7, "$openc$") { return false; }
    usize index = 7;
    while index < length {
        u8 value = cast(u8, *(bytes + index));
        if !((value >= 48 && value <= 57) ||
            (value >= 97 && value <= 102)) { return false; }
        index = index + 1;
    }
    return true;
}

unsafe usize coff_link_name_slot(ptr byte bytes, usize length) {
    usize slot = 5381;
    usize index = 0;
    while index < length {
        slot = (slot * 33 + cast(usize, cast(u8, *(bytes + index)))) &
            8191;
        index = index + 1;
    }
    return slot;
}

unsafe bool coff_link_insert_definition(
    ref DBuffer bundle,
    ref DBuffer definitions,
    ptr byte slots,
    usize name_offset,
    usize name_length,
    usize target
) {
    if definitions.length / 24 >= 4096 ||
        name_offset > bundle.length ||
        name_length > bundle.length - name_offset {
        return false;
    }
    ptr byte name = bundle.data + name_offset;
    usize slot = coff_link_name_slot(name, name_length);
    usize probes = 0;
    while probes < 8192 {
        usize found = read_usize(slots, slot * size_of(usize));
        if found == 0 {
            pe32_put_u64(definitions, cast(u64, name_offset));
            pe32_put_u64(definitions, cast(u64, name_length));
            pe32_put_u64(definitions, cast(u64, target));
            if !definitions.ok { return false; }
            write_usize(slots, slot * size_of(usize),
                definitions.length / 24);
            return true;
        }
        usize at = (found - 1) * 24;
        usize prior_offset = read_usize(definitions.data, at);
        usize prior_length = read_usize(definitions.data, at + 8);
        if coff_link_bytes_equal(
            name, name_length,
            bundle.data + prior_offset, prior_length
        ) { return false; }
        slot = (slot + 1) & 8191;
        probes = probes + 1;
    }
    return false;
}

unsafe CoffLinkValue coff_link_find_definition(
    ref DBuffer bundle,
    ref DBuffer definitions,
    ptr byte slots,
    ptr byte name,
    usize name_length
) {
    CoffLinkValue found_value = CoffLinkValue{
        value = 0, ok = false
    };
    usize slot = coff_link_name_slot(name, name_length);
    usize probes = 0;
    while probes < 8192 {
        usize found = read_usize(slots, slot * size_of(usize));
        if found == 0 { return found_value; }
        usize at = (found - 1) * 24;
        usize prior_offset = read_usize(definitions.data, at);
        usize prior_length = read_usize(definitions.data, at + 8);
        if coff_link_bytes_equal(
            name, name_length,
            bundle.data + prior_offset, prior_length
        ) {
            found_value.value = read_usize(definitions.data, at + 16);
            found_value.ok = true;
            return found_value;
        }
        slot = (slot + 1) & 8191;
        probes = probes + 1;
    }
    return found_value;
}

unsafe CoffLinkCounts coff_link_bundle_collect(
    ref DBuffer bundle,
    ref DBuffer code,
    ref DBuffer constants,
    ref DBuffer pdata,
    ref DBuffer xdata,
    ptr byte bases
) {
    CoffLinkCounts counts = CoffLinkCounts{
        objects = 0, functions = 0, ok = false
    };
    if !bundle.ok || bundle.length == 0 ||
        bundle.length > 8388608 { return counts; }
    usize cursor = 0;
    while cursor < bundle.length {
        if counts.objects >= 64 || bundle.length - cursor < 4 {
            return counts;
        }
        usize length = native_read_u32(bundle, cursor);
        if length > bundle.length - cursor - 4 { return counts; }
        DBuffer object = DBuffer{
            data = bundle.data + cursor + 4,
            length = length, capacity = length, ok = true
        };
        CoffLinkObject parsed = coff_link_parse(object);
        if !parsed.ok { return counts; }
        usize functions = parsed.unwind_index.size / 12;
        if functions > 4096 - counts.functions { return counts; }
        pe32_pad_to(code, x64_align_up(code.length, 16));
        pe32_pad_to(xdata, x64_align_up(xdata.length, 4));
        usize at = counts.objects * 4 * size_of(usize);
        write_usize(bases, at, code.length);
        write_usize(bases, at + 8, constants.length);
        write_usize(bases, at + 16, pdata.length);
        write_usize(bases, at + 24, xdata.length);
        native_copy_range(
            code, object, parsed.code.raw, parsed.code.size
        );
        native_copy_range(
            constants, object,
            parsed.constants.raw, parsed.constants.size
        );
        native_copy_range(
            pdata, object,
            parsed.unwind_index.raw, parsed.unwind_index.size
        );
        native_copy_range(
            xdata, object,
            parsed.unwind_data.raw, parsed.unwind_data.size
        );
        if !code.ok || !constants.ok || !pdata.ok || !xdata.ok {
            return counts;
        }
        counts.functions = counts.functions + functions;
        counts.objects = counts.objects + 1;
        cursor = cursor + 4 + length;
    }
    counts.ok = counts.objects != 0 && cursor == bundle.length &&
        code.length <= 8388608 && constants.length <= 8388608 &&
        pdata.length <= 1048576 && xdata.length <= 4194304;
    return counts;
}

unsafe CoffLinkSymbol coff_link_symbol_fields(
    ref DBuffer object,
    ref CoffLinkObject parsed,
    usize index
) {
    CoffLinkSymbol symbol = CoffLinkSymbol{
        name = coff_link_symbol_name(object, parsed, index),
        value = 0, section = 0, storage_class = 0, ok = false
    };
    if !symbol.name.ok { return symbol; }
    bool valid = true;
    usize row = parsed.symbols + index * 18;
    symbol.value = pe_coff_read_u32(
        object.data, object.length, row + 8, valid
    );
    symbol.section = pe_coff_read_u16(
        object.data, object.length, row + 12, valid
    );
    usize type_value = pe_coff_read_u16(
        object.data, object.length, row + 14, valid
    );
    symbol.storage_class = cast(usize, cast(u8, *(object.data + row + 16)));
    usize auxiliary = cast(usize, cast(u8, *(object.data + row + 17)));
    symbol.ok = valid && auxiliary == 0 &&
        (type_value == 0 || type_value == 32);
    return symbol;
}

unsafe bool coff_link_import_name(
    ptr byte name,
    usize length,
    usize imported
) {
    text expected = pe32_import_name(imported);
    if length != text.byte_length(expected) + 6 ||
        !coff_link_bytes_text(name, 6, "__imp_") { return false; }
    usize index = 0;
    while index < text.byte_length(expected) {
        if cast(u8, *(name + 6 + index)) !=
            byte_at_or_zero(expected, index) { return false; }
        index = index + 1;
    }
    return true;
}

unsafe bool coff_link_validate_symbols(
    ref DBuffer bundle,
    ref DBuffer definitions,
    ptr byte slots,
    ptr byte bases,
    ref DBuffer entry_name,
    ref usize entry_offset
) {
    entry_offset = 0;
    usize cursor = 0;
    usize object_index = 0;
    bool found_entry = false;
    while cursor < bundle.length {
        usize length = native_read_u32(bundle, cursor);
        DBuffer object = DBuffer{
            data = bundle.data + cursor + 4,
            length = length, capacity = length, ok = true
        };
        CoffLinkObject parsed = coff_link_parse(object);
        if !parsed.ok { return false; }
        usize functions = parsed.unwind_index.size / 12;
        usize base = read_usize(
            bases, object_index * 4 * size_of(usize)
        );
        usize index = 0;
        while index < parsed.symbol_count {
            CoffLinkSymbol row_symbol = coff_link_symbol_fields(
                object, parsed, index
            );
            if !row_symbol.ok { return false; }
            ptr byte name = object.data + row_symbol.name.offset;
            if index < 5 {
                text expected = ".text";
                if index == 1 { expected = ".rdata"; }
                if index == 2 { expected = ".data"; }
                if index == 3 { expected = ".pdata"; }
                if index == 4 { expected = ".xdata"; }
                if !coff_link_bytes_text(
                    name, row_symbol.name.length, expected
                ) || row_symbol.section != index + 1 ||
                    row_symbol.value != 0 ||
                    row_symbol.storage_class != 3 { return false; }
            } else if index < 7 {
                text expected = "$openc_checked_fault";
                usize expected_value = 0;
                if index == 6 {
                    expected = "$openc_target_fault";
                    expected_value = 16;
                }
                if !coff_link_bytes_text(
                    name, row_symbol.name.length, expected
                ) || row_symbol.section != 1 ||
                    row_symbol.value != expected_value ||
                    row_symbol.storage_class != 3 { return false; }
            } else if index < 7 + functions {
                if !coff_link_stable_name(
                    name, row_symbol.name.length
                ) || row_symbol.section != 1 ||
                    row_symbol.value < 32 ||
                    row_symbol.value >= parsed.code.size ||
                    row_symbol.storage_class != 2 {
                    return false;
                }
                if !coff_link_insert_definition(
                    bundle, definitions, slots,
                    cursor + 4 + row_symbol.name.offset,
                    row_symbol.name.length, base + row_symbol.value
                ) { return false; }
                if coff_link_bytes_equal(
                    name, row_symbol.name.length,
                    entry_name.data, entry_name.length
                ) {
                    if found_entry { return false; }
                    found_entry = true;
                    entry_offset = base + row_symbol.value;
                }
            } else if index < 7 + functions + pe32_import_count() {
                usize imported = index - 7 - functions;
                if !coff_link_import_name(
                    name, row_symbol.name.length, imported
                ) || row_symbol.section != 0 ||
                    row_symbol.value != 0 || row_symbol.storage_class != 2 {
                    return false;
                }
            } else {
                if !coff_link_stable_name(
                    name, row_symbol.name.length
                ) || row_symbol.section != 0 ||
                    row_symbol.value != 0 || row_symbol.storage_class != 2 {
                    return false;
                }
            }
            index = index + 1;
        }
        cursor = cursor + 4 + length;
        object_index = object_index + 1;
    }
    return found_entry && definitions.ok;
}

unsafe CoffLinkValue coff_link_target(
    ref DBuffer bundle,
    ref DBuffer object,
    ref CoffLinkObject parsed,
    ref DBuffer definitions,
    ptr byte slots,
    ref Pe32RuntimeLayout layout,
    usize symbol_index,
    usize text_base,
    usize rdata_base,
    usize xdata_base
) {
    CoffLinkValue target = CoffLinkValue{
        value = 0, ok = false
    };
    if symbol_index >= parsed.symbol_count { return target; }
    usize functions = parsed.unwind_index.size / 12;
    if symbol_index == 0 {
        target.value = layout.text_rva + text_base;
        target.ok = true;
        return target;
    }
    if symbol_index == 1 {
        target.value = layout.rdata_rva + 1536 + rdata_base;
        target.ok = true;
        return target;
    }
    if symbol_index == 4 {
        target.value = layout.xdata_rva + xdata_base;
        target.ok = true;
        return target;
    }
    if symbol_index == 5 || symbol_index == 6 {
        target.value = layout.text_rva + text_base;
        if symbol_index == 6 { target.value = target.value + 16; }
        target.ok = true;
        return target;
    }
    if symbol_index < 7 { return target; }
    if symbol_index < 7 + functions {
        bool valid = true;
        usize value = pe_coff_read_u32(
            object.data, object.length,
            parsed.symbols + symbol_index * 18 + 8, valid
        );
        if !valid || value >= parsed.code.size { return target; }
        target.value = layout.text_rva + text_base + value;
        target.ok = true;
        return target;
    }
    if symbol_index < 7 + functions + pe32_import_count() {
        target.value = pe32_import_iat_rva(
            layout, symbol_index - 7 - functions
        );
        target.ok = true;
        return target;
    }
    CoffLinkName name = coff_link_symbol_name(
        object, parsed, symbol_index
    );
    if !name.ok { return target; }
    CoffLinkValue definition = coff_link_find_definition(
        bundle, definitions, slots,
        object.data + name.offset, name.length
    );
    if !definition.ok { return target; }
    target.value = layout.text_rva + definition.value;
    target.ok = true;
    return target;
}

unsafe bool coff_link_text_relocations(
    ref DBuffer bundle,
    ref DBuffer code,
    ref DBuffer definitions,
    ptr byte slots,
    ptr byte bases,
    ref Pe32RuntimeLayout layout
) {
    usize cursor = 0;
    usize object_index = 0;
    while cursor < bundle.length {
        usize length = native_read_u32(bundle, cursor);
        DBuffer object = DBuffer{
            data = bundle.data + cursor + 4,
            length = length, capacity = length, ok = true
        };
        CoffLinkObject parsed = coff_link_parse(object);
        if !parsed.ok { return false; }
        usize at = object_index * 4 * size_of(usize);
        usize text_base = read_usize(bases, at);
        usize rdata_base = read_usize(bases, at + 8);
        usize xdata_base = read_usize(bases, at + 24);
        usize index = 0;
        while index < parsed.code.count {
            bool valid = true;
            usize row = parsed.code.reloc + index * 10;
            usize offset = pe_coff_read_u32(
                object.data, object.length, row, valid
            );
            usize symbol = pe_coff_read_u32(
                object.data, object.length, row + 4, valid
            );
            usize kind = pe_coff_read_u16(
                object.data, object.length, row + 8, valid
            );
            if !valid || kind != 4 || offset > parsed.code.size ||
                parsed.code.size - offset < 4 { return false; }
            CoffLinkValue target = coff_link_target(
                bundle, object, parsed, definitions, slots, layout,
                symbol, text_base, rdata_base, xdata_base
            );
            if !target.ok { return false; }
            usize addend = pe_coff_read_u32(
                code.data, code.length, text_base + offset, valid
            );
            if !valid || addend > 2147483647 { return false; }
            usize source_rva = layout.text_rva + text_base + offset;
            i64 delta = cast(i64, target.value) + cast(i64, addend) -
                cast(i64, source_rva + 4);
            if delta < cast(i64, -2147483647) - 1 ||
                delta > 2147483647 {
                return false;
            }
            u32 encoded = 0;
            if delta < 0 {
                encoded = cast(u32,
                    cast(u64, 4294967296) - cast(u64, 0 - delta));
            } else { encoded = cast(u32, delta); }
            pe32_patch_u32(code, text_base + offset,
                cast(usize, encoded));
            if !code.ok { return false; }
            index = index + 1;
        }
        cursor = cursor + 4 + length;
        object_index = object_index + 1;
    }
    return true;
}

unsafe bool coff_link_pdata_relocations(
    ref DBuffer bundle,
    ref DBuffer pdata,
    ptr byte bases,
    ref Pe32RuntimeLayout layout
) {
    usize cursor = 0;
    usize object_index = 0;
    while cursor < bundle.length {
        usize length = native_read_u32(bundle, cursor);
        DBuffer object = DBuffer{
            data = bundle.data + cursor + 4,
            length = length, capacity = length, ok = true
        };
        CoffLinkObject parsed = coff_link_parse(object);
        if !parsed.ok { return false; }
        usize at = object_index * 4 * size_of(usize);
        usize text_base = read_usize(bases, at);
        usize pdata_base = read_usize(bases, at + 16);
        usize xdata_base = read_usize(bases, at + 24);
        usize index = 0;
        while index < parsed.unwind_index.count {
            bool valid = true;
            usize row = parsed.unwind_index.reloc + index * 10;
            usize offset = pe_coff_read_u32(
                object.data, object.length, row, valid
            );
            usize symbol = pe_coff_read_u32(
                object.data, object.length, row + 4, valid
            );
            usize kind = pe_coff_read_u16(
                object.data, object.length, row + 8, valid
            );
            usize expected_offset = (index / 3) * 12 +
                (index % 3) * 4;
            usize expected_symbol = 0;
            if index % 3 == 2 { expected_symbol = 4; }
            if !valid || kind != 3 || offset != expected_offset ||
                symbol != expected_symbol ||
                offset > parsed.unwind_index.size ||
                parsed.unwind_index.size - offset < 4 {
                return false;
            }
            usize addend = pe_coff_read_u32(
                pdata.data, pdata.length, pdata_base + offset, valid
            );
            if !valid { return false; }
            usize target = 0;
            if symbol == 0 {
                if addend > parsed.code.size { return false; }
                target = layout.text_rva + text_base + addend;
            } else {
                if addend > parsed.unwind_data.size { return false; }
                target = layout.xdata_rva + xdata_base + addend;
            }
            if target > 4294967295 { return false; }
            pe32_patch_u32(pdata, pdata_base + offset, target);
            if !pdata.ok { return false; }
            index = index + 1;
        }
        cursor = cursor + 4 + length;
        object_index = object_index + 1;
    }
    return true;
}

unsafe bool coff_link_entry_name(
    ref IrContext context,
    ref DBuffer objects,
    ref DBuffer name
) {
    if context.symbols.length > 4096 { return false; }
    usize entry = context.symbols.length;
    usize cursor = 0;
    while cursor < objects.length {
        if objects.length - cursor < 24 { return false; }
        usize symbol = native_read_u32(objects, cursor);
        usize entry_flag = native_read_u32(objects, cursor + 4);
        usize code = native_read_u32(objects, cursor + 8);
        usize unwind = native_read_u32(objects, cursor + 12);
        usize relocations = native_read_u32(objects, cursor + 16);
        usize constants = native_read_u32(objects, cursor + 20);
        usize record_size = 24 + code + unwind +
            relocations * 8 + constants;
        if symbol >= context.symbols.length ||
            record_size > objects.length - cursor { return false; }
        if entry_flag != 0 {
            if entry != context.symbols.length { return false; }
            entry = symbol;
        }
        cursor = cursor + record_size;
    }
    if entry >= context.symbols.length || cursor != objects.length {
        return false;
    }
    DBuffer hashes = d_buffer_create(
        context.symbols.length * 64 + 64
    );
    ptr byte offsets = memory.alloc(
        (context.symbols.length + 1) * size_of(usize)
    );
    bool ok = hashes.ok && coff_stable_prepare(
        context, hashes, offsets
    );
    if ok {
        usize at_plus_one = read_usize(
            offsets, entry * size_of(usize)
        );
        if at_plus_one == 0 || at_plus_one - 1 + 64 > hashes.length {
            ok = false;
        } else {
            d_put(name, "$openc$");
            d_put_raw(name, hashes.data + at_plus_one - 1, 64);
            ok = name.ok && name.length == 71;
        }
    }
    memory.free(offsets);
    d_buffer_destroy(hashes);
    return ok;
}

unsafe Pe32RuntimeLayout coff_link_layout(
    ref DBuffer code,
    ref DBuffer constants,
    ref DBuffer pdata,
    ref DBuffer xdata
) {
    Pe32RuntimeLayout layout = pe32_runtime_layout();
    layout.rdata_rva = x64_align_up(
        layout.text_rva + code.length, 4096
    );
    layout.data_rva = x64_align_up(
        layout.rdata_rva + 1536 + constants.length, 4096
    );
    layout.pdata_rva = layout.data_rva + 4096;
    layout.xdata_rva = x64_align_up(
        layout.pdata_rva + pdata.length, 4096
    );
    layout.tls_rva = x64_align_up(
        layout.xdata_rva + xdata.length, 4096
    );
    layout.reloc_rva = layout.tls_rva + 4096;
    layout.image_size = layout.reloc_rva + 4096;
    return layout;
}

unsafe status coff_link_emit_pe(
    ref DBuffer code,
    ref DBuffer constants,
    ref DBuffer pdata,
    ref DBuffer xdata,
    ref Pe32RuntimeLayout layout,
    usize entry_offset,
    text output_path
) {
    status written = status{ code = 1 };
    Pe32Section text_section = native_section(
        ".text", code.length, layout.text_rva, 1024,
        pe32_section_code()
    );
    Pe32Section rdata_section = native_section(
        ".rdata", 1536 + constants.length, layout.rdata_rva,
        text_section.raw_pointer + text_section.raw_size,
        pe32_section_read_only_data()
    );
    Pe32Section data_section = native_section(
        ".data", 96, layout.data_rva,
        rdata_section.raw_pointer + rdata_section.raw_size,
        pe32_section_read_write_data()
    );
    Pe32Section pdata_section = native_section(
        ".pdata", pdata.length, layout.pdata_rva,
        data_section.raw_pointer + data_section.raw_size,
        pe32_section_read_only_data()
    );
    Pe32Section xdata_section = native_section(
        ".xdata", xdata.length, layout.xdata_rva,
        pdata_section.raw_pointer + pdata_section.raw_size,
        pe32_section_read_only_data()
    );
    Pe32Section tls_section = native_section(
        ".tls", 8, layout.tls_rva,
        xdata_section.raw_pointer + xdata_section.raw_size,
        pe32_section_read_write_data()
    );
    Pe32Section reloc_section = native_section(
        ".reloc", 28, layout.reloc_rva,
        tls_section.raw_pointer + tls_section.raw_size, 1107296320
    );
    Pe32Section unused_edata = Pe32Section{
        name = "", virtual_size = 0, virtual_address = 0,
        raw_size = 0, raw_pointer = 0, characteristics = 0
    };
    Pe32Section unused_rsrc = Pe32Section{
        name = "", virtual_size = 0, virtual_address = 0,
        raw_size = 0, raw_pointer = 0, characteristics = 0
    };
    DBuffer headers = pe32_build_artifact_headers(
        layout, pe32_subsystem_windows_console(), false,
        text_section, rdata_section, data_section,
        pdata_section, xdata_section, tls_section, reloc_section,
        false, unused_edata, 0, false, unused_rsrc, 0,
        pdata.length
    );
    pe32_patch_u32(headers, 168, layout.text_rva + entry_offset);
    DBuffer rdata = pe32_build_rdata(layout);
    DBuffer data = pe32_build_data(layout);
    DBuffer tls = pe32_build_tls();
    DBuffer reloc = pe32_build_relocations(layout);
    usize raw_end = reloc_section.raw_pointer +
        reloc_section.raw_size;
    DBuffer image = d_buffer_create(raw_end);
    x64_copy_bytes(image, headers);
    x64_copy_bytes(image, code);
    pe32_pad_to(image, rdata_section.raw_pointer);
    x64_copy_bytes(image, rdata);
    x64_copy_bytes(image, constants);
    pe32_pad_to(image, data_section.raw_pointer);
    x64_copy_bytes(image, data);
    pe32_pad_to(image, pdata_section.raw_pointer);
    x64_copy_bytes(image, pdata);
    pe32_pad_to(image, xdata_section.raw_pointer);
    x64_copy_bytes(image, xdata);
    pe32_pad_to(image, tls_section.raw_pointer);
    x64_copy_bytes(image, tls);
    pe32_pad_to(image, reloc_section.raw_pointer);
    x64_copy_bytes(image, reloc);
    pe32_pad_to(image, raw_end);
    if headers.ok && rdata.ok && data.ok && tls.ok && reloc.ok &&
        image.ok {
        written = file.write_bytes(
            output_path, image.data, image.length
        );
    }
    d_buffer_destroy(image);
    d_buffer_destroy(reloc);
    d_buffer_destroy(tls);
    d_buffer_destroy(data);
    d_buffer_destroy(rdata);
    d_buffer_destroy(headers);
    return written;
}

unsafe status coff_link_module_bundle(
    ref IrContext context,
    ref DBuffer objects,
    ref DBuffer bundle,
    text output_path
) {
    status result = status{ code = 1 };
    DBuffer entry_name = d_buffer_create(80);
    DBuffer code = d_buffer_create(1024);
    DBuffer constants = d_buffer_create(1024);
    DBuffer pdata = d_buffer_create(1024);
    DBuffer xdata = d_buffer_create(1024);
    DBuffer definitions = d_buffer_create(1024);
    ptr byte bases = memory.alloc(
        cast(usize, 256) * size_of(usize)
    );
    ptr byte slots = memory.alloc(
        cast(usize, 8192) * size_of(usize)
    );
    usize index = 0;
    while index < 8192 {
        write_usize(slots, index * size_of(usize), 0);
        index = index + 1;
    }
    CoffLinkCounts counts = coff_link_bundle_collect(
        bundle, code, constants, pdata, xdata, bases
    );
    bool ok = counts.ok;
    if !ok {
        io.error("error[OPENC-COFF-LINK-PARSE]: object bundle rejected\n");
    }
    if ok {
        ok = coff_link_entry_name(context, objects, entry_name);
        if !ok {
            io.error("error[OPENC-COFF-LINK-ENTRY]: entry rejected\n");
        }
    }
    usize entry_offset = 0;
    if ok {
        ok = coff_link_validate_symbols(
            bundle, definitions, slots, bases,
            entry_name, entry_offset
        );
        if !ok {
            io.error("error[OPENC-COFF-LINK-SYMBOLS]: symbols rejected\n");
        }
    }
    Pe32RuntimeLayout layout = coff_link_layout(
        code, constants, pdata, xdata
    );
    if ok {
        ok = coff_link_text_relocations(
            bundle, code, definitions, slots, bases, layout
        ) && coff_link_pdata_relocations(
            bundle, pdata, bases, layout
        );
        if !ok {
            io.error("error[OPENC-COFF-LINK-RELOC]: relocations rejected\n");
        }
    }
    if ok && entry_offset < code.length &&
        counts.objects <= 64 && counts.functions <= 4096 {
        result = coff_link_emit_pe(
            code, constants, pdata, xdata, layout,
            entry_offset, output_path
        );
        if !result.ok {
            io.error("error[OPENC-COFF-LINK-PE]: image write failed\n");
        }
    } else {
        io.error("error[OPENC-COFF-LINK]: malformed, duplicate, undefined or unsupported COFF input\n");
    }
    memory.free(slots);
    memory.free(bases);
    d_buffer_destroy(definitions);
    d_buffer_destroy(xdata);
    d_buffer_destroy(pdata);
    d_buffer_destroy(constants);
    d_buffer_destroy(code);
    d_buffer_destroy(entry_name);
    return result;
}
