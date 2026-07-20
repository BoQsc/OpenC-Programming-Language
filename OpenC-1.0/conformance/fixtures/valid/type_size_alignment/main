struct Point { i32 x; i32 y; }
const usize point_size = size_of(Point);
const usize point_align = align_of(Point);
const usize array_size = size_of(Point[4]);
i32 main() { if array_size == point_size * 4 && point_align > 0 { return 0; } return 1; }
