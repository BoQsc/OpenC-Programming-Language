import system.io;

export void print_summary(
    usize lines, usize digits, usize warnings, usize fingerprint
) {
    io.print("lines="); io.println(lines);
    io.print("digits="); io.println(digits);
    io.print("warnings="); io.println(warnings);
    io.print("fingerprint="); io.println(fingerprint);
}
