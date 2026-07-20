struct Player { i32 health; }

i32 main() {
    storage Player space;
    ref Player player = construct(space, Player{ health = 100 });
    scope destroy(player);
    player.health = 80;
    return player.health;
}
