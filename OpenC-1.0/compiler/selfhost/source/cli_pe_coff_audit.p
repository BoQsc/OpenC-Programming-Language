import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

external(c, "cli_sh22_dynamic_probe") i32 cli_sh22_dynamic_probe(
    text dll_path
);

struct CliSh22Counts {
    usize total;
    usize passed;
}

struct CliSh22Pe {
    bool valid;
    usize sections;
    usize subsystem;
    usize characteristics;
    usize export_rva;
    usize import_rva;
    usize resource_rva;
    usize exception_rva;
    usize iat_rva;
}

struct CliSh22Coff {
    bool valid;
    usize sections;
    usize symbols;
    usize text_relocations;
    usize unwind_relocations;
}

unsafe void cli_sh22_put_check(
    ref DBuffer checks,
    ref CliSh22Counts counts,
    text name,
    bool passed
) {
    if counts.total != 0 { d_put(checks, ",\n"); }
    d_put(checks, "    ");
    cli_json_text(checks, name);
    d_put(checks, ": ");
    native_put_bool(checks, passed);
    counts.total = counts.total + 1;
    if passed { counts.passed = counts.passed + 1; }
    io.print("pe-coff ");
    io.print(name);
    io.print(": ");
    if passed { io.println("PASS"); } else { io.println("FAIL"); }
}

unsafe bool cli_sh22_bytes_contain(
    ptr byte data,
    usize length,
    text expected
) {
    usize expected_length = text.byte_length(expected);
    if expected_length == 0 { return true; }
    if expected_length > length { return false; }
    usize cursor = 0;
    while cursor + expected_length <= length {
        usize index = 0;
        while index < expected_length &&
            cast(u8, *(data + cursor + index)) ==
                byte_at_or_zero(expected, index) {
            index = index + 1;
        }
        if index == expected_length { return true; }
        cursor = cursor + 1;
    }
    return false;
}

unsafe bool cli_sh22_files_equal(text left, text right) {
    ptr byte left_data;
    usize left_length;
    status left_loaded = file.read_bytes_raw(
        left, out left_data, out left_length
    );
    if !left_loaded.ok { return false; }
    ptr byte right_data;
    usize right_length;
    status right_loaded = file.read_bytes_raw(
        right, out right_data, out right_length
    );
    if !right_loaded.ok {
        memory.free(left_data);
        return false;
    }
    bool same = left_length == right_length;
    usize index = 0;
    while same && index < left_length {
        same = cast(u8, *(left_data + index)) ==
            cast(u8, *(right_data + index));
        index = index + 1;
    }
    memory.free(right_data);
    memory.free(left_data);
    return same;
}

unsafe bool cli_sh22_run_artifact(
    text compiler,
    text project,
    text kind,
    text output,
    text subsystem,
    text dll_name,
    text manifest,
    text resource_path
) {
    DBuffer command = d_buffer_create(32768);
    cli_workflow_command_start(command, compiler, "artifact");
    cli_workflow_command_named_argument(command, "--project=", project);
    cli_workflow_command_named_argument(command, "--kind=", kind);
    cli_workflow_command_named_argument(command, "--output=", output);
    if text.byte_length(subsystem) != 0 {
        cli_workflow_command_named_argument(
            command, "--subsystem=", subsystem
        );
    }
    if text.byte_length(dll_name) != 0 {
        cli_workflow_command_named_argument(
            command, "--dll-name=", dll_name
        );
    }
    if text.byte_length(manifest) != 0 {
        cli_workflow_command_named_argument(
            command, "--manifest=", manifest
        );
    }
    if text.byte_length(resource_path) != 0 {
        cli_workflow_command_named_argument(
            command, "--resource=", resource_path
        );
    }
    i32 exit_code;
    text child_output;
    status ran = cli_process_run_bounded(
        d_buffer_text(command), cast(usize, 300000),
        out exit_code, out child_output
    );
    if !ran.ok {
        d_buffer_destroy(command);
        return false;
    }
    bool passed = exit_code == 0 && native_contains(
        child_output, "OpenC Windows artifact: PASS"
    );
    if !passed {
        io.error("SH-22 artifact child output:\n");
        io.error(child_output);
    }
    d_buffer_destroy(command);
    return passed;
}

unsafe CliSh22Coff cli_sh22_inspect_coff(
    ptr byte data,
    usize length
) {
    CliSh22Coff result = CliSh22Coff{
        valid = false, sections = 0, symbols = 0,
        text_relocations = 0, unwind_relocations = 0
    };
    bool valid = length >= 220;
    usize machine = pe_coff_read_u16(data, length, 0, valid);
    result.sections = pe_coff_read_u16(data, length, 2, valid);
    usize timestamp = pe_coff_read_u32(data, length, 4, valid);
    usize symbols_at = pe_coff_read_u32(data, length, 8, valid);
    result.symbols = pe_coff_read_u32(data, length, 12, valid);
    usize optional_size = pe_coff_read_u16(data, length, 16, valid);
    if !valid || machine != 34404 || result.sections != 5 ||
        timestamp != 0 || optional_size != 0 ||
        symbols_at > length || result.symbols >
            (length - symbols_at) / 18 {
        return result;
    }
    usize section = 20;
    usize index = 0;
    while valid && index < result.sections {
        usize raw_size = pe_coff_read_u32(
            data, length, section + 16, valid
        );
        usize raw_at = pe_coff_read_u32(
            data, length, section + 20, valid
        );
        usize reloc_at = pe_coff_read_u32(
            data, length, section + 24, valid
        );
        usize relocations = pe_coff_read_u16(
            data, length, section + 32, valid
        );
        if raw_at > length || raw_size > length - raw_at ||
            (relocations != 0 && (reloc_at > length ||
                relocations > (length - reloc_at) / 10)) {
            valid = false;
        }
        if index == 0 { result.text_relocations = relocations; }
        if index == 3 { result.unwind_relocations = relocations; }
        section = section + 40;
        index = index + 1;
    }
    result.valid = valid && result.symbols != 0 &&
        cli_sh22_bytes_contain(data, length, ".text") &&
        cli_sh22_bytes_contain(data, length, ".rdata") &&
        cli_sh22_bytes_contain(data, length, ".pdata") &&
        cli_sh22_bytes_contain(data, length, ".xdata");
    return result;
}

unsafe CliSh22Pe cli_sh22_inspect_pe(
    ptr byte data,
    usize length
) {
    CliSh22Pe result = CliSh22Pe{
        valid = false, sections = 0, subsystem = 0,
        characteristics = 0, export_rva = 0, import_rva = 0,
        resource_rva = 0, exception_rva = 0, iat_rva = 0
    };
    bool valid = length >= 512;
    if !valid || cast(u8, *data) != 77 ||
        cast(u8, *(data + 1)) != 90 {
        return result;
    }
    usize pe = pe_coff_read_u32(data, length, 60, valid);
    if !valid || pe > length || length - pe < 264 ||
        cast(u8, *(data + pe)) != 80 ||
        cast(u8, *(data + pe + 1)) != 69 {
        return result;
    }
    usize machine = pe_coff_read_u16(data, length, pe + 4, valid);
    result.sections = pe_coff_read_u16(data, length, pe + 6, valid);
    usize timestamp = pe_coff_read_u32(data, length, pe + 8, valid);
    result.characteristics = pe_coff_read_u16(
        data, length, pe + 22, valid
    );
    usize optional_header = pe + 24;
    usize magic = pe_coff_read_u16(
        data, length, optional_header, valid
    );
    result.subsystem = pe_coff_read_u16(
        data, length, optional_header + 68, valid
    );
    result.export_rva = pe_coff_read_u32(
        data, length, optional_header + 112, valid
    );
    result.import_rva = pe_coff_read_u32(
        data, length, optional_header + 120, valid
    );
    result.resource_rva = pe_coff_read_u32(
        data, length, optional_header + 128, valid
    );
    result.exception_rva = pe_coff_read_u32(
        data, length, optional_header + 136, valid
    );
    result.iat_rva = pe_coff_read_u32(
        data, length, optional_header + 208, valid
    );
    result.valid = valid && machine == 34404 && magic == 523 &&
        timestamp == 0 && result.sections >= 2 &&
        result.import_rva != 0 && result.iat_rva != 0;
    return result;
}

unsafe bool cli_sh22_archive_base(
    ptr byte data,
    usize length
) {
    return length >= 88 &&
        cli_sh22_bytes_contain(data, 8, "!<arch>\n") &&
        cli_sh22_bytes_contain(data + 8, 16, "/") &&
        cli_sh22_bytes_contain(data, length, "openc_add");
}

unsafe bool cli_sh22_source_contract(text root) {
    text resources;
    status resources_loaded = file.read_text(path.join(
        root, "standard_library/windows.resources/source/resources.p"
    ), out resources);
    text backend;
    status backend_loaded = file.read_text(path.join(
        root, "compiler/selfhost/source/backend_native_library.p"
    ), out backend);
    if !resources_loaded.ok || !backend_loaded.ok { return false; }
    return
        native_contains(resources, "load_absolute") &&
        native_contains(resources, "symbol_ascii_z") &&
        native_contains(resources, "call_i32_two") &&
        native_contains(resources, "ocw_library_close") &&
        native_contains(backend, "LoadLibraryExW") == false &&
        native_contains(backend, "native_import(function, 19)") &&
        native_contains(backend, "native_import(function, 20)") &&
        native_contains(backend, "native_import(function, 22)");
}
