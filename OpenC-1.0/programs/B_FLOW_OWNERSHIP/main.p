resource Ticket {
    i32 id;
}

status ticket_create(i32 id, out Ticket ticket) {
    ticket = Ticket{ id = id };
    return status{ code = 0 };
}

Ticket ticket_move(own Ticket source) {
    return source;
}

void ticket_destroy(own Ticket ticket) {
}

i32 main() {
    Ticket ticket;
    status made = ticket_create(42, out ticket);

    if !made.ok {
        return made.code;
    }

    scope ticket_destroy(ticket);
    return ticket.id - 42;
}
