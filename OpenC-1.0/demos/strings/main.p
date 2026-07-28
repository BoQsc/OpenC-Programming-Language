import system.io;

i32 main() {
    io.println("String handling demo");
    io.println("-------------------");

    io.print("Printing multiple values: ");
    io.print(1);
    io.print(", ");
    io.print(2);
    io.print(", ");
    io.println(3);

    io.print("Newlines are supported");
    io.println("");
    io.println("via io.println.");

    return 0;
}