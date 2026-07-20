resource Box { i32 value; }
Box box_create(i32 value);
Box box_move(own Box value);
void box_destroy(own Box value);
i32 main() {
    Box box = box_create(1);
    bool choose = true;
    if choose {
        Box other = box_move(box);
        box_destroy(other);
    }
    box_destroy(box);
    return 0;
}
