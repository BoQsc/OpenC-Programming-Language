import windows.raw.graphics;
import windows.window;

export struct Rectangle {
    i32 left;
    i32 top;
    i32 right;
    i32 bottom;
}

export resource DeviceContext {
    usize value;
    usize window_value;
    bool open;
}

export resource Brush {
    usize value;
    bool open;
}

external(c, "ocw_dc_acquire") status win_graphics_dc_acquire_runtime(
    usize window, out usize dc
);
external(c, "ocw_dc_release") void win_graphics_dc_release_runtime(
    usize window, usize dc
);
external(c, "ocw_brush_create") status win_graphics_brush_create_runtime(
    u32 color, out usize brush
);
external(c, "ocw_gdi_delete") void win_graphics_delete_runtime(usize object);
external(c, "ocw_fill_rectangle") status win_graphics_fill_runtime(
    usize dc, i32 left, i32 top, i32 right, i32 bottom, usize brush
);

export status acquire(window.Window target, out DeviceContext context) {
    usize dc;
    status result = win_graphics_dc_acquire_runtime(target.value, out dc);
    if !result.ok { return result; }
    context = DeviceContext{ value = dc, window_value = target.value, open = true };
    return status{ code = 0 };
}

export status solid_brush(u32 color, out Brush brush) {
    usize value;
    status result = win_graphics_brush_create_runtime(color, out value);
    if !result.ok { return result; }
    brush = Brush{ value = value, open = true };
    return status{ code = 0 };
}

export status fill(
    ref DeviceContext context, Rectangle area, ref Brush brush
) {
    return win_graphics_fill_runtime(
        context.value, area.left, area.top, area.right, area.bottom, brush.value
    );
}

export void context_destroy(own DeviceContext context) {
    if context.open {
        win_graphics_dc_release_runtime(context.window_value, context.value);
    }
}

export void brush_destroy(own Brush brush) {
    if brush.open { win_graphics_delete_runtime(brush.value); }
}
