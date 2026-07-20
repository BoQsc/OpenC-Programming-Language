import system.text;

i32 main() {
    text value = text.trim(" hello ");
    if value == "hello" { return 0; }
    return 1;
}
