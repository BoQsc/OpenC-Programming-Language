import windows.raw.thread;

export resource Event {
    usize value;
    bool open;
}

external(c, "ocw_event_create") status win_thread_event_create_runtime(
    bool manual_reset, bool initially_signaled, out usize handle
);
external(c, "ocw_event_set") status win_thread_event_set_runtime(usize handle);
external(c, "ocw_wait_handle") status win_thread_wait_runtime(
    usize handle, u32 milliseconds, bool infinite, out bool timed_out
);
external(c, "ocw_current_thread_id") u32 win_thread_current_id_runtime();
external(c, "ocw_sleep") void win_thread_sleep_runtime(u32 milliseconds);
external(c, "ocw_close_handle") void win_thread_close_runtime(usize handle);

export status create_event(
    bool manual_reset, bool initially_signaled, out Event event
) {
    usize handle;
    status result = win_thread_event_create_runtime(
        manual_reset, initially_signaled, out handle
    );
    if !result.ok { return result; }
    event = Event{ value = handle, open = true };
    return status{ code = 0 };
}

export status set(ref Event event) {
    return win_thread_event_set_runtime(event.value);
}

export status wait(ref Event event, optional u32 timeout, out bool timed_out) {
    if timeout.present {
        status waited_finite = win_thread_wait_runtime(
            event.value, timeout.value, false, out timed_out
        );
        if !waited_finite.ok { return waited_finite; }
        return waited_finite;
    }
    status waited_infinite = win_thread_wait_runtime(
        event.value, 0, true, out timed_out
    );
    if !waited_infinite.ok { return waited_infinite; }
    return waited_infinite;
}

export u32 current_id() { return win_thread_current_id_runtime(); }
export void sleep(u32 milliseconds) { win_thread_sleep_runtime(milliseconds); }

export void close(own Event event) {
    if event.open { win_thread_close_runtime(event.value); }
}
