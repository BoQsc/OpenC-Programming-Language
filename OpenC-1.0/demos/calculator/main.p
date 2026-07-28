import system.io;

i32 add(i32 a, i32 b) {
    return a + b;
}

i32 subtract(i32 a, i32 b) {
    return a - b;
}

i32 multiply(i32 a, i32 b) {
    return a * b;
}

i32 divide(i32 a, i32 b) {
    return a / b;
}

i32 modulus(i32 a, i32 b) {
    return a % b;
}

i32 main() {
    i32 x = 42;
    i32 y = 10;

    io.print(x);
    io.print(" + ");
    io.print(y);
    io.print(" = ");
    io.println(add(x, y));

    io.print(x);
    io.print(" - ");
    io.print(y);
    io.print(" = ");
    io.println(subtract(x, y));

    io.print(x);
    io.print(" * ");
    io.print(y);
    io.print(" = ");
    io.println(multiply(x, y));

    io.print(x);
    io.print(" / ");
    io.print(y);
    io.print(" = ");
    io.println(divide(x, y));

    io.print(x);
    io.print(" % ");
    io.print(y);
    io.print(" = ");
    io.println(modulus(x, y));

    return 0;
}