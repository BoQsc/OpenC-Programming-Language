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

TextSpan cli_json_string_field(text source, text field) {
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

text cli_json_string_or(
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
        bool changed = false;
        status formatted = cli_format_one(
            source_path, write, out changed
        );
        if !formatted.ok {
            error_count = error_count + 1;
        } else if changed {
            changed_count = changed_count + 1;
            if write { io.print("formatted: "); }
            else { io.print("would format: "); }
            io.println(source_path);
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
    bool changed = false;
    status format_status = cli_format_one(
        source_path, write, out changed
    );
    usize errors = 0;
    if !format_status.ok { errors = 1; }
    usize changed_count = 0;
    if changed { changed_count = 1; }
    if !cli_write_format_record(
        output_path, source_path, write, 1,
        changed_count, errors
    ) {
        io.error("error: format record could not be written\n");
        return 1;
    }
    if !format_status.ok { return 1; }
    if !write && changed {
        io.println("OpenC fmt: WOULD_CHANGE");
        return 1;
    }
    io.println("OpenC fmt: PASS");
    return 0;
}

unsafe void cli_info_put_implementation(ref DBuffer record) {
    d_put(record, "\"implementation\": {\n");
    d_put(record, "    \"name\": \"OpenC\",\n");
    d_put(record, "    \"version\": ");
    cli_json_text(record, cli_version());
    d_put(record, ",\n    \"language\": \"OpenC\",\n");
    d_put(record, "    \"component\": \"native-compiler\"\n");
    d_put(record, "  }");
}

unsafe void cli_info_put_target(ref DBuffer record) {
    d_put(record, "\"target\": {\n");
    d_put(record, "    \"triple\": \"windows-x86_64-hosted\",\n");
    d_put(record, "    \"pointer_bits\": 64,\n");
    d_put(record, "    \"endianness\": \"little\",\n");
    d_put(record, "    \"backend\": \"c11-tinycc-win64\",\n");
    d_put(record, "    \"hash_algorithm\": \"openc-stable32\",\n");
    d_put(record, "    \"hash\": \"");
    cli_put_hex_usize(
        record,
        cli_hash_text(
            cli_hash_initial(),
            "windows-x86_64-hosted|64|little|c11-tinycc-win64"
        )
    );
    d_put(record, "\"\n  }");
}

unsafe void cli_info_put_limits(ref DBuffer record) {
    d_put(record, "\"limits\": {\n");
    d_put(record, "    \"usize_bits\": 64,\n");
    d_put(record, "    \"isize_bits\": 64,\n");
    d_put(record, "    \"maximum_source_bytes\": 4194304,\n");
    d_put(record, "    \"formatter_width_preference\": 100\n");
    d_put(record, "  }");
}

unsafe void cli_info_put_types(ref DBuffer record) {
    d_put(record, "\"types\": [");
    d_put(record, "\"bool\", \"byte\", \"i8\", \"i16\", \"i32\", ");
    d_put(record, "\"i64\", \"u8\", \"u16\", \"u32\", \"u64\", ");
    d_put(record, "\"isize\", \"usize\", \"f32\", \"f64\", ");
    d_put(record, "\"text\", \"status\", \"ptr\", \"slice\"");
    d_put(record, "]");
}

unsafe void cli_info_put_modules(
    ref DBuffer record,
    text project_source,
    text project_root,
    ptr byte module_data,
    ref PackedBuffer modules,
    ptr byte source_data
) {
    d_put(record, "\"modules\": [\n");
    usize module_record = 0;
    while module_record < modules.length {
        if module_record != 0 { d_put(record, ",\n"); }
        d_put(record, "    {\"name\": ");
        cli_json_text(
            record,
            project_slice(
                project_source,
                read_record_field(module_data, module_record, 0),
                read_record_field(module_data, module_record, 1)
            )
        );
        d_put(record, ", \"sources\": [");
        usize first = read_record_field(
            module_data, module_record, 2
        );
        usize count = read_record_field(
            module_data, module_record, 3
        );
        usize source_index = 0;
        while source_index < count {
            if source_index != 0 { d_put(record, ", "); }
            cli_json_text(
                record,
                project_source_record_path(
                    project_source, project_root,
                    source_data, first + source_index
                )
            );
            source_index = source_index + 1;
        }
        d_put(record, "]}");
        module_record = module_record + 1;
    }
    d_put(record, "\n  ]");
}

unsafe void cli_info_put_sources(
    ref DBuffer record,
    text project_source,
    text project_root,
    ptr byte source_data,
    ref PackedBuffer sources
) {
    d_put(record, "\"sources\": [");
    usize source_record = 0;
    while source_record < sources.length {
        if source_record != 0 { d_put(record, ", "); }
        cli_json_text(
            record,
            project_source_record_path(
                project_source, project_root,
                source_data, source_record
            )
        );
        source_record = source_record + 1;
    }
    d_put(record, "]");
}

unsafe i32 cli_info_command() {
    text project_path = "";
    text output_path = "";
    bool json_stdout = false;
    usize view = 0;
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--project=") {
            project_path = cli_remove_prefix(value, "--project=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else if value == "--json" {
            json_stdout = true;
        } else if value == "--context" {
            view = 0;
        } else if value == "--sources" {
            view = 1;
        } else if value == "--modules" {
            view = 2;
        } else if value == "--limits" {
            view = 3;
        } else if value == "--dependencies" {
            view = 4;
        } else if value == "--target" {
            view = 5;
        } else if value == "--types" {
            view = 6;
        } else {
            io.error("usage: openc info --project=PROJECT [--context|--sources|--modules|--limits|--dependencies|--target|--types] [--json] [--output=CONTEXT.json]\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(project_path) == 0 {
        io.error("usage: openc info --project=PROJECT [--context|--sources|--modules|--limits|--dependencies|--target|--types] [--json] [--output=CONTEXT.json]\n");
        return 64;
    }
    text project_source;
    status loaded = file.read_text(project_path, out project_source);
    if !loaded.ok {
        io.error("error: project context could not be read\n");
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
        io.error("error: project context JSON is invalid\n");
        return 1;
    }
    project_sort_modules(project_source, module_data, modules);
    text project_root = path.directory(project_path);
    text view_name = "context";
    if view == 1 { view_name = "sources"; }
    if view == 2 { view_name = "modules"; }
    if view == 3 { view_name = "limits"; }
    if view == 4 { view_name = "dependencies"; }
    if view == 5 { view_name = "target"; }
    if view == 6 { view_name = "types"; }

    DBuffer record = d_buffer_create(4194304);
    d_put(record, "{\n  \"schema\": \"openc.tool_context.v1\",\n");
    d_put(record, "  \"view\": ");
    cli_json_text(record, view_name);
    d_put(record, ",\n  ");
    cli_info_put_implementation(record);
    d_put(record, ",\n  \"canonical_source_extension\": \".p\",\n");
    d_put(record, "  \"project\": {\n    \"path\": ");
    cli_json_text(record, project_path);
    d_put(record, ",\n    \"root\": ");
    cli_json_text(record, project_root);
    d_put(record, ",\n    \"name\": ");
    cli_json_text(
        record, cli_json_string_or(project_source, "name", "")
    );
    d_put(record, ",\n    \"version\": ");
    cli_json_text(
        record, cli_json_string_or(project_source, "version", "")
    );
    d_put(record, ",\n    \"edition\": ");
    cli_json_text(
        record, cli_json_string_or(project_source, "edition", "OpenC 1.0")
    );
    d_put(record, ",\n    \"profile\": ");
    cli_json_text(
        record, cli_json_string_or(project_source, "profile", "standard")
    );
    d_put(record, ",\n    \"output_directory\": ");
    cli_json_text(
        record,
        cli_json_string_or(project_source, "output_directory", "")
    );
    d_put(record, "\n  },\n  ");

    if view == 1 {
        cli_info_put_sources(
            record, project_source, project_root,
            source_data, sources
        );
    } else if view == 2 {
        cli_info_put_modules(
            record, project_source, project_root,
            module_data, modules, source_data
        );
    } else if view == 3 {
        cli_info_put_limits(record);
    } else if view == 4 {
        d_put(record, "\"dependencies\": []");
    } else if view == 5 {
        cli_info_put_target(record);
    } else if view == 6 {
        cli_info_put_types(record);
    } else {
        cli_info_put_target(record);
        d_put(record, ",\n  ");
        cli_info_put_modules(
            record, project_source, project_root,
            module_data, modules, source_data
        );
        d_put(record, ",\n  \"dependencies\": [],\n  ");
        cli_info_put_limits(record);
        d_put(record, ",\n  \"build_context\": {\n");
        d_put(record, "    \"profile_origin\": \"project\",\n");
        d_put(record, "    \"target_origin\": \"project\",\n");
        d_put(record, "    \"command_line_overrides\": [],\n");
        d_put(record, "    \"environment_inputs_consulted\": [],\n");
        d_put(record, "    \"generated_source_inputs\": []\n");
        d_put(record, "  }");
    }
    d_put(record, "\n}\n");
    if !record.ok {
        d_buffer_destroy(record);
        io.error("error: project context record capacity exceeded\n");
        return 1;
    }
    if text.byte_length(output_path) != 0 {
        status written = file.write_text(
            output_path, d_buffer_text(record)
        );
        if !written.ok {
            d_buffer_destroy(record);
            io.error("error: project context record could not be written\n");
            return 1;
        }
    }
    if json_stdout {
        io.print(d_buffer_text(record));
    } else {
        io.println("OpenC project context");
        io.print("view: ");
        io.println(view_name);
        io.print("project: ");
        io.println(project_path);
        io.print("name: ");
        io.println(cli_json_string_or(project_source, "name", ""));
        io.print("target: ");
        io.println(cli_json_string_or(
            project_source, "target", "windows-x86_64-hosted"
        ));
        io.print("profile: ");
        io.println(cli_json_string_or(
            project_source, "profile", "standard"
        ));
        io.print("modules: ");
        io.println(modules.length);
        io.print("sources: ");
        io.println(sources.length);
        io.println("dependencies: 0");
    }
    d_buffer_destroy(record);
    return 0;
}

usize cli_json_number(text source, ref JsonState state) {
    project_json_skip_space(source, state);
    usize result = 0;
    usize start = state.cursor;
    while state.cursor < text.byte_length(source) {
        u8 value = byte_at_or_zero(source, state.cursor);
        if value < 48 || value > 57 { break; }
        result = result * 10 + cast(usize, value - 48);
        state.cursor = state.cursor + 1;
    }
    if state.cursor == start { state.failed = true; }
    return result;
}

unsafe void cli_test_record(
    ptr byte test_data,
    ref PackedBuffer tests,
    TextSpan name,
    TextSpan project_value,
    usize expected_exit
) {
    usize record = tests.length;
    write_record_field(test_data, record, 0, name.start);
    write_record_field(test_data, record, 1, name.length);
    write_record_field(test_data, record, 2, project_value.start);
    write_record_field(test_data, record, 3, project_value.length);
    write_record_field(test_data, record, 4, expected_exit);
    tests.length = tests.length + 1;
}

unsafe void cli_test_parse_object(
    text source,
    ref JsonState state,
    ptr byte test_data,
    ref PackedBuffer tests
) {
    if !project_json_take(source, state, 123) { return; }
    TextSpan name = TextSpan{ start = 0, length = 0 };
    TextSpan project_value = TextSpan{ start = 0, length = 0 };
    usize expected_exit = 0;
    project_json_skip_space(source, state);
    while !state.failed &&
        byte_at_or_zero(source, state.cursor) != 125 {
        TextSpan key = project_json_string(source, state);
        if !project_json_take(source, state, 58) { return; }
        if span_equals_ascii(
            source, key.start, key.length, "name"
        ) {
            name = project_json_string(source, state);
        } else if span_equals_ascii(
            source, key.start, key.length, "project"
        ) {
            project_value = project_json_string(source, state);
        } else if span_equals_ascii(
            source, key.start, key.length, "expected_exit"
        ) {
            expected_exit = cli_json_number(source, state);
        } else {
            project_json_skip_value(source, state);
        }
        if state.failed { return; }
        project_json_skip_space(source, state);
        if byte_at_or_zero(source, state.cursor) == 44 {
            state.cursor = state.cursor + 1;
        } else if byte_at_or_zero(source, state.cursor) != 125 {
            state.failed = true;
        }
        project_json_skip_space(source, state);
    }
    if !project_json_take(source, state, 125) { return; }
    if name.length == 0 || project_value.length == 0 {
        state.failed = true;
        return;
    }
    cli_test_record(
        test_data, tests, name, project_value, expected_exit
    );
}

unsafe void cli_test_parse_array(
    text source,
    ref JsonState state,
    ptr byte test_data,
    ref PackedBuffer tests
) {
    if !project_json_take(source, state, 91) { return; }
    project_json_skip_space(source, state);
    while !state.failed &&
        byte_at_or_zero(source, state.cursor) != 93 {
        cli_test_parse_object(source, state, test_data, tests);
        if state.failed { return; }
        project_json_skip_space(source, state);
        if byte_at_or_zero(source, state.cursor) == 44 {
            state.cursor = state.cursor + 1;
        } else if byte_at_or_zero(source, state.cursor) != 93 {
            state.failed = true;
        }
        project_json_skip_space(source, state);
    }
    project_json_take(source, state, 93);
}

unsafe bool cli_test_parse_manifest(
    text source,
    ptr byte test_data,
    ref PackedBuffer tests
) {
    JsonState state = JsonState{ cursor = 0, failed = false };
    if !project_json_take(source, state, 123) { return false; }
    project_json_skip_space(source, state);
    while !state.failed &&
        byte_at_or_zero(source, state.cursor) != 125 {
        TextSpan key = project_json_string(source, state);
        if !project_json_take(source, state, 58) { return false; }
        if span_equals_ascii(
            source, key.start, key.length, "tests"
        ) {
            cli_test_parse_array(source, state, test_data, tests);
        } else {
            project_json_skip_value(source, state);
        }
        if state.failed { return false; }
        project_json_skip_space(source, state);
        if byte_at_or_zero(source, state.cursor) == 44 {
            state.cursor = state.cursor + 1;
        } else if byte_at_or_zero(source, state.cursor) != 125 {
            return false;
        }
        project_json_skip_space(source, state);
    }
    if !project_json_take(source, state, 125) { return false; }
    project_json_skip_space(source, state);
    return !state.failed &&
        state.cursor == text.byte_length(source) &&
        tests.length != 0;
}

unsafe NativeRunResult cli_run_project_action(
    text action,
    text project_path
) {
    text compiler = path.join(
        process.executable_directory(), "openc.exe"
    );
    DBuffer command = d_buffer_create(
        text.byte_length(compiler) + text.byte_length(action) +
        text.byte_length(project_path) + 64
    );
    native_put_quoted(command, compiler);
    d_put(command, " ");
    d_put(command, action);
    d_put(command, " \"--project=");
    d_put(command, project_path);
    d_put(command, "\" 2>&1");
    i32 exit_code;
    text output;
    status ran = process.run(
        d_buffer_text(command), out exit_code, out output
    );
    d_buffer_destroy(command);
    if !ran.ok {
        return NativeRunResult{
            launched = false, exit_code = 0, output = ""
        };
    }
    return NativeRunResult{
        launched = true, exit_code = exit_code, output = output
    };
}

unsafe CliTestOutcome cli_test_execute(
    text project_path,
    usize expected_exit,
    bool no_run,
    usize execution_index
) {
    usize source_hash = cli_project_source_hash(project_path);
    if source_hash == 0 {
        return CliTestOutcome{
            kind = 3, exit_code = 0, source_hash = 0,
            output = "",
            diagnostics = "project or source hashing failed"
        };
    }
    NativeRunResult checked = cli_run_project_action(
        "check", project_path
    );
    if !checked.launched {
        return CliTestOutcome{
            kind = 3, exit_code = 0, source_hash = source_hash,
            output = "",
            diagnostics = "native check could not be launched"
        };
    }
    if checked.exit_code != 0 {
        return CliTestOutcome{
            kind = 1, exit_code = checked.exit_code,
            source_hash = source_hash,
            output = "", diagnostics = checked.output
        };
    }
    if no_run {
        return CliTestOutcome{
            kind = 0, exit_code = 0, source_hash = source_hash,
            output = "", diagnostics = ""
        };
    }

    DBuffer executable_name = d_buffer_create(64);
    d_put(executable_name, "openc-test-");
    d_put_usize(executable_name, execution_index);
    d_put(executable_name, ".exe");
    text executable = path.join(
        process.executable_directory(),
        d_buffer_text(executable_name)
    );
    NativeRunResult built = native_run_build(
        path.join(process.executable_directory(), "openc.exe"),
        project_path,
        executable
    );
    if !built.launched || built.exit_code != 0 {
        d_buffer_destroy(executable_name);
        return CliTestOutcome{
            kind = 3,
            exit_code = built.exit_code,
            source_hash = source_hash,
            output = "",
            diagnostics = built.output
        };
    }
    NativeRunResult executed = native_run_program(executable);
    d_buffer_destroy(executable_name);
    if !executed.launched {
        return CliTestOutcome{
            kind = 3, exit_code = 0, source_hash = source_hash,
            output = "",
            diagnostics = "built test could not be launched"
        };
    }
    if executed.exit_code != cast(i32, expected_exit) {
        return CliTestOutcome{
            kind = 2, exit_code = executed.exit_code,
            source_hash = source_hash,
            output = executed.output,
            diagnostics = "runtime exit assertion failed"
        };
    }
    return CliTestOutcome{
        kind = 0, exit_code = executed.exit_code,
        source_hash = source_hash,
        output = executed.output, diagnostics = ""
    };
}

text cli_test_kind_name(usize kind) {
    if kind == 0 { return "PASS"; }
    if kind == 1 { return "LANGUAGE_FAILURE"; }
    if kind == 2 { return "ASSERTION_FAILURE"; }
    return "INFRASTRUCTURE_FAILURE";
}

unsafe void cli_test_report_header(
    ref DBuffer report,
    text manifest_path,
    bool no_run,
    bool list_only,
    usize jobs,
    text target
) {
    d_put(report, "{\n  \"schema\": \"openc.test_result.v1\",\n");
    d_put(report, "  \"implementation\": {\n");
    d_put(report, "    \"name\": \"OpenC\",\n");
    d_put(report, "    \"version\": ");
    cli_json_text(report, cli_version());
    d_put(report, ",\n    \"language\": \"OpenC\"\n  },\n");
    d_put(report, "  \"target\": ");
    cli_json_text(report, target);
    d_put(report, ",\n  \"manifest\": ");
    cli_json_text(report, manifest_path);
    d_put(report, ",\n  \"command\": \"openc test\",\n");
    d_put(report, "  \"mode\": \"");
    if list_only { d_put(report, "list"); }
    else if no_run { d_put(report, "no-run"); }
    else { d_put(report, "run"); }
    d_put(report, "\",\n  \"requested_jobs\": ");
    d_put_usize(report, jobs);
    d_put(report, ",\n  \"execution_order\": \"name-sorted\",\n");
    d_put(report, "  \"results\": [\n");
}

unsafe void cli_test_report_case(
    ref DBuffer report,
    bool first,
    text name,
    text project_path,
    usize expected_exit,
    bool list_only,
    ref CliTestOutcome outcome
) {
    if !first { d_put(report, ",\n"); }
    d_put(report, "    {\n      \"name\": ");
    cli_json_text(report, name);
    d_put(report, ",\n      \"project\": ");
    cli_json_text(report, project_path);
    d_put(report, ",\n      \"expected_exit\": ");
    d_put_usize(report, expected_exit);
    if list_only {
        d_put(report, ",\n      \"status\": \"DISCOVERED\"");
    } else {
        d_put(report, ",\n      \"status\": ");
        cli_json_text(report, cli_test_kind_name(outcome.kind));
        d_put(report, ",\n      \"source_hash\": {\n");
        d_put(report, "        \"algorithm\": \"openc-stable32\",\n");
        d_put(report, "        \"value\": \"");
        cli_put_hex_usize(report, outcome.source_hash);
        d_put(report, "\"\n      },\n");
        d_put(report, "      \"exit_code\": ");
        d_put_usize(report, cast(usize, outcome.exit_code));
        d_put(report, ",\n      \"stdout\": ");
        cli_json_text(report, outcome.output);
        d_put(report, ",\n      \"diagnostics\": ");
        cli_json_text(report, outcome.diagnostics);
    }
    d_put(report, "\n    }");
}

unsafe i32 cli_test_finish_report(
    ref DBuffer report,
    text report_path,
    usize selected,
    usize passed,
    usize language_failures,
    usize assertion_failures,
    usize infrastructure_failures,
    bool list_only
) {
    d_put(report, "\n  ],\n  \"summary\": {\n");
    d_put(report, "    \"selected\": ");
    d_put_usize(report, selected);
    d_put(report, ",\n    \"passed\": ");
    d_put_usize(report, passed);
    d_put(report, ",\n    \"language_failures\": ");
    d_put_usize(report, language_failures);
    d_put(report, ",\n    \"assertion_failures\": ");
    d_put_usize(report, assertion_failures);
    d_put(report, ",\n    \"infrastructure_failures\": ");
    d_put_usize(report, infrastructure_failures);
    d_put(report, "\n  },\n  \"status\": \"");
    if selected == 0 { d_put(report, "NO_TESTS"); }
    else if list_only || (
        language_failures == 0 &&
        assertion_failures == 0 &&
        infrastructure_failures == 0
    ) {
        d_put(report, "PASS");
    } else {
        d_put(report, "FAIL");
    }
    d_put(report, "\"\n}\n");
    if !report.ok {
        io.error("error: test report capacity exceeded\n");
        return 1;
    }
    if text.byte_length(report_path) != 0 {
        status written = file.write_text(
            report_path, d_buffer_text(report)
        );
        if !written.ok {
            io.error("error: test report could not be written\n");
            return 1;
        }
    }
    if selected == 0 {
        io.println("OpenC test: NO_TESTS");
        return 1;
    }
    if list_only {
        io.print("OpenC test: ");
        io.print(selected);
        io.println(" test(s) discovered");
        return 0;
    }
    io.print("OpenC test: ");
    io.print(passed);
    io.print("/");
    io.print(selected);
    io.println(" passed");
    if language_failures != 0 ||
        assertion_failures != 0 ||
        infrastructure_failures != 0 {
        return 1;
    }
    return 0;
}

unsafe i32 cli_test_direct(
    text project_path,
    text report_path,
    text filter,
    bool list_only,
    bool no_run,
    usize jobs,
    text target
) {
    text name = project_path;
    DBuffer report = d_buffer_create(4194304);
    cli_test_report_header(
        report, "", no_run, list_only, jobs, target
    );
    usize selected = 0;
    usize passed = 0;
    usize language_failures = 0;
    usize assertion_failures = 0;
    usize infrastructure_failures = 0;
    if text.byte_length(filter) == 0 || native_contains(name, filter) {
        selected = 1;
        if list_only {
            io.println(name);
            CliTestOutcome listed = CliTestOutcome{
                kind = 0, exit_code = 0, source_hash = 0,
                output = "", diagnostics = ""
            };
            cli_test_report_case(
                report, true, name, project_path, 0, true, listed
            );
        } else {
            CliTestOutcome outcome = cli_test_execute(
                project_path, 0, no_run, 0
            );
            io.print("test ");
            io.print(name);
            io.print(": ");
            io.println(cli_test_kind_name(outcome.kind));
            if outcome.kind == 0 { passed = 1; }
            if outcome.kind == 1 { language_failures = 1; }
            if outcome.kind == 2 { assertion_failures = 1; }
            if outcome.kind == 3 { infrastructure_failures = 1; }
            cli_test_report_case(
                report, true, name, project_path, 0, false, outcome
            );
        }
    }
    i32 result = cli_test_finish_report(
        report, report_path, selected, passed,
        language_failures, assertion_failures,
        infrastructure_failures, list_only
    );
    d_buffer_destroy(report);
    return result;
}

unsafe i32 cli_test_manifest(
    text manifest_path,
    text report_path,
    text filter,
    bool list_only,
    bool no_run,
    usize jobs,
    text target
) {
    text manifest;
    status loaded = file.read_text(manifest_path, out manifest);
    if !loaded.ok {
        io.error("error: test manifest could not be read\n");
        return 1;
    }
    PackedBuffer tests = PackedBuffer{
        length = 0,
        capacity = text.byte_length(manifest) + 1
    };
    ptr byte test_data = memory.alloc(
        tests.capacity * record_stride()
    );
    scope memory.free(test_data);
    if !cli_test_parse_manifest(manifest, test_data, tests) {
        io.error("error: test manifest is invalid or empty\n");
        return 1;
    }
    project_sort_modules(manifest, test_data, tests);
    text manifest_root = path.directory(manifest_path);
    DBuffer report = d_buffer_create(4194304);
    cli_test_report_header(
        report, manifest_path, no_run, list_only, jobs, target
    );
    usize selected = 0;
    usize passed = 0;
    usize language_failures = 0;
    usize assertion_failures = 0;
    usize infrastructure_failures = 0;
    usize test_record = 0;
    while test_record < tests.length {
        text name = project_slice(
            manifest,
            read_record_field(test_data, test_record, 0),
            read_record_field(test_data, test_record, 1)
        );
        if text.byte_length(filter) != 0 &&
            !native_contains(name, filter) {
            test_record = test_record + 1;
            continue;
        }
        text relative_project = project_slice(
            manifest,
            read_record_field(test_data, test_record, 2),
            read_record_field(test_data, test_record, 3)
        );
        text project_path = path.join(
            manifest_root, relative_project
        );
        usize expected_exit = read_record_field(
            test_data, test_record, 4
        );
        if list_only {
            io.println(name);
            CliTestOutcome listed = CliTestOutcome{
                kind = 0, exit_code = 0, source_hash = 0,
                output = "", diagnostics = ""
            };
            cli_test_report_case(
                report, selected == 0, name, project_path,
                expected_exit, true, listed
            );
        } else {
            CliTestOutcome outcome = cli_test_execute(
                project_path, expected_exit, no_run, selected
            );
            io.print("test ");
            io.print(name);
            io.print(": ");
            io.println(cli_test_kind_name(outcome.kind));
            if outcome.kind == 0 { passed = passed + 1; }
            if outcome.kind == 1 {
                language_failures = language_failures + 1;
            }
            if outcome.kind == 2 {
                assertion_failures = assertion_failures + 1;
            }
            if outcome.kind == 3 {
                infrastructure_failures =
                    infrastructure_failures + 1;
            }
            cli_test_report_case(
                report, selected == 0, name, project_path,
                expected_exit, false, outcome
            );
        }
        selected = selected + 1;
        test_record = test_record + 1;
    }
    i32 result = cli_test_finish_report(
        report, report_path, selected, passed,
        language_failures, assertion_failures,
        infrastructure_failures, list_only
    );
    d_buffer_destroy(report);
    return result;
}

unsafe i32 cli_test_command() {
    text manifest_path = "";
    text project_path = "";
    text report_path = "";
    text filter = "";
    text target = "windows-x86_64-hosted";
    bool list_only = false;
    bool no_run = false;
    usize jobs = 1;
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--manifest=") {
            manifest_path = cli_remove_prefix(value, "--manifest=");
        } else if cli_has_prefix(value, "--project=") {
            project_path = cli_remove_prefix(value, "--project=");
        } else if cli_has_prefix(value, "--report=") {
            report_path = cli_remove_prefix(value, "--report=");
        } else if cli_has_prefix(value, "--filter=") {
            filter = cli_remove_prefix(value, "--filter=");
        } else if cli_has_prefix(value, "--jobs=") {
            jobs = native_parse_usize(
                cli_remove_prefix(value, "--jobs=")
            );
        } else if cli_has_prefix(value, "--target=") {
            target = cli_remove_prefix(value, "--target=");
        } else if value == "--list" {
            list_only = true;
        } else if value == "--no-run" {
            no_run = true;
        } else {
            io.error("usage: openc test (--manifest=TESTS.json|--project=PROJECT) [--list] [--filter=TEXT] [--jobs=N] [--target=TARGET] [--report=RESULT.json] [--no-run]\n");
            return 64;
        }
        argument = argument + 1;
    }
    if jobs == 0 ||
        target != "windows-x86_64-hosted" ||
        (text.byte_length(manifest_path) == 0 &&
            text.byte_length(project_path) == 0) ||
        (text.byte_length(manifest_path) != 0 &&
            text.byte_length(project_path) != 0) {
        io.error("usage: openc test (--manifest=TESTS.json|--project=PROJECT) [--list] [--filter=TEXT] [--jobs=N] [--target=windows-x86_64-hosted] [--report=RESULT.json] [--no-run]\n");
        return 64;
    }
    if text.byte_length(project_path) != 0 {
        return cli_test_direct(
            project_path, report_path, filter, list_only,
            no_run, jobs, target
        );
    }
    return cli_test_manifest(
        manifest_path, report_path, filter, list_only,
        no_run, jobs, target
    );
}
