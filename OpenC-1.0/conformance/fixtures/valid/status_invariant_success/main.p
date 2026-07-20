status ready() {
    return status{ code = 0, message = "ready" };
}

i32 main() {
    status result = ready();
    if !result.ok { return result.code; }
    return 0;
}
