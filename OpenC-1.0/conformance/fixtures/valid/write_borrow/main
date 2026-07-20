struct Player { i32 health; }

void damage(ref Player player) {
    player.health -= 10;
}

i32 main() {
    Player player = Player{ health = 100 };
    damage(player);
    return player.health;
}
