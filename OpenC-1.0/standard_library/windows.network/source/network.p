import windows.foundation;

export resource Session {
    usize module;
    bool active;
}

external(c, "ocw_network_start") status win_network_start_runtime(out usize module);
external(c, "ocw_network_stop") void win_network_stop_runtime(usize module);
external(c, "ocw_network_host_name") status win_network_host_runtime(
    usize module, out own ptr byte data, out usize length
);

export status start(out Session session) {
    usize module;
    status result = win_network_start_runtime(out module);
    if !result.ok { return result; }
    session = Session{ module = module, active = true };
    return status{ code = 0 };
}

export status host_name(
    ref Session session, out foundation.OwnedText name
) {
    ptr byte data;
    usize length;
    status result = win_network_host_runtime(
        session.module, out data, out length
    );
    if !result.ok { return result; }
    name = foundation.OwnedText{ own data = data, length = length };
    return status{ code = 0 };
}

export void close(own Session session) {
    if session.active { win_network_stop_runtime(session.module); }
}
