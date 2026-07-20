import system.io;
void done() { io.print("cleanup"); }
i32 read(i32[] values, usize index) {
    scope done();
    return values[index];
}
i32 main() {
    i32[1] values = {1};
    return read(values, 2);
}
