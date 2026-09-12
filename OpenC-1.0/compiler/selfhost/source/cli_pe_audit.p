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
unsafe CliPeAuditResult cli_pe_audit_image(ptr byte data, usize length) {
    CliPeAuditResult result = CliPeAuditResult{
        file_bytes = length, sections = 0, imports = 0, runtime_functions = 0, relocations = 0, subsystem = 0, dos_and_pe_headers = false, amd64_pe32_plus = false, deterministic_headers = false, section_layout = false, section_bounds = false, write_xor_execute = false, entry_point = false, import_directory = false, kernel32_only = false, expected_imports = false, forbidden_crt_absent = false, relocation_directory = false, tls_directory = false, exception_directory = false, unwind_version_one = false, unwind_sorted_nonoverlapping = false
    };
    bool valid = length >= 1024;
    if ! valid {
        return result;
    }
    usize pe_offset = cli_pe_u32(data, length, 60, valid);
    bool mz = cast(u8, * data) == 77 && cast(u8, * (data + 1)) == 90;
    bool signature = false;
    if valid && pe_offset <= length && length - pe_offset >= 24 {
        signature = cast(u8, * (data + pe_offset)) == 80 && cast(u8, * (data + pe_offset + 1)) == 69 && cast(u8, * (data + pe_offset + 2)) == 0 && cast(u8, * (data + pe_offset + 3)) == 0;
    }
    else {
        valid = false;
    }
    result.dos_and_pe_headers = valid && mz && signature;
    if ! result.dos_and_pe_headers {
        return result;
    }
    usize machine = cli_pe_u16(data, length, pe_offset + 4, valid);
    usize section_count = cli_pe_u16(data, length, pe_offset + 6, valid);
    usize timestamp = cli_pe_u32(data, length, pe_offset + 8, valid);
    usize optional_size = cli_pe_u16(data, length, pe_offset + 20, valid);
    usize optional_header = pe_offset + 24;
    usize magic = cli_pe_u16(data, length, optional_header, valid);
    usize entry_rva = cli_pe_u32(data, length, optional_header + 16, valid);
    usize section_alignment = cli_pe_u32(data, length, optional_header + 32, valid);
    usize file_alignment = cli_pe_u32(data, length, optional_header + 36, valid);
    usize checksum = cli_pe_u32(data, length, optional_header + 64, valid);
    result.subsystem = cli_pe_u16(data, length, optional_header + 68, valid);
    usize dll_characteristics = cli_pe_u16(data, length, optional_header + 70, valid);
    usize directory_count = cli_pe_u32(data, length, optional_header + 108, valid);
    result.sections = section_count;
    result.amd64_pe32_plus = valid && machine == 34404 && magic == 523 && optional_size == 240 && directory_count >= 16;
    result.deterministic_headers = timestamp == 0 && checksum == 0;
    if ! result.amd64_pe32_plus {
        return result;
    }
    usize import_rva = cli_pe_u32(data, length, optional_header + 120, valid);
    usize import_size = cli_pe_u32(data, length, optional_header + 124, valid);
    usize exception_rva = cli_pe_u32(data, length, optional_header + 136, valid);
    usize exception_size = cli_pe_u32(data, length, optional_header + 140, valid);
    usize relocation_rva = cli_pe_u32(data, length, optional_header + 152, valid);
    usize relocation_size = cli_pe_u32(data, length, optional_header + 156, valid);
    usize tls_rva = cli_pe_u32(data, length, optional_header + 184, valid);
    usize tls_size = cli_pe_u32(data, length, optional_header + 188, valid);
    usize iat_rva = cli_pe_u32(data, length, optional_header + 208, valid);
    usize iat_size = cli_pe_u32(data, length, optional_header + 212, valid);
    usize section_table = optional_header + optional_size;
    if section_count != 7 || section_table > length || section_count * 40 > length - section_table {
        valid = false;
    }
    bool layout = valid && section_alignment == 4096 && file_alignment == 512;
    bool bounds = valid;
    bool write_xor_execute = valid;
    usize text_rva = 0;
    usize text_size = 0;
    usize pdata_rva = 0;
    usize pdata_size = 0;
    usize xdata_rva = 0;
    usize xdata_size = 0;
    usize index = 0;
    while valid && index < section_count {
        usize section = section_table + index * 40;
        if ! cli_pe_section_name_equals(data, length, section, cli_pe_expected_section(index)) {
            layout = false;
        }
        usize virtual_size = cli_pe_u32(data, length, section + 8, valid);
        usize virtual_address = cli_pe_u32(data, length, section + 12, valid);
        usize raw_size = cli_pe_u32(data, length, section + 16, valid);
        usize raw_pointer = cli_pe_u32(data, length, section + 20, valid);
        usize characteristics = cli_pe_u32(data, length, section + 36, valid);
        if raw_pointer > length || raw_size > length - raw_pointer || raw_pointer % file_alignment != 0 || virtual_address % section_alignment != 0 || virtual_size == 0 {
            bounds = false;
        }
        bool writable = (characteristics & 2147483648) != 0;
        bool executable = (characteristics & 536870912) != 0;
        if writable && executable {
            write_xor_execute = false;
        }
        if index == 0 {
            text_rva = virtual_address;
            text_size = virtual_size;
            if ! executable || writable {
                layout = false;
            }
        }
        else if executable {
            layout = false;
        }
        if index == 3 {
            pdata_rva = virtual_address;
            pdata_size = virtual_size;
        }
        if index == 4 {
            xdata_rva = virtual_address;
            xdata_size = virtual_size;
        }
        index = index + 1;
    }
    result.section_layout = layout;
    result.section_bounds = bounds;
    result.write_xor_execute = write_xor_execute;
    result.entry_point = entry_rva >= text_rva && entry_rva - text_rva < text_size && (result.subsystem == 2 || result.subsystem == 3) && (dll_characteristics & 64) != 0 && (dll_characteristics & 256) != 0;
    result.import_directory = cli_pe_audit_imports(data, length, section_table, section_count, import_rva, import_size, result) && iat_rva != 0 && iat_size == (pe32_import_count() + 1) * 8;
    result.relocation_directory = cli_pe_audit_relocations(data, length, section_table, section_count, relocation_rva, relocation_size, result);
    bool tls_valid = tls_rva != 0 && tls_size == 40;
    usize tls_offset = 0;
    if tls_valid {
        tls_offset = cli_pe_rva_offset(data, length, section_table, section_count, tls_rva, tls_size, tls_valid);
    }
    if tls_valid {
        u64 tls_start = cli_pe_u64(data, length, tls_offset, tls_valid);
        u64 tls_end = cli_pe_u64(data, length, tls_offset + 8, tls_valid);
        u64 tls_index = cli_pe_u64(data, length, tls_offset + 16, tls_valid);
        tls_valid = tls_valid && tls_start != cast(u64, 0) && tls_end > tls_start && tls_index != cast(u64, 0);
    }
    result.tls_directory = tls_valid;
    result.exception_directory = cli_pe_audit_unwind(data, length, section_table, section_count, exception_rva, exception_size, text_rva, text_size, pdata_rva, pdata_size, xdata_rva, xdata_size, result);
    return result;
}
bool cli_pe_audit_passed(ref CliPeAuditResult result) {
    return result.dos_and_pe_headers && result.amd64_pe32_plus && result.deterministic_headers && result.section_layout && result.section_bounds && result.write_xor_execute && result.entry_point && result.import_directory && result.kernel32_only && result.expected_imports && result.forbidden_crt_absent && result.relocation_directory && result.tls_directory && result.exception_directory && result.unwind_version_one && result.unwind_sorted_nonoverlapping;
}
unsafe bool cli_pe_audit_write_report(text output_path, text input_path, ref CliPeAuditResult result, bool passed) {
    DBuffer report = d_buffer_create(4096);
    d_put(report, "{\n  \"schema\": \"openc.native_pe_audit.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"input\": ");
    cli_json_text(report, input_path);
    d_put(report, ",\n  \"file_bytes\": ");
    d_put_usize(report, result.file_bytes);
    d_put(report, ",\n  \"observations\": {\n    \"sections\": ");
    d_put_usize(report, result.sections);
    d_put(report, ",\n    \"imports\": ");
    d_put_usize(report, result.imports);
    d_put(report, ",\n    \"runtime_functions\": ");
    d_put_usize(report, result.runtime_functions);
    d_put(report, ",\n    \"relocations\": ");
    d_put_usize(report, result.relocations);
    d_put(report, ",\n    \"subsystem\": ");
    d_put_usize(report, result.subsystem);
    d_put(report, "\n  },\n  \"checks\": {\n");
    d_put(report, "    \"dos_and_pe_headers\": ");
    native_put_bool(report, result.dos_and_pe_headers);
    d_put(report, ",\n    \"amd64_pe32_plus\": ");
    native_put_bool(report, result.amd64_pe32_plus);
    d_put(report, ",\n    \"deterministic_headers\": ");
    native_put_bool(report, result.deterministic_headers);
    d_put(report, ",\n    \"section_layout\": ");
    native_put_bool(report, result.section_layout);
    d_put(report, ",\n    \"section_bounds\": ");
    native_put_bool(report, result.section_bounds);
    d_put(report, ",\n    \"write_xor_execute\": ");
    native_put_bool(report, result.write_xor_execute);
    d_put(report, ",\n    \"entry_point\": ");
    native_put_bool(report, result.entry_point);
    d_put(report, ",\n    \"import_directory\": ");
    native_put_bool(report, result.import_directory);
    d_put(report, ",\n    \"kernel32_only\": ");
    native_put_bool(report, result.kernel32_only);
    d_put(report, ",\n    \"expected_imports\": ");
    native_put_bool(report, result.expected_imports);
    d_put(report, ",\n    \"forbidden_crt_absent\": ");
    native_put_bool(report, result.forbidden_crt_absent);
    d_put(report, ",\n    \"relocation_directory\": ");
    native_put_bool(report, result.relocation_directory);
    d_put(report, ",\n    \"tls_directory\": ");
    native_put_bool(report, result.tls_directory);
    d_put(report, ",\n    \"exception_directory\": ");
    native_put_bool(report, result.exception_directory);
    d_put(report, ",\n    \"unwind_version_one\": ");
    native_put_bool(report, result.unwind_version_one);
    d_put(report, ",\n    \"unwind_sorted_nonoverlapping\": ");
    native_put_bool(report, result.unwind_sorted_nonoverlapping);
    d_put(report, "\n  },\n  \"status\": \"");
    if passed {
        d_put(report, "PASS");
    }
    else {
        d_put(report, "FAIL");
    }
    d_put(report, "\"\n}\n");
    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    return report_ok && written.ok;
}
unsafe i32 cli_pe_audit_command() {
    text input_path = "";
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--input=") {
            input_path = cli_remove_prefix(value, "--input=");
        }
        else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        }
        else {
            io.error("usage: openc pe-audit --input=FILE --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(input_path) == 0 || text.byte_length(output_path) == 0 {
        io.error("usage: openc pe-audit --input=FILE --output=REPORT.json\n");
        return 64;
    }
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(input_path, out data, out length);
    CliPeAuditResult result = CliPeAuditResult{
        file_bytes = 0, sections = 0, imports = 0, runtime_functions = 0, relocations = 0, subsystem = 0, dos_and_pe_headers = false, amd64_pe32_plus = false, deterministic_headers = false, section_layout = false, section_bounds = false, write_xor_execute = false, entry_point = false, import_directory = false, kernel32_only = false, expected_imports = false, forbidden_crt_absent = false, relocation_directory = false, tls_directory = false, exception_directory = false, unwind_version_one = false, unwind_sorted_nonoverlapping = false
    };
    if loaded.ok {
        result = cli_pe_audit_image(data, length);
        memory.free(data);
    }
    bool passed = loaded.ok && cli_pe_audit_passed(result);
    if ! cli_pe_audit_write_report(output_path, input_path, result, passed) {
        io.error("error: PE audit report could not be written\n");
        return 1;
    }
    io.print("OpenC PE audit: ");
    if passed {
        io.println("PASS");
    }
    else {
        io.println("FAIL");
    }
    if passed {
        return 0;
    }
    return 1;
}
