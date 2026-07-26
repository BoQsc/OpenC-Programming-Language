i32 main() {
    text first = "OpenC";
    text second = first;
    if first == second && first.length == 5 {
        return 0;
    }
    return 1;
}
