import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool cli_release_build_archive(
    text root,
    text plan,
    text version,
    text archive,
    bool standalone,
    text compiler,
    text compiler_record,
    text compiler_hash,
    text build_record_hash,
    ref usize plan_records,
    ref usize archive_entries,
    ref usize input_bytes,
    ref usize peak_entry_bytes
) {
    DBuffer root_name = d_buffer_create(text.byte_length(version) + 16);
    d_put(root_name, "OpenC-"); d_put(root_name, version);
    CliZipWriter writer = cli_zip_writer_create(
        archive, d_buffer_text(root_name), standalone
    );
    usize records = 0;
    usize accepted = 0;
    bool ok = cli_release_add_plan(
        writer, root, plan, standalone, records, accepted
    );
    if standalone && ok {
        DBuffer release_record = d_buffer_create(4096);
        cli_release_record(
            version, compiler_hash, build_record_hash, release_record
        );
        ok = release_record.ok &&
            cli_zip_add_file(writer, "openc.exe", compiler, true) &&
            cli_zip_add_file(
                writer, "openc.exe.build.json", compiler_record, true
            ) &&
            cli_zip_add_file(
                writer, "bootstrap/openc-stage0.exe", compiler, true
            ) &&
            cli_zip_add_file(
                writer, "README-STANDALONE.md",
                path.join(root, "release/STANDALONE_WINDOWS_README.md"), true
            ) &&
            cli_zip_add_data(
                writer, "STANDALONE-RELEASE.json", release_record.data,
                release_record.length, true
            );
        if ok {
            ok = cli_zip_add_data(
                writer, "STANDALONE-MANIFEST.sha256", writer.manifest.data,
                writer.manifest.length, false
            );
        }
        d_buffer_destroy(release_record);
    }
    if ok { ok = cli_zip_writer_finish(writer); }
    plan_records = records;
    archive_entries = writer.entries;
    input_bytes = writer.input_bytes;
    peak_entry_bytes = writer.peak_entry_bytes;
    cli_zip_writer_destroy(writer);
    d_buffer_destroy(root_name);
    return ok;
}

unsafe bool cli_release_verify_manifest(
    text distribution,
    usize expected_entries,
    ref usize entries
) {
    text manifest;
    status loaded = file.read_text(path.join(
        distribution, "STANDALONE-MANIFEST.sha256"
    ), out manifest);
    if !loaded.ok { return false; }
    NativeCursor cursor = NativeCursor{ value = 0 };
    bool valid = true;
    usize entry_count = 0;
    while valid && cursor.value < text.byte_length(manifest) {
        TextSpan line_span = native_next_line(manifest, cursor);
        text line = project_slice(
            manifest, line_span.start, line_span.length
        );
        if text.byte_length(line) != 0 {
            usize line_length = text.byte_length(line);
            text expected = "";
            text relative = "";
            if line_length >= 67 && byte_at_or_zero(line, 64) == 32 &&
                byte_at_or_zero(line, 65) == 32 {
                expected = project_slice(line, 0, 64);
                relative = project_slice(line, 66, line_length - 66);
            }
            DBuffer actual = d_buffer_create(65);
            valid = text.byte_length(expected) == 64 &&
                text.byte_length(relative) != 0 &&
                cli_release_hash_file(path.join(distribution, relative), actual) &&
                d_buffer_text(actual) == expected;
            d_buffer_destroy(actual);
            entry_count = entry_count + 1;
        }
    }
    entries = entry_count;
    return valid && entry_count + 1 == expected_entries;
}

unsafe bool cli_release_run_task(
    ref DBuffer command,
    text marker,
    ref usize elapsed
) {
    usize started = process.monotonic_milliseconds();
    i32 exit_code;
    text output;
    status ran = cli_process_run_bounded(
        d_buffer_text(command), cast(usize, 300000), out exit_code, out output
    );
    elapsed = process.monotonic_milliseconds() - started;
    if !ran.ok { return false; }
    return exit_code == 0 && native_contains(output, marker);
}
