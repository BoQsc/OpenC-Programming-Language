resource Buffer { usize length; }
i32 main() {
    Buffer a = buffer_create(10);
    Buffer b = a;
    return 0;
}
