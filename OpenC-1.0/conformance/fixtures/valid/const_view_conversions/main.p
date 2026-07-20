struct Player { i32 health; }

i32 inspect(ref const Player player) { return player.health; }

void inspect_mutable(ref Player player) {
    i32 value = inspect(player);
    player.health = value;
}

i32 main() {
    Player player = Player{ health = 10 };
    inspect_mutable(player);

    i32[2] values = {1, 2};
    i32[] mutable_values = values;
    const i32[] readonly_values = mutable_values;

    unsafe {
        ptr i32 address = &values[0];
        ptr const i32 readonly_address = address;
        return *readonly_address + readonly_values[1] + player.health;
    }
}
