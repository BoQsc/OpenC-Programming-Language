import system.io;

struct Pair { i32 value; i32 spare; }

i32 select_value(i32 value) {
    i32 total = value;
    if value > 0 {
        i32 inner = value + 1;
        if inner > value {
            i32 deepest = inner + 2;
            total = deepest;
        }
    }
    if value < 0 {
        i32 sibling = value - 1;
        total = sibling;
    }
    i32 after = total + 4;
    return after;
}

i64 sum_eight(i64 a, i64 b, i64 c, i64 d, i64 e, i64 f, i64 g, i64 h) {
    return a + b + c + d + e + f + g + h;
}

unsafe i32 pair_value(ref Pair value, i32 extra) {
    return value.value + extra;
}

unsafe i32 main() {
    if select_value(3) != 10 { return 1; }
    if select_value(-3) != 0 { return 2; }
    if other_value(3) != 21 { return 3; }
    if sum_eight(1, 2, 3, 4, 5, 6, 7, 8) != 36 { return 4; }
    Pair value = Pair{ value = 25, spare = 0 };
    if pair_value(value, 7) != 32 { return 5; }
    i32 total = 0;
    for i32 index = 0; index < 3; index = index + 1 {
        i32 iteration = index + 1;
        total = total + iteration;
    }
    if total != 6 { return 6; }
    io.println("indexed-bindings-ok");
    return 0;
}
