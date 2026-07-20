resource Buffer { i32 value; }
Buffer buffer_create(i32 value);
void buffer_destroy(own Buffer value);
i32 main() {
    Buffer buffer = buffer_create(1);
    scope buffer_destroy(buffer);
    scope buffer_destroy(buffer);
    return 0;
}
