resource Allocation {
    usize id = 0;
}

resource Buffer {
    Allocation allocation;
    usize length = 0;
}

resource Token {
    usize id = 0;
}

Allocation allocate(usize size);
void buffer_destroy(own Buffer buffer);
void token_destroy(own Token token) {
}

usize buffer_length(ref const Buffer buffer) {
    return buffer.length;
}

i32 main() {
    Allocation allocation = allocate(8);
    Buffer buffer = Buffer{
        length = 8,
        own allocation = allocation
    };
    usize observed = buffer_length(buffer);
    buffer_destroy(buffer);

    Token token = Token{};
    token_destroy(token);
    return cast(i32, observed);
}
