struct Pair { i32 a; i32 b; }
i32 main() {
    Pair pair = Pair{ a = 1, b = 2 };
    unsafe { u64 bits = reinterpret(u64, pair); return cast(i32, bits); }
}
