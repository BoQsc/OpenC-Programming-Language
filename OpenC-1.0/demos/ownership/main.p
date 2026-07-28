import system.io;

resource File {
    i32 descriptor;
}

status file_open(i32 id, out File file) {
    file = File{ descriptor = id };
    io.print("file_open: opened descriptor ");
    io.println(id);
    return status{ code = 0 };
}

void file_close(own File file) {
    io.print("file_close: closed descriptor ");
    io.println(file.descriptor);
}

i32 main() {
    io.println("Ownership and resource demo");

    File f;
    status st = file_open(7, out f);

    if !st.ok {
        return st.code;
    }

    scope file_close(f);

    io.print("File descriptor in use: ");
    io.println(f.descriptor);

    return 0;
}