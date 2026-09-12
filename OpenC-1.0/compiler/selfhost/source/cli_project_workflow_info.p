import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

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
    d_put(record, "    \"backend\": \"openc-x64-pe32\",\n");
    d_put(record, "    \"hash_algorithm\": \"openc-stable32\",\n");
    d_put(record, "    \"hash\": \"");
    cli_put_hex_usize(
        record,
        cli_hash_text(
            cli_hash_initial(),
            "windows-x86_64-hosted|64|little|openc-x64-pe32"
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
