struct Player { i32 health; }

void bad() {
    storage Player space;
    ref Player player = construct(space, Player{ health = 100 });
    player.health = 80;
}
