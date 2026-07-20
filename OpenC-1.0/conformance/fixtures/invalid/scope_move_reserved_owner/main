resource Buffer { i32 value; }
Buffer buffer_create(i32 value);
Buffer buffer_move(own Buffer value);
void buffer_destroy(own Buffer value);
i32 main() {
    Buffer buffer = buffer_create(1);
    scope buffer_destroy(buffer);
    Buffer other = buffer_move(buffer);
    return 0;
}
