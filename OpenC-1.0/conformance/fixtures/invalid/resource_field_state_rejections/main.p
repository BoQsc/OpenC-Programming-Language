resource Part {
    usize id = 0;
}

resource Pair {
    Part first;
    Part second;
}

Part make_part();
void consume_part(own Part part);
void observe(ref const Pair pair);

void invalid_field_transfers(own Pair pair) {
    consume_part(pair.first);
    consume_part(pair.first);
    observe(pair);

    Part replacement = make_part();
    pair.second = replacement;
}
