struct Pair {
    usize length;
    usize capacity;
}

struct NestedState {
    usize prefix;
    Pair modules;
    usize middle;
    Pair symbols;
    usize suffix;
}

struct SimpleState {
    usize prefix;
    usize middle;
}

struct ScalarState {
    usize value;
}

unsafe i32 verify_scalar(ref usize value) {
    ScalarState state = ScalarState{ value = value };
    if state.value != 577 { return 31; }
    return 0;
}

i32 simple() {
    SimpleState state = SimpleState{ prefix = 11, middle = 22 };
    if state.prefix != 11 { return 21; }
    if state.middle != 22 { return 22; }
    return 0;
}

unsafe i32 verify(ref Pair modules, ref Pair symbols) {
    if modules.length != 1282 { return 41; }
    if modules.capacity != 2048 { return 42; }
    if symbols.length != 735 { return 43; }
    if symbols.capacity != 1024 { return 44; }
    NestedState state = NestedState{
        prefix = 11,
        modules = modules,
        middle = 22,
        symbols = symbols,
        suffix = 33
    };
    if state.prefix != 11 { return 1; }
    if state.middle != 22 { return 2; }
    if state.suffix != 33 { return 3; }
    if state.modules.length != 1282 { return 4; }
    if state.modules.capacity != 2048 { return 5; }
    if state.symbols.length != 735 { return 6; }
    if state.symbols.capacity != 1024 { return 7; }
    return 0;
}

unsafe i32 main() {
    i32 simple_result = simple();
    if simple_result != 0 { return simple_result; }
    usize scalar = 577;
    i32 scalar_result = verify_scalar(scalar);
    if scalar_result != 0 { return scalar_result; }
    Pair modules = Pair{ length = 1282, capacity = 2048 };
    Pair symbols = Pair{ length = 735, capacity = 1024 };
    return verify(modules, symbols);
}
