import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

unsafe bool cli_zip_add_data(
    ref CliZipWriter writer,
    text entry_name,
    ptr byte data,
    usize length,
    bool add_to_manifest
) {
    if !writer.ok || length > 16777216 { writer.ok = false; return false; }
    DBuffer full_name = d_buffer_create(
        text.byte_length(writer.root_name) + text.byte_length(entry_name) + 2
    );
    if text.byte_length(writer.root_name) != 0 {
        d_put(full_name, writer.root_name);
        d_put(full_name, "/");
    }
    d_put(full_name, entry_name);
    usize name_length = full_name.length;
    if !full_name.ok || name_length > 65535 {
        d_buffer_destroy(full_name);
        writer.ok = false;
        return false;
    }
    usize crc = cli_zip_crc32(data, length);
    usize local_offset = writer.offset;
    DBuffer local = d_buffer_create(30 + name_length);
    cli_zip_put_u32(local, 67324752);
    cli_zip_put_u16(local, 20);
    cli_zip_put_u16(local, 0);
    cli_zip_put_u16(local, 0);
    cli_zip_put_u16(local, 0);
    cli_zip_put_u16(local, 33);
    cli_zip_put_u32(local, crc);
    cli_zip_put_u32(local, length);
    cli_zip_put_u32(local, length);
    cli_zip_put_u16(local, name_length);
    cli_zip_put_u16(local, 0);
    d_put(local, d_buffer_text(full_name));
    bool wrote = local.ok &&
        cli_zip_write_piece(writer, local.data, local.length) &&
        cli_zip_write_piece(writer, data, length);

    cli_zip_put_u32(writer.central, 33639248);
    cli_zip_put_u16(writer.central, 788);
    cli_zip_put_u16(writer.central, 20);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 33);
    cli_zip_put_u32(writer.central, crc);
    cli_zip_put_u32(writer.central, length);
    cli_zip_put_u32(writer.central, length);
    cli_zip_put_u16(writer.central, name_length);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u16(writer.central, 0);
    cli_zip_put_u32(writer.central, 2175008768);
    cli_zip_put_u32(writer.central, local_offset);
    d_put(writer.central, d_buffer_text(full_name));
    writer.ok = writer.ok && writer.central.ok && wrote;
    if add_to_manifest {
        cli_zip_manifest_line(writer, entry_name, data, length);
    }
    writer.entries = writer.entries + 1;
    writer.input_bytes = writer.input_bytes + length;
    if length > writer.peak_entry_bytes { writer.peak_entry_bytes = length; }
    d_buffer_destroy(local);
    d_buffer_destroy(full_name);
    return writer.ok;
}

unsafe bool cli_zip_add_file(
    ref CliZipWriter writer,
    text entry_name,
    text source_path,
    bool add_to_manifest
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(source_path, out data, out length);
    if !loaded.ok { writer.ok = false; return false; }
    bool added = cli_zip_add_data(
        writer, entry_name, data, length, add_to_manifest
    );
    memory.free(data);
    return added;
}

unsafe CliZipWriter cli_zip_writer_create(
    text archive_path,
    text root_name,
    bool manifest_enabled
) {
    usize manifest_capacity = 1;
    if manifest_enabled { manifest_capacity = 524288; }
    return CliZipWriter{
        archive_path = archive_path,
        root_name = root_name,
        offset = 0,
        entries = 0,
        input_bytes = 0,
        peak_entry_bytes = 0,
        first_piece = true,
        ok = true,
        central = d_buffer_create(2097152),
        manifest = d_buffer_create(manifest_capacity)
    };
}

unsafe bool cli_zip_writer_finish(ref CliZipWriter writer) {
    usize central_offset = writer.offset;
    bool wrote = cli_zip_write_piece(
        writer, writer.central.data, writer.central.length
    );
    usize central_length = writer.central.length;
    DBuffer end = d_buffer_create(22);
    cli_zip_put_u32(end, 101010256);
    cli_zip_put_u16(end, 0);
    cli_zip_put_u16(end, 0);
    cli_zip_put_u16(end, writer.entries);
    cli_zip_put_u16(end, writer.entries);
    cli_zip_put_u32(end, central_length);
    cli_zip_put_u32(end, central_offset);
    cli_zip_put_u16(end, 0);
    wrote = wrote && end.ok &&
        cli_zip_write_piece(writer, end.data, end.length);
    d_buffer_destroy(end);
    return wrote && writer.ok && writer.entries != 0;
}

unsafe void cli_zip_writer_destroy(ref CliZipWriter writer) {
    d_buffer_destroy(writer.manifest);
    d_buffer_destroy(writer.central);
}
