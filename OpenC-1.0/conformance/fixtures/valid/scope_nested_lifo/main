import system.io;
void show(text value) { io.print(value); }
i32 main() {
    scope show("outer");
    {
        scope show("inner-first");
        scope show("inner-last");
    }
    return 0;
}
