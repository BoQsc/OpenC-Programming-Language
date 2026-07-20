struct Player { i32 health; }
ref Player bad() {
    Player player = Player{ health = 100 };
    return player;
}
