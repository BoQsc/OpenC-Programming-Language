resource Resource {
    usize id = 0;
}

Resource make_resource();
void consume_resource(own Resource value);

i32 main() {
    Resource value = make_resource();
    value = make_resource();
    consume_resource(value);
    return 0;
}
