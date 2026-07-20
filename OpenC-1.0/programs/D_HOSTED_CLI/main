import system.io;
import system.process;

i32 main() {
    usize count = process.argument_count();
    io.print("arguments: ");
    io.print(count);
    io.println("");

    usize index = 0;
    while index < count {
        io.print(index);
        io.print(": ");
        io.println(process.argument(index));
        index = index + 1;
    }

    return 0;
}
