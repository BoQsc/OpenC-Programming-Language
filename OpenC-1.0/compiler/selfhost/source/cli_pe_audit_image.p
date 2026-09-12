import system.file;
import system.io;
import system.memory;
import system.process;
import system.text;

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
