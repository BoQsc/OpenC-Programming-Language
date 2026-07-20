status allocate(out ptr byte data) {
    data = memory.alloc(8);
    return status{ ok = true, code = 0, message = "" };
}
