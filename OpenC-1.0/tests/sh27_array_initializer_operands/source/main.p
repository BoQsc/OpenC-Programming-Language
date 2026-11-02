import system.io;

i32 mark(i32 value) {
    io.print(value);
    return value;
}

i32 add(i32 left, i32 right) { return left + right; }
i32 negative() { return -123; }
u8 byte_value() { return 255; }
f32 float_value() { return cast(f32, 1.5); }

struct Pair { usize length; usize capacity; }

unsafe i32 copy_references(ref Pair left, ref Pair right) {
    Pair[2] values = {left, right};
    Pair first = values[0];
    Pair second = values[1];
    if first.length != 11 || first.capacity != 22 { return 21; }
    if second.length != 33 || second.capacity != 44 { return 22; }
    return 0;
}

unsafe i32 main() {
    i32[3] values = {mark(1), mark(12), mark(123)};
    io.println("");
    if values[0] != 1 { return 2; }
    if values[1] != 12 { return 3; }
    if values[2] != 123 { return 4; }
    i32[3] mixed = {add(4, 5), values[0] + values[1], add(add(1, 2), 3)};
    if mixed[0] != 9 { return 5; }
    if mixed[1] != 13 { return 6; }
    if mixed[2] != 6 { return 7; }
    i32[2] grouped = {(add(1, 2)), (add(3, 4) + 5),};
    if grouped[0] != 3 || grouped[1] != 12 { return 11; }
    text[2] words = {"a,b", "c}d"};
    if words[0] != "a,b" || words[1] != "c}d" { return 12; }
    i64[2] widened = {negative(), -1};
    if widened[0] != -123 || widened[1] != -1 { return 8; }
    u8[3] bytes = {byte_value(), 1, 2};
    if bytes[0] != 255 || bytes[1] != 1 || bytes[2] != 2 { return 9; }
    f64[2] floats = {float_value(), 2.5};
    if floats[0] != 1.5 || floats[1] != 2.5 { return 10; }
    Pair left = Pair{ length = 11, capacity = 22 };
    Pair right = Pair{ length = 33, capacity = 44 };
    i32 copied = copy_references(left, right);
    if copied != 0 { return copied; }
    Pair[2] created = {Pair{ length = 5, capacity = 6 },
        Pair{ length = 7, capacity = 8 }};
    Pair last = created[1];
    if last.length != 7 || last.capacity != 8 { return 13; }
    return 0;
}
