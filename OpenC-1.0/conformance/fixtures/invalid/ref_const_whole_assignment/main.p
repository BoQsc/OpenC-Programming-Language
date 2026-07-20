struct Point { i32 x; }

void bad(ref const Point point) {
    point = Point{ x = 10 };
}
