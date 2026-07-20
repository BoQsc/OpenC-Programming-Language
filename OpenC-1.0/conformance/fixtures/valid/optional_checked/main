struct Player { i32 health; }

i32 main() {
    optional Player found = Player{ health = 100 };
    if found.present {
        return found.value.health;
    }
    return 0;
}
