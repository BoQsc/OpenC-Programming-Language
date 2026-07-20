import system.io;
void show(i32 value) { io.print(value); }
i32 main() {
    i32 value = 1;
    scope show(value);
    value = 2;
    return 0;
}
