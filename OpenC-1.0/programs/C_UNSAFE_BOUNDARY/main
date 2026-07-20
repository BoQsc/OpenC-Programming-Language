struct Pair {
    i32 left;
    i32 right;
}

i32 read_left(ref const Pair pair) {
    return pair.left;
}

i32 main() {
    storage Pair slot;
    ref Pair pair = construct(slot, Pair{ left = 10, right = 20 });
    scope destroy(pair);

    unsafe {
        ptr i32 left = &pair.left;
        *left = 30;
    }

    return read_left(pair);
}
