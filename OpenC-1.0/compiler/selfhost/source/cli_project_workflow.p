import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliTestOutcome {
    usize kind;
    i32 exit_code;
    usize source_hash;
    text output;
    text diagnostics;
}

unsafe TextSpan cli_json_string_field(text source, text field) {
    DBuffer needle = d_buffer_create(text.byte_length(field) + 4);
    d_put(needle, "\"");
    d_put(needle, field);
    d_put(needle, "\"");
    usize found = native_find(source, d_buffer_text(needle));
    usize after = found + text.byte_length(d_buffer_text(needle));
    d_buffer_destroy(needle);
    if found > text.byte_length(source) {
        return TextSpan{ start = 0, length = 0 };
    }
    JsonState state = JsonState{ cursor = after, failed = false };
    if !project_json_take(source, state, 58) {
        return TextSpan{ start = 0, length = 0 };
    }
    return project_json_string(source, state);
}

unsafe text cli_json_string_or(
    text source,
    text field,
    text fallback
) {
    TextSpan value = cli_json_string_field(source, field);
    if value.length == 0 { return fallback; }
    return project_slice(source, value.start, value.length);
}

unsafe void cli_put_hex_usize(ref DBuffer output, usize value) {
    usize shift = 60;
    while true {
        usize digit = (value >> shift) & 15;
        d_put(output, project_hex_digit(digit));
        if shift == 0 { return; }
        shift = shift - 4;
    }
}

usize cli_hash_text(usize initial, text value) {
    usize hash = initial;
    usize cursor = 0;
    while cursor < text.byte_length(value) {
        hash = (
            hash * 131 +
            cast(usize, byte_at_or_zero(value, cursor))
        ) % cast(usize, 4294967291);
        cursor = cursor + 1;
    }
    return hash;
}

usize cli_hash_initial() {
    return cast(usize, 2166136261);
}

unsafe usize cli_project_source_hash(text project_path) {
    text project_source;
    status loaded = file.read_text(project_path, out project_source);
    if !loaded.ok { return 0; }
    usize length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{
        length = 0, capacity = length + 1
    };
    PackedBuffer sources = PackedBuffer{
        length = 0, capacity = length + 1
    };
    ptr byte module_data = memory.alloc(
        modules.capacity * record_stride()
    );
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(
        sources.capacity * record_stride()
    );
    scope memory.free(source_data);
    if !project_parse_json(
        project_source,
        module_data, modules,
        source_data, sources
    ) {
        return 0;
    }
    usize hash = cli_hash_text(cli_hash_initial(), project_source);
    text project_root = path.directory(project_path);
    usize source_record = 0;
    while source_record < sources.length {
        text source_path = project_source_record_path(
            project_source, project_root, source_data, source_record
        );
        text source;
        status source_loaded = file.read_text(source_path, out source);
        if !source_loaded.ok { return 0; }
        hash = cli_hash_text(hash, source_path);
        hash = cli_hash_text(hash, source);
        source_record = source_record + 1;
    }
    return hash;
}

unsafe bool cli_write_format_record(
    text output_path,
    text input_path,
    bool write,
    usize files,
    usize changed,
    usize errors
) {
    if text.byte_length(output_path) == 0 { return true; }
    DBuffer record = d_buffer_create(65536);
    d_put(record, "{\n  \"schema\": \"openc.format.v1\",\n");
    d_put(record, "  \"status\": \"");
    if errors != 0 { d_put(record, "ERROR"); }
    else if !write && changed != 0 { d_put(record, "WOULD_CHANGE"); }
    else { d_put(record, "PASS"); }
    d_put(record, "\",\n  \"mode\": \"");
    if write { d_put(record, "write"); }
    else { d_put(record, "check"); }
    d_put(record, "\",\n  \"input\": ");
    cli_json_text(record, input_path);
    d_put(record, ",\n  \"files\": ");
    d_put_usize(record, files);
    d_put(record, ",\n  \"changed\": ");
    d_put_usize(record, changed);
    d_put(record, ",\n  \"errors\": ");
    d_put_usize(record, errors);
    d_put(record, ",\n  \"canonical\": {\n");
    d_put(record, "    \"encoding\": \"UTF-8\",\n");
    d_put(record, "    \"line_ending\": \"LF\",\n");
    d_put(record, "    \"indent_spaces\": 4,\n");
    d_put(record, "    \"source_extension\": \".p\"\n");
    d_put(record, "  }\n}\n");
    bool ok = record.ok;
    status written = file.write_text(
        output_path, d_buffer_text(record)
    );
    d_buffer_destroy(record);
    return ok && written.ok;
}

unsafe i32 cli_format_project(
    text project_path,
    bool write,
    text output_path
) {
    text project_source;
    status loaded = file.read_text(project_path, out project_source);
    if !loaded.ok {
        io.error("error: formatter could not read project\n");
        return 1;
    }
    usize length = text.byte_length(project_source);
    PackedBuffer modules = PackedBuffer{
        length = 0, capacity = length + 1
    };
    PackedBuffer sources = PackedBuffer{
        length = 0, capacity = length + 1
    };
    ptr byte module_data = memory.alloc(
        modules.capacity * record_stride()
    );
    scope memory.free(module_data);
    ptr byte source_data = memory.alloc(
        sources.capacity * record_stride()
    );
    scope memory.free(source_data);
    if !project_parse_json(
        project_source,
        module_data, modules,
        source_data, sources
    ) {
        io.error("error: formatter rejected invalid project JSON\n");
        return 1;
    }
    text project_root = path.directory(project_path);
    usize source_record = 0;
    usize changed_count = 0;
    usize error_count = 0;
    while source_record < sources.length {
        text source_path = project_source_record_path(
            project_source, project_root, source_data, source_record
        );
        usize formatted = cli_format_one(source_path, write);
        if formatted != 2 {
            if formatted == 1 {
                changed_count = changed_count + 1;
                if write { io.print("formatted: "); }
                else { io.print("would format: "); }
                io.println(source_path);
            }
        } else {
            error_count = error_count + 1;
        }
        source_record = source_record + 1;
    }
    if !cli_write_format_record(
        output_path, project_path, write,
        sources.length, changed_count, error_count
    ) {
        io.error("error: format record could not be written\n");
        return 1;
    }
    io.print("OpenC fmt: ");
    if error_count != 0 {
        io.println("ERROR");
        return 1;
    }
    if !write && changed_count != 0 {
        io.println("WOULD_CHANGE");
        return 1;
    }
    io.println("PASS");
    return 0;
}

unsafe i32 cli_format_command() {
    bool check = false;
    bool write = false;
    text source_path = "";
    text project_path = "";
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if value == "--check" {
            check = true;
        } else if value == "--write" {
            write = true;
        } else if cli_has_prefix(value, "--project=") {
            project_path = cli_remove_prefix(value, "--project=");
        } else if cli_has_prefix(value, "--source=") {
            source_path = cli_remove_prefix(value, "--source=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else if !cli_has_prefix(value, "--") &&
            text.byte_length(source_path) == 0 {
            source_path = value;
        } else {
            io.error("usage: openc fmt (--check|--write) (--project=PROJECT|SOURCE.p) [--output=FORMAT-RECORD.json]\n");
            return 64;
        }
        argument = argument + 1;
    }
    bool source_missing = text.byte_length(source_path) == 0;
    bool project_missing = text.byte_length(project_path) == 0;
    if check == write || source_missing == project_missing {
        io.error("usage: openc fmt (--check|--write) (--project=PROJECT|SOURCE.p) [--output=FORMAT-RECORD.json]\n");
        return 64;
    }
    if text.byte_length(project_path) != 0 {
        return cli_format_project(project_path, write, output_path);
    }
    usize formatted = cli_format_one(source_path, write);
    usize errors = 0;
    usize changed_count = 0;
    if formatted != 2 {
        if formatted == 1 { changed_count = 1; }
    } else {
        errors = 1;
    }
    if !cli_write_format_record(
        output_path, source_path, write, 1,
        changed_count, errors
    ) {
        io.error("error: format record could not be written\n");
        return 1;
    }
    if formatted == 2 { return 1; }
    if !write && formatted == 1 {
        io.println("OpenC fmt: WOULD_CHANGE");
        return 1;
    }
    io.println("OpenC fmt: PASS");
    return 0;
}
