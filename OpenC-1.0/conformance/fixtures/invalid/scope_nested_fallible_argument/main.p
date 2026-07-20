resource Handle { i32 raw; }
status open(out Handle handle);
void close(own Handle handle);
i32 main() {
    Handle handle;
    scope close(open(out handle));
    return 0;
}
