import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe usize cli_sh22_audit_object(
    text object_path,
    ref DBuffer checks,
    ref CliSh22Counts counts,
    ref CliSh22Coff observed
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(
        object_path, out data, out length
    );
    if !loaded.ok {
        cli_sh22_put_check(checks, counts, "coff_amd64_five_sections", false);
        cli_sh22_put_check(checks, counts, "coff_symbol_table", false);
        cli_sh22_put_check(checks, counts, "coff_rel32_relocations", false);
        cli_sh22_put_check(checks, counts, "coff_unwind_relocations", false);
        cli_sh22_put_check(checks, counts, "coff_c_abi_exports", false);
        cli_sh22_put_check(checks, counts, "coff_kernel32_undefined_symbols", false);
        return 0;
    }
    observed = cli_sh22_inspect_coff(data, length);
    cli_sh22_put_check(
        checks, counts, "coff_amd64_five_sections",
        observed.valid && observed.sections == 5
    );
    cli_sh22_put_check(
        checks, counts, "coff_symbol_table",
        observed.valid && observed.symbols != 0
    );
    cli_sh22_put_check(
        checks, counts, "coff_rel32_relocations",
        observed.valid && observed.text_relocations != 0
    );
    cli_sh22_put_check(
        checks, counts, "coff_unwind_relocations",
        observed.valid && observed.unwind_relocations != 0 &&
            observed.unwind_relocations % 3 == 0
    );
    bool exports = cli_sh22_bytes_contain(data, length, "openc_add") &&
        cli_sh22_bytes_contain(data, length, "openc_twice");
    cli_sh22_put_check(
        checks, counts, "coff_c_abi_exports", exports
    );
    cli_sh22_put_check(
        checks, counts, "coff_kernel32_undefined_symbols",
        cli_sh22_bytes_contain(data, length, "__imp_ExitProcess")
    );
    memory.free(data);
    return length;
}

unsafe void cli_sh22_audit_static_library(
    text library_path,
    ref DBuffer checks,
    ref CliSh22Counts counts
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(
        library_path, out data, out length
    );
    if !loaded.ok {
        cli_sh22_put_check(checks, counts, "static_archive_format", false);
        cli_sh22_put_check(checks, counts, "static_archive_object_member", false);
        return;
    }
    cli_sh22_put_check(
        checks, counts, "static_archive_format",
        cli_sh22_archive_base(data, length)
    );
    cli_sh22_put_check(
        checks, counts, "static_archive_object_member",
        cli_sh22_bytes_contain(data, length, "openc.obj/")
    );
    memory.free(data);
}

unsafe void cli_sh22_audit_import_library(
    text library_path,
    ref DBuffer checks,
    ref CliSh22Counts counts
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(
        library_path, out data, out length
    );
    if !loaded.ok {
        cli_sh22_put_check(checks, counts, "import_archive_format", false);
        cli_sh22_put_check(checks, counts, "short_import_object", false);
        cli_sh22_put_check(checks, counts, "import_library_c_abi_symbols", false);
        return;
    }
    bool short_signature = false;
    usize cursor = 0;
    while !short_signature && cursor + 4 <= length {
        short_signature = cast(u8, *(data + cursor)) == 0 &&
            cast(u8, *(data + cursor + 1)) == 0 &&
            cast(u8, *(data + cursor + 2)) == 255 &&
            cast(u8, *(data + cursor + 3)) == 255;
        cursor = cursor + 1;
    }
    cli_sh22_put_check(
        checks, counts, "import_archive_format",
        cli_sh22_archive_base(data, length)
    );
    cli_sh22_put_check(
        checks, counts, "short_import_object", short_signature
    );
    bool symbols = cli_sh22_bytes_contain(
        data, length, "__imp_openc_add"
    ) && cli_sh22_bytes_contain(data, length, "openc-sh22.dll");
    cli_sh22_put_check(
        checks, counts, "import_library_c_abi_symbols", symbols
    );
    memory.free(data);
}

unsafe usize cli_sh22_audit_dll(
    text dll_path,
    ref DBuffer checks,
    ref CliSh22Counts counts
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(dll_path, out data, out length);
    if !loaded.ok {
        cli_sh22_put_check(checks, counts, "dll_pe32_plus_amd64", false);
        cli_sh22_put_check(checks, counts, "dll_image_characteristic", false);
        cli_sh22_put_check(checks, counts, "dll_export_directory", false);
        cli_sh22_put_check(checks, counts, "dll_named_exports", false);
        cli_sh22_put_check(checks, counts, "dll_resource_directory", false);
        cli_sh22_put_check(checks, counts, "dll_manifest_and_resource_payload", false);
        cli_sh22_put_check(checks, counts, "dll_unwind_directory", false);
        cli_sh22_put_check(checks, counts, "dll_crt_free", false);
        return 0;
    }
    CliSh22Pe image = cli_sh22_inspect_pe(data, length);
    cli_sh22_put_check(
        checks, counts, "dll_pe32_plus_amd64",
        image.valid && image.sections == 9
    );
    cli_sh22_put_check(
        checks, counts, "dll_image_characteristic",
        image.valid && (image.characteristics & 8192) != 0
    );
    cli_sh22_put_check(
        checks, counts, "dll_export_directory",
        image.valid && image.export_rva != 0 &&
            cli_sh22_bytes_contain(data, length, ".edata")
    );
    bool named_exports = cli_sh22_bytes_contain(
        data, length, "openc_add"
    ) && cli_sh22_bytes_contain(data, length, "openc_twice");
    cli_sh22_put_check(
        checks, counts, "dll_named_exports", named_exports
    );
    cli_sh22_put_check(
        checks, counts, "dll_resource_directory",
        image.valid && image.resource_rva != 0 &&
            cli_sh22_bytes_contain(data, length, ".rsrc")
    );
    bool resource_payload = cli_sh22_bytes_contain(
        data, length, "requestedExecutionLevel"
    ) && cli_sh22_bytes_contain(
        data, length, "OpenC SH-22 deterministic RCDATA payload."
    );
    cli_sh22_put_check(
        checks, counts, "dll_manifest_and_resource_payload",
        resource_payload
    );
    cli_sh22_put_check(
        checks, counts, "dll_unwind_directory",
        image.valid && image.exception_rva != 0
    );
    bool crt_free = !cli_sh22_bytes_contain(
        data, length, "ucrtbase"
    ) && !cli_sh22_bytes_contain(
        data, length, "msvcrt"
    ) && !cli_sh22_bytes_contain(
        data, length, "vcruntime"
    ) && !cli_sh22_bytes_contain(data, length, "msvcp");
    cli_sh22_put_check(checks, counts, "dll_crt_free", crt_free);
    memory.free(data);
    return length;
}

unsafe void cli_sh22_audit_gui(
    text executable,
    ref DBuffer checks,
    ref CliSh22Counts counts
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(executable, out data, out length);
    if !loaded.ok {
        cli_sh22_put_check(checks, counts, "gui_subsystem", false);
        cli_sh22_put_check(checks, counts, "gui_manifest_and_resource", false);
        return;
    }
    CliSh22Pe image = cli_sh22_inspect_pe(data, length);
    cli_sh22_put_check(
        checks, counts, "gui_subsystem",
        image.valid && image.subsystem == 2
    );
    bool payload = image.valid && image.resource_rva != 0 &&
        cli_sh22_bytes_contain(data, length, "requestedExecutionLevel") &&
        cli_sh22_bytes_contain(
            data, length, "OpenC SH-22 deterministic RCDATA payload."
        );
    cli_sh22_put_check(
        checks, counts, "gui_manifest_and_resource", payload
    );
    memory.free(data);
}

unsafe void cli_sh22_audit_console(
    text executable,
    ref DBuffer checks,
    ref CliSh22Counts counts
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(executable, out data, out length);
    if !loaded.ok {
        cli_sh22_put_check(checks, counts, "console_subsystem", false);
        cli_sh22_put_check(checks, counts, "console_crt_free", false);
        return;
    }
    CliSh22Pe image = cli_sh22_inspect_pe(data, length);
    cli_sh22_put_check(
        checks, counts, "console_subsystem",
        image.valid && image.subsystem == 3
    );
    bool crt_free = !cli_sh22_bytes_contain(
        data, length, "ucrtbase"
    ) && !cli_sh22_bytes_contain(data, length, "msvcrt");
    cli_sh22_put_check(checks, counts, "console_crt_free", crt_free);
    memory.free(data);
}
