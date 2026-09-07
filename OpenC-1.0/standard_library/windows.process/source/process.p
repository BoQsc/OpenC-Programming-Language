import windows.foundation;
import windows.raw.process;

export resource Process {
    usize process_handle;
    usize thread_handle;
    u32 id;
    bool open;
}

external(c, "ocw_process_start") status win_process_start_runtime(
    ptr const byte command, ptr const byte directory, bool has_directory,
    bool hidden, out usize process_handle, out usize thread_handle,
    out u32 process_id
);
external(c, "ocw_wait_handle") status win_process_wait_runtime(
    usize handle, u32 milliseconds, bool infinite, out bool timed_out
);
external(c, "ocw_process_exit_code") status win_process_exit_code_runtime(
    usize handle, out u32 exit_code
);
external(c, "ocw_close_handle") void win_process_close_runtime(usize handle);

void release_utf16(own foundation.Utf16 value) {
    foundation.utf16_destroy(value);
}

status start_encoded(
    ref const foundation.Utf16 command,
    ref const foundation.Utf16 directory,
    bool has_directory,
    bool hidden,
    out Process child
) {
    usize process_handle;
    usize thread_handle;
    u32 process_id;
    status result = win_process_start_runtime(
        command.data, directory.data, has_directory, hidden,
        out process_handle, out thread_handle, out process_id
    );
    if !result.ok { return result; }
    child = Process{
        process_handle = process_handle,
        thread_handle = thread_handle,
        id = process_id,
        open = true
    };
    return status{ code = 0 };
}

export status start(text command, bool hidden, out Process child) {
    foundation.Utf16 wide_command;
    status encoded = foundation.encode_utf16(command, out wide_command);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide_command);
    foundation.Utf16 empty_directory;
    status empty = foundation.encode_utf16("", out empty_directory);
    if !empty.ok { return empty; }
    scope release_utf16(empty_directory);
    status started = start_encoded(
        wide_command, empty_directory, false, hidden, out child
    );
    if !started.ok { return started; }
    return started;
}

export status start_in(
    text command, text directory, bool hidden, out Process child
) {
    foundation.Utf16 wide_command;
    status encoded = foundation.encode_utf16(command, out wide_command);
    if !encoded.ok { return encoded; }
    scope release_utf16(wide_command);
    foundation.Utf16 wide_directory;
    status encoded_directory = foundation.encode_utf16(directory, out wide_directory);
    if !encoded_directory.ok { return encoded_directory; }
    scope release_utf16(wide_directory);
    status started = start_encoded(
        wide_command, wide_directory, true, hidden, out child
    );
    if !started.ok { return started; }
    return started;
}

export status wait(
    ref Process child, optional u32 timeout, out bool timed_out
) {
    if timeout.present {
        status waited_finite = win_process_wait_runtime(
            child.process_handle, timeout.value, false, out timed_out
        );
        if !waited_finite.ok { return waited_finite; }
        return waited_finite;
    }
    status waited_infinite = win_process_wait_runtime(
        child.process_handle, 0, true, out timed_out
    );
    if !waited_infinite.ok { return waited_infinite; }
    return waited_infinite;
}

export status exit_code(ref Process child, out u32 code) {
    status result = win_process_exit_code_runtime(
        child.process_handle, out code
    );
    if !result.ok { return result; }
    return result;
}

export void close(own Process child) {
    if child.open {
        win_process_close_runtime(child.thread_handle);
        win_process_close_runtime(child.process_handle);
    }
}
