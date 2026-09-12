import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

unsafe bool cli_pe_audit_imports(ptr byte data, usize length, usize section_table, usize section_count, usize import_rva, usize import_size, ref CliPeAuditResult result) {
    bool valid = import_rva != 0 && import_size >= 40 && import_size <= 4096;
    usize directory = 0;
    if valid {
        directory = cli_pe_rva_offset(data, length, section_table, section_count, import_rva, import_size, valid);
    }
    usize descriptor_count = 0;
    bool terminated = false;
    bool names_match = true;
    bool kernel32_only = true;
    usize descriptor_cursor = 0;
    while valid && descriptor_cursor + 20 <= import_size && ! terminated {
        usize descriptor = directory + descriptor_cursor;
        usize original_thunk = cli_pe_u32(data, length, descriptor, valid);
        usize time_date = cli_pe_u32(data, length, descriptor + 4, valid);
        usize forwarder = cli_pe_u32(data, length, descriptor + 8, valid);
        usize name_rva = cli_pe_u32(data, length, descriptor + 12, valid);
        usize first_thunk = cli_pe_u32(data, length, descriptor + 16, valid);
        if original_thunk == 0 && time_date == 0 && forwarder == 0 && name_rva == 0 && first_thunk == 0 {
            terminated = true;
        }
        else {
            descriptor_count = descriptor_count + 1;
            if descriptor_count > 1 || original_thunk == 0 || name_rva == 0 || first_thunk == 0 {
                valid = false;
            }
            bool name_valid = valid;
            usize name_offset = 0;
            if name_valid {
                name_offset = cli_pe_rva_offset(data, length, section_table, section_count, name_rva, 13, name_valid);
            }
            if ! name_valid || ! cli_pe_ascii_z_equals(data, length, name_offset, "KERNEL32.dll") {
                kernel32_only = false;
                valid = false;
            }
            usize thunk_index = 0;
            bool thunk_terminated = false;
            while valid && thunk_index <= pe32_import_count() && ! thunk_terminated {
                bool thunk_valid = true;
                usize thunk_offset = cli_pe_rva_offset(data, length, section_table, section_count, original_thunk + thunk_index * 8, 8, thunk_valid);
                if ! thunk_valid {
                    valid = false;
                }
                else {
                    usize hint_name_rva = cli_pe_u32(data, length, thunk_offset, valid);
                    usize high = cli_pe_u32(data, length, thunk_offset + 4, valid);
                    if hint_name_rva == 0 && high == 0 {
                        thunk_terminated = true;
                    }
                    else if high != 0 || thunk_index >= pe32_import_count() {
                        valid = false;
                    }
                    else {
                        bool symbol_valid = true;
                        usize symbol_offset = cli_pe_rva_offset(data, length, section_table, section_count, hint_name_rva, 3, symbol_valid);
                        if ! symbol_valid || ! cli_pe_ascii_z_equals(data, length, symbol_offset + 2, pe32_import_name(thunk_index)) {
                            names_match = false;
                            valid = false;
                        }
                        else {
                            result.imports = result.imports + 1;
                        }
                    }
                }
                thunk_index = thunk_index + 1;
            }
            if ! thunk_terminated {
                valid = false;
            }
        }
        descriptor_cursor = descriptor_cursor + 20;
    }
    result.kernel32_only = kernel32_only && descriptor_count == 1;
    result.expected_imports = names_match && result.imports == pe32_import_count();
    result.forbidden_crt_absent = result.kernel32_only;
    return valid && terminated && descriptor_count == 1 && result.expected_imports;
}
unsafe bool cli_pe_audit_relocations(ptr byte data, usize length, usize section_table, usize section_count, usize relocation_rva, usize relocation_size, ref CliPeAuditResult result) {
    bool valid = relocation_rva != 0 && relocation_size >= 8 && relocation_size <= 16777216;
    usize offset = 0;
    if valid {
        offset = cli_pe_rva_offset(data, length, section_table, section_count, relocation_rva, relocation_size, valid);
    }
    usize cursor = 0;
    while valid && cursor < relocation_size {
        if relocation_size - cursor < 8 {
            valid = false;
        }
        else {
            usize page = cli_pe_u32(data, length, offset + cursor, valid);
            usize block_size = cli_pe_u32(data, length, offset + cursor + 4, valid);
            if page == 0 || block_size < 8 || block_size % 2 != 0 || block_size > relocation_size - cursor {
                valid = false;
            }
            else {
                usize entry = 8;
                while valid && entry < block_size {
                    usize encoded = cli_pe_u16(data, length, offset + cursor + entry, valid);
                    usize kind = encoded >> 12;
                    if kind == 10 {
                        result.relocations = result.relocations + 1;
                    }
                    else if kind != 0 {
                        valid = false;
                    }
                    entry = entry + 2;
                }
                cursor = cursor + block_size;
            }
        }
    }
    return valid && cursor == relocation_size && result.relocations != 0;
}
unsafe bool cli_pe_audit_unwind(ptr byte data, usize length, usize section_table, usize section_count, usize exception_rva, usize exception_size, usize text_rva, usize text_size, usize pdata_rva, usize pdata_size, usize xdata_rva, usize xdata_size, ref CliPeAuditResult result) {
    bool valid = exception_rva == pdata_rva && exception_size == pdata_size && exception_size >= 12 && exception_size % 12 == 0 && exception_size <= 16777216;
    usize offset = 0;
    if valid {
        offset = cli_pe_rva_offset(data, length, section_table, section_count, exception_rva, exception_size, valid);
    }
    bool version_one = true;
    bool sorted = true;
    usize previous_end = 0;
    usize cursor = 0;
    while valid && cursor < exception_size {
        usize begin = cli_pe_u32(data, length, offset + cursor, valid);
        usize end = cli_pe_u32(data, length, offset + cursor + 4, valid);
        usize unwind_rva = cli_pe_u32(data, length, offset + cursor + 8, valid);
        if begin < text_rva || end <= begin || begin - text_rva >= text_size || end - text_rva > text_size || (previous_end != 0 && begin < previous_end) {
            sorted = false;
            valid = false;
        }
        if unwind_rva < xdata_rva || unwind_rva - xdata_rva >= xdata_size {
            version_one = false;
            valid = false;
        }
        bool unwind_valid = valid;
        usize unwind_offset = 0;
        if unwind_valid {
            unwind_offset = cli_pe_rva_offset(data, length, section_table, section_count, unwind_rva, 4, unwind_valid);
        }
        if ! unwind_valid {
            version_one = false;
            valid = false;
        }
        else {
            usize header = cast(usize, cast(u8, * (data + unwind_offset)));
            usize prolog = cast(usize, cast(u8, * (data + unwind_offset + 1)));
            usize codes = cast(usize, cast(u8, * (data + unwind_offset + 2)));
            usize record_size = x64_align_up(4 + codes * 2, 4);
            bool record_valid = true;
            cli_pe_rva_offset(data, length, section_table, section_count, unwind_rva, record_size, record_valid);
            if(header & 7) != 1 || (header >> 3) != 0 || prolog > end - begin || ! record_valid {
                version_one = false;
                valid = false;
            }
        }
        previous_end = end;
        result.runtime_functions = result.runtime_functions + 1;
        cursor = cursor + 12;
    }
    result.unwind_version_one = version_one && result.runtime_functions != 0;
    result.unwind_sorted_nonoverlapping = sorted && result.runtime_functions != 0;
    return valid && cursor == exception_size && result.unwind_version_one && result.unwind_sorted_nonoverlapping;
}
