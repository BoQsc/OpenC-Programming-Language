i32 zero() { return 7; }

i32 add(i32 left, i32 right) { return left + right; }

i32 main() {
    return add(zero(), 5) - 12;
}
