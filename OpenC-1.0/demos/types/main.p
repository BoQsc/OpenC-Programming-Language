import system.io;

struct Point {
    i32 x;
    i32 y;
}

struct Rectangle {
    Point top_left;
    Point bottom_right;
}

enum Color {
    red,
    green,
    blue,
    yellow,
}

i32 area(Rectangle rect) {
    i32 width = rect.bottom_right.x - rect.top_left.x;
    i32 height = rect.bottom_right.y - rect.top_left.y;
    return width * height;
}

i32 color_code(Color color) {
    switch color {
        case Color.red    { return 0xFF0000; }
        case Color.green  { return 0x00FF00; }
        case Color.blue   { return 0x0000FF; }
        case Color.yellow { return 0xFFFF00; }
    }
}

i32 main() {
    Point a = Point{ x = 0, y = 0 };
    Point b = Point{ x = 100, y = 50 };
    Rectangle rect = Rectangle{ top_left = a, bottom_right = b };

    io.print("Rectangle area: ");
    io.println(area(rect));

    io.print("Color code for green: ");
    io.println(color_code(Color.green));

    io.print("Color code for red: ");
    io.println(color_code(Color.red));

    return 0;
}