struct Point {
    i32 x;
    i32 y;
}

i32 main() {
    Point left = Point{x=3, y=4};
    Point right = Point{x=3, y=4};
    if left == right {
        return 0;
    }
    return 1;
}
