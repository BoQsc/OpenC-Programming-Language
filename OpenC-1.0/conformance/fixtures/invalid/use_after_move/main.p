resource Buffer { usize length; }
i32 main() {
    Buffer a = buffer_create(10);
    Buffer b = buffer_move(a);
    return a.length;
}
