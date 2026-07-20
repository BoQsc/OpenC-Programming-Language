struct Player { i32 health; }
i32 main() {
    storage Player space;
    ref Player a = construct(space, Player{ health = 1 });
    ref Player b = construct(space, Player{ health = 2 });
    return a.health + b.health;
}
