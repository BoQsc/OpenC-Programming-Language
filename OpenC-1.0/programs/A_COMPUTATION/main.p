struct Point {
    i32 x;
    i32 y;
}

enum Direction {
    north,
    east,
    south,
    west,
}

i32 score(Point point, Direction direction) {
    i32 base = point.x + point.y;

    switch direction {
        case Direction.north { return base + 1; }
        case Direction.east  { return base + 2; }
        case Direction.south { return base + 3; }
        case Direction.west  { return base + 4; }
    }
}

i32 main() {
    Point point = Point{ x = 10, y = 20 };
    return score(point, Direction.east);
}
