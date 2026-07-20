struct Point { i32 x; i32 y; }

void replace(ref Point target) {
    target = Point{ x = 10, y = 20 };
}

i32 main() {
    Point point = Point{ x = 1, y = 2 };
    replace(point);
    return point.x + point.y;
}
