import system.file;
import system.io;
import system.memory;
import system.path;
import system.process;
import system.text;

struct CliAuditCounts {
    usize files;
    usize files_passed;
    usize hashes;
    usize hashes_passed;
    usize fixtures;
    usize fixtures_passed;
    usize rules;
    usize rules_passed;
    usize productions;
    usize productions_passed;
}

unsafe bool cli_audit_nonempty(text root, text relative) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(
        path.join(root, relative), out data, out length
    );
    if !loaded.ok { return false; }
    bool passed = length != 0;
    memory.free(data);
    return passed;
}

unsafe bool cli_audit_hash(
    text root,
    text relative,
    usize expected_bytes,
    text expected_hash
) {
    ptr byte data;
    usize length;
    status loaded = file.read_bytes_raw(
        path.join(root, relative), out data, out length
    );
    if !loaded.ok { return false; }
    DBuffer actual = d_buffer_create(65);
    winmd_sha256_hex(data, length, actual);
    memory.free(data);
    bool passed = length == expected_bytes && actual.ok &&
        d_buffer_text(actual) == expected_hash;
    d_buffer_destroy(actual);
    return passed;
}

unsafe bool cli_audit_contains_pair(
    text root,
    text left_relative,
    text right_relative,
    text expected
) {
    text left;
    status left_loaded = file.read_text_cached(
        path.join(root, left_relative), out left
    );
    if !left_loaded.ok { return false; }
    text right;
    status right_loaded = file.read_text_cached(
        path.join(root, right_relative), out right
    );
    return right_loaded.ok && native_contains(left, expected) &&
        native_contains(right, expected);
}

unsafe bool cli_audit_plan_record(
    text root,
    text line,
    ref CliAuditCounts counts
) {
    NativeCursor cursor = NativeCursor{ value = 0 };
    TextSpan kind_span = native_next_field(line, cursor);
    TextSpan first_span = native_next_field(line, cursor);
    text kind = project_slice(line, kind_span.start, kind_span.length);
    text first = project_slice(line, first_span.start, first_span.length);
    if kind == "file" {
        counts.files = counts.files + 1;
        bool passed = cli_audit_nonempty(root, first);
        if passed { counts.files_passed = counts.files_passed + 1; }
        return passed;
    }
    if kind == "hash" {
        TextSpan bytes_span = native_next_field(line, cursor);
        TextSpan hash_span = native_next_field(line, cursor);
        usize expected_bytes = native_parse_usize(project_slice(
            line, bytes_span.start, bytes_span.length
        ));
        text expected_hash = project_slice(
            line, hash_span.start, hash_span.length
        );
        counts.hashes = counts.hashes + 1;
        bool passed = expected_bytes != 0 &&
            text.byte_length(expected_hash) == 64 &&
            cli_audit_hash(root, first, expected_bytes, expected_hash);
        if passed { counts.hashes_passed = counts.hashes_passed + 1; }
        return passed;
    }
    if kind == "fixture" || kind == "rule" || kind == "production" {
        TextSpan right_span = native_next_field(line, cursor);
        TextSpan expected_span = native_next_field(line, cursor);
        text right = project_slice(
            line, right_span.start, right_span.length
        );
        text expected = project_slice(
            line, expected_span.start, expected_span.length
        );
        bool passed = text.byte_length(first) != 0 &&
            text.byte_length(right) != 0 &&
            text.byte_length(expected) != 0 &&
            cli_audit_contains_pair(root, first, right, expected);
        if kind == "fixture" {
            counts.fixtures = counts.fixtures + 1;
            if passed {
                counts.fixtures_passed = counts.fixtures_passed + 1;
            }
        } else if kind == "rule" {
            counts.rules = counts.rules + 1;
            if passed { counts.rules_passed = counts.rules_passed + 1; }
        } else {
            counts.productions = counts.productions + 1;
            if passed {
                counts.productions_passed =
                    counts.productions_passed + 1;
            }
        }
        return passed;
    }
    return false;
}

unsafe bool cli_audit_plan(
    text root,
    text plan,
    ref CliAuditCounts counts
) {
    NativeCursor cursor = NativeCursor{ value = 0 };
    TextSpan header_span = native_next_line(plan, cursor);
    text header = project_slice(
        plan, header_span.start, header_span.length
    );
    NativeCursor header_cursor = NativeCursor{ value = 0 };
    TextSpan schema_span = native_next_field(header, header_cursor);
    TextSpan version_span = native_next_field(header, header_cursor);
    TextSpan file_count_span = native_next_field(header, header_cursor);
    TextSpan hash_count_span = native_next_field(header, header_cursor);
    TextSpan fixture_count_span = native_next_field(header, header_cursor);
    TextSpan rule_count_span = native_next_field(header, header_cursor);
    TextSpan production_count_span = native_next_field(
        header, header_cursor
    );
    bool header_ok = span_equals_ascii(
        header, schema_span.start, schema_span.length,
        "openc.native_repository_audit_plan.v1"
    ) && span_equals_ascii(
        header, version_span.start, version_span.length, "1"
    );
    usize expected_files = native_parse_usize(project_slice(
        header, file_count_span.start, file_count_span.length
    ));
    usize expected_hashes = native_parse_usize(project_slice(
        header, hash_count_span.start, hash_count_span.length
    ));
    usize expected_fixtures = native_parse_usize(project_slice(
        header, fixture_count_span.start, fixture_count_span.length
    ));
    usize expected_rules = native_parse_usize(project_slice(
        header, rule_count_span.start, rule_count_span.length
    ));
    usize expected_productions = native_parse_usize(project_slice(
        header, production_count_span.start, production_count_span.length
    ));

    bool records_ok = true;
    while cursor.value < text.byte_length(plan) {
        TextSpan line_span = native_next_line(plan, cursor);
        text line = project_slice(
            plan, line_span.start, line_span.length
        );
        if text.byte_length(line) != 0 &&
            !cli_audit_plan_record(root, line, counts) {
            records_ok = false;
        }
    }
    return header_ok && records_ok &&
        expected_files == 364 && counts.files == expected_files &&
        counts.files_passed == counts.files &&
        expected_hashes == 39 && counts.hashes == expected_hashes &&
        counts.hashes_passed == counts.hashes &&
        expected_fixtures == 278 && counts.fixtures == expected_fixtures &&
        counts.fixtures_passed == counts.fixtures &&
        expected_rules == 466 && counts.rules == expected_rules &&
        counts.rules_passed == counts.rules &&
        expected_productions == 174 &&
        counts.productions == expected_productions &&
        counts.productions_passed == counts.productions;
}

unsafe bool cli_audit_write_report(
    text output_path,
    text root,
    ref CliAuditCounts counts,
    bool passed
) {
    DBuffer report = d_buffer_create(4096);
    d_put(report, "{\n  \"schema\": \"openc.native_repository_audit.v1\",\n");
    d_put(report, "  \"implementation_language\": \"OpenC\",\n");
    d_put(report, "  \"root\": ");
    cli_json_text(report, root);
    d_put(report, ",\n  \"checks\": {\n    \"required_files\": ");
    d_put_usize(report, counts.files);
    d_put(report, ",\n    \"required_files_passed\": ");
    d_put_usize(report, counts.files_passed);
    d_put(report, ",\n    \"pinned_hashes\": ");
    d_put_usize(report, counts.hashes);
    d_put(report, ",\n    \"pinned_hashes_passed\": ");
    d_put_usize(report, counts.hashes_passed);
    d_put(report, ",\n    \"fixture_identities\": ");
    d_put_usize(report, counts.fixtures);
    d_put(report, ",\n    \"fixture_identities_passed\": ");
    d_put_usize(report, counts.fixtures_passed);
    d_put(report, ",\n    \"active_rules\": ");
    d_put_usize(report, counts.rules);
    d_put(report, ",\n    \"covered_rules\": ");
    d_put_usize(report, counts.rules_passed);
    d_put(report, ",\n    \"grammar_productions\": ");
    d_put_usize(report, counts.productions);
    d_put(report, ",\n    \"covered_productions\": ");
    d_put_usize(report, counts.productions_passed);
    d_put(report, "\n  },\n  \"status\": \"");
    if passed { d_put(report, "PASS"); } else { d_put(report, "FAIL"); }
    d_put(report, "\"\n}\n");
    bool report_ok = report.ok;
    status written = file.write_text(output_path, d_buffer_text(report));
    d_buffer_destroy(report);
    return report_ok && written.ok;
}

unsafe i32 cli_repository_audit_command() {
    text root = process.executable_directory();
    text output_path = "";
    usize argument = 1;
    while argument < process.argument_count() {
        text value = process.argument(argument);
        if cli_has_prefix(value, "--root=") {
            root = cli_remove_prefix(value, "--root=");
        } else if cli_has_prefix(value, "--output=") {
            output_path = cli_remove_prefix(value, "--output=");
        } else {
            io.error("usage: openc audit --root=ROOT --output=REPORT.json\n");
            return 64;
        }
        argument = argument + 1;
    }
    if text.byte_length(output_path) == 0 {
        io.error("usage: openc audit --root=ROOT --output=REPORT.json\n");
        return 64;
    }
    text plan;
    status loaded = file.read_text(path.join(
        root, "tests/SH21_NATIVE_REPOSITORY_AUDIT_PLAN.tsv"
    ), out plan);
    CliAuditCounts counts = CliAuditCounts{
        files = 0,
        files_passed = 0,
        hashes = 0,
        hashes_passed = 0,
        fixtures = 0,
        fixtures_passed = 0,
        rules = 0,
        rules_passed = 0,
        productions = 0,
        productions_passed = 0
    };
    bool passed = false;
    if loaded.ok {
        passed = cli_audit_plan(root, plan, counts);
    }
    if !cli_audit_write_report(output_path, root, counts, passed) {
        io.error("error: repository audit report could not be written\n");
        return 1;
    }
    io.print("OpenC repository audit: ");
    if passed { io.println("PASS"); }
    else { io.println("FAIL"); }
    if passed { return 0; }
    return 1;
}
