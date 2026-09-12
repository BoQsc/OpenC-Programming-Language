import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;
struct CliPeAuditResult {
    usize file_bytes;
    usize sections;
    usize imports;
    usize runtime_functions;
    usize relocations;
    usize subsystem;
    bool dos_and_pe_headers;
    bool amd64_pe32_plus;
    bool deterministic_headers;
    bool section_layout;
    bool section_bounds;
    bool write_xor_execute;
    bool entry_point;
    bool import_directory;
    bool kernel32_only;
    bool expected_imports;
    bool forbidden_crt_absent;
    bool relocation_directory;
    bool tls_directory;
    bool exception_directory;
    bool unwind_version_one;
    bool unwind_sorted_nonoverlapping;
}
unsafe usize cli_pe_u16(ptr byte data, usize length, usize offset, ref bool valid) {
    if offset > length || length - offset < 2 {
        valid = false;
        return 0;
    }
    return cast(usize, cast(u8, * (data + offset))) | (cast(usize, cast(u8, * (data + offset + 1))) << 8);
}
unsafe usize cli_pe_u32(ptr byte data, usize length, usize offset, ref bool valid) {
    if offset > length || length - offset < 4 {
        valid = false;
        return 0;
    }
    usize value = 0;
    usize index = 0;
    while index < 4 {
        value = value | (cast(usize, cast(u8, * (data + offset + index))) << (index * 8));
        index = index + 1;
    }
    return value;
}
unsafe u64 cli_pe_u64(ptr byte data, usize length, usize offset, ref bool valid) {
    if offset > length || length - offset < 8 {
        valid = false;
        return cast(u64, 0);
    }
    u64 value = cast(u64, 0);
    usize index = 0;
    while index < 8 {
        value = value | (cast(u64, cast(u8, * (data + offset + index))) << (index * 8));
        index = index + 1;
    }
    return value;
}
unsafe bool cli_pe_ascii_z_equals(ptr byte data, usize length, usize offset, text expected) {
    usize expected_length = text.byte_length(expected);
    if offset > length || expected_length + 1 > length - offset {
        return false;
    }
    usize index = 0;
    while index < expected_length {
        if cast(u8, * (data + offset + index)) != byte_at_or_zero(expected, index) {
            return false;
        }
        index = index + 1;
    }
    return cast(u8, * (data + offset + expected_length)) == 0;
}
unsafe bool cli_pe_section_name_equals(ptr byte data, usize length, usize offset, text expected) {
    if offset > length || length - offset < 8 {
        return false;
    }
    usize expected_length = text.byte_length(expected);
    if expected_length > 8 {
        return false;
    }
    usize index = 0;
    while index < 8 {
        u8 wanted = 0;
        if index < expected_length {
            wanted = byte_at_or_zero(expected, index);
        }
        if cast(u8, * (data + offset + index)) != wanted {
            return false;
        }
        index = index + 1;
    }
    return true;
}
text cli_pe_expected_section(usize index) {
    if index == 0 {
        return ".text";
    }
    if index == 1 {
        return ".rdata";
    }
    if index == 2 {
        return ".data";
    }
    if index == 3 {
        return ".pdata";
    }
    if index == 4 {
        return ".xdata";
    }
    if index == 5 {
        return ".tls";
    }
    return ".reloc";
}
unsafe usize cli_pe_rva_offset(ptr byte data, usize length, usize section_table, usize section_count, usize rva, usize needed, ref bool valid) {
    usize index = 0;
    while index < section_count {
        bool fields_valid = valid;
        if ! fields_valid {
            return 0;
        }
        usize section = section_table + index * 40;
        usize virtual_size = cli_pe_u32(data, length, section + 8, valid);
        usize virtual_address = cli_pe_u32(data, length, section + 12, valid);
        usize raw_size = cli_pe_u32(data, length, section + 16, valid);
        usize raw_pointer = cli_pe_u32(data, length, section + 20, valid);
        usize span = virtual_size;
        if raw_size > span {
            span = raw_size;
        }
        fields_valid = valid;
        if fields_valid {
            if rva >= virtual_address && rva - virtual_address < span {
                usize delta = rva - virtual_address;
                if delta > raw_size || needed > raw_size - delta || raw_pointer > length || delta > length - raw_pointer || needed > length - raw_pointer - delta {
                    valid = false;
                    return 0;
                }
                return raw_pointer + delta;
            }
        }
        index = index + 1;
    }
    valid = false;
    return 0;
}
