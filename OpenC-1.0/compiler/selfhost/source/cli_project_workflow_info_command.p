import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
