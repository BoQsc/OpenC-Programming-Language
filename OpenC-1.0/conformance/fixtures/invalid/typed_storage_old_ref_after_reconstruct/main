struct Player { i32 health; }

i32 main() {
    storage Player space;
    ref Player old = construct(space, Player{ health = 10 });
    destroy(old);
    ref Player current = construct(space, Player{ health = 20 });
    scope destroy(current);
    return old.health;
}
