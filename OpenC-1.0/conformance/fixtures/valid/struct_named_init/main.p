struct Player {
    i32 health;
    i32 mana;
}

i32 main() {
    Player player = Player{ health = 100, mana = 50 };
    return player.health;
}
