import audit.report;
import audit.scan;
import audit.score;
import system.file;

i32 main() {
    text input;
    status loaded = file.read_text("sample.log", out input);
    if !loaded.ok { return 2; }

    usize lines = scan.count_lines(input);
    usize digits = scan.count_digits(input);
    usize warnings = scan.count_warnings(input);
    usize fingerprint = score.fingerprint(input);
    report.print_summary(lines, digits, warnings, fingerprint);
    return 0;
}
