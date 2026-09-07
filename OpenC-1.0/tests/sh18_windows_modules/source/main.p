import windows.console;
import windows.file;
import windows.foundation;
import windows.graphics;
import windows.memory;
import windows.network;
import windows.process;
import windows.registry;
import windows.resources;
import windows.shell;
import windows.thread;
import windows.window;

i32 verify_foundation() {
    foundation.Utf16 wide;
    status encoded = foundation.encode_utf16("OpenC SH-18 ✓", out wide);
    if !encoded.ok { return 1; }
    foundation.OwnedText roundtrip;
    status decoded = foundation.decode_utf16(wide, out roundtrip);
    if !decoded.ok {
        foundation.utf16_destroy(wide);
        return 2;
    }
    foundation.utf16_destroy(wide);
    text observed = "";
    unsafe { observed = foundation.view(roundtrip); }
    if observed != "OpenC SH-18 ✓" {
        foundation.text_destroy(roundtrip);
        return 3;
    }
    foundation.text_destroy(roundtrip);
    return 0;
}

i32 verify_file() {
    text path = "build-output/sh18-friendly-✓.txt";
    file.File output;
    status created = file.replace(path, out output);
    if !created.ok { return 10; }
    status written = file.write_text(output, "OpenC UTF-8 file ✓");
    if !written.ok { file.close(output); return 11; }
    status flushed = file.flush(output);
    if !flushed.ok { file.close(output); return 12; }
    file.close(output);

    file.File input;
    status opened = file.open_read(path, out input);
    if !opened.ok { return 13; }
    foundation.OwnedText value;
    status read = file.read_text(input, out value);
    if !read.ok { file.close(input); return 14; }
    file.close(input);
    text observed = "";
    unsafe { observed = foundation.view(value); }
    if observed != "OpenC UTF-8 file ✓" {
        foundation.text_destroy(value);
        return 15;
    }
    foundation.text_destroy(value);
    status removed = file.remove(path);
    if !removed.ok { return 16; }
    return 0;
}

i32 verify_memory() {
    memory.Heap heap;
    status created = memory.create(out heap);
    if !created.ok { return 20; }
    memory.Block block;
    status allocated = memory.allocate(heap, 32, out block);
    if !allocated.ok { memory.heap_destroy(heap); return 21; }
    memory.Block resized;
    status changed = memory.resize(block, 96, out resized);
    if !changed.ok { memory.heap_destroy(heap); return 22; }
    memory.block_destroy(resized);
    memory.heap_destroy(heap);
    return 0;
}

i32 verify_process() {
    process.Process child;
    status started = process.start("cmd.exe /d /c exit 7", true, out child);
    if !started.ok { return 30; }
    u32 limit = 5000;
    optional u32 timeout = limit;
    bool timed_out;
    status waited = process.wait(child, timeout, out timed_out);
    if !waited.ok { process.close(child); return 31; }
    if timed_out { process.close(child); return 32; }
    u32 code;
    status observed = process.exit_code(child, out code);
    if !observed.ok { process.close(child); return 33; }
    process.close(child);
    if code != 7 { return 34; }
    return 0;
}

i32 verify_thread() {
    thread.Event event;
    status created = thread.create_event(false, false, out event);
    if !created.ok { return 40; }
    status signaled = thread.set(event);
    if !signaled.ok { thread.close(event); return 41; }
    u32 limit = 1000;
    optional u32 timeout = limit;
    bool timed_out;
    status waited = thread.wait(event, timeout, out timed_out);
    if !waited.ok { thread.close(event); return 42; }
    thread.close(event);
    if timed_out { return 43; }
    if thread.current_id() == 0 { return 44; }
    thread.sleep(0);
    return 0;
}

i32 verify_window_graphics() {
    window.Window desktop;
    status found = window.desktop(out desktop);
    if !found.ok { return 50; }
    if !window.valid(desktop) { return 51; }
    foundation.OwnedText title;
    status read_title = window.title(desktop, out title);
    if !read_title.ok { return 52; }
    foundation.text_destroy(title);

    graphics.DeviceContext context;
    status acquired = graphics.acquire(desktop, out context);
    if !acquired.ok { return 53; }
    graphics.Brush brush;
    status created = graphics.solid_brush(0, out brush);
    if !created.ok { graphics.context_destroy(context); return 54; }
    graphics.Rectangle empty = graphics.Rectangle{
        left = 0, top = 0, right = 0, bottom = 0
    };
    status filled = graphics.fill(context, empty, brush);
    graphics.brush_destroy(brush);
    graphics.context_destroy(context);
    if !filled.ok { return 55; }
    return 0;
}

i32 verify_resources_network() {
    foundation.OwnedText executable;
    status located = resources.executable_path(out executable);
    if !located.ok { return 60; }
    foundation.text_destroy(executable);
    resources.Library library;
    status loaded = resources.load_system("kernel32.dll", out library);
    if !loaded.ok { return 61; }
    resources.close(library);

    network.Session session;
    status started = network.start(out session);
    if !started.ok { return 62; }
    foundation.OwnedText host;
    status named = network.host_name(session, out host);
    if !named.ok { network.close(session); return 63; }
    text host_text = "";
    unsafe { host_text = foundation.view(host); }
    if host_text == "" {
        foundation.text_destroy(host);
        network.close(session);
        return 64;
    }
    foundation.text_destroy(host);
    network.close(session);
    return 0;
}

i32 verify_registry_shell() {
    registry.Key key;
    status opened = registry.open_current_user("Environment", false, out key);
    if !opened.ok { return 70; }
    registry.close(key);

    foundation.OwnedText local_data;
    status located = shell.local_app_data(out local_data);
    if !located.ok { return 71; }
    text path = "";
    unsafe { path = foundation.view(local_data); }
    if path == "" { foundation.text_destroy(local_data); return 72; }
    foundation.text_destroy(local_data);
    return 0;
}

i32 main() {
    i32 result = verify_foundation();
    if result != 0 { return result; }
    result = console.write("OpenC SH-18 friendly Windows modules ✓\n").code;
    if result != 0 { return 4; }
    result = verify_file();
    if result != 0 { return result; }
    result = verify_memory();
    if result != 0 { return result; }
    result = verify_process();
    if result != 0 { return result; }
    result = verify_thread();
    if result != 0 { return result; }
    result = verify_window_graphics();
    if result != 0 { return result; }
    result = verify_resources_network();
    if result != 0 { return result; }
    return verify_registry_shell();
}
