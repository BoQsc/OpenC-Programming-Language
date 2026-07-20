struct Player { i32 health; }

i32 main() {
    storage Player space;
    ref Player first = construct(space, Player{ health = 10 });
    destroy(first);

    ref Player second = construct(space, Player{ health = 20 });
    scope destroy(second);
    return second.health;
}
