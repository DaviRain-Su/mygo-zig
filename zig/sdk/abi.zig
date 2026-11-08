//! C layouts shared with zig/host (see zig/host/abi.go). Keep in step.

/// One ui.InputEvent as the host marshals it (`ZigEventUIInput`).
pub const Input = extern struct {
    kind: u32 = 0,
    mods: u32 = 0,
    key: u32 = 0,
    physical_key: u32 = 0,
    code: u32 = 0,
    button: u32 = 0,
    clicks: u32 = 0,
    caret: i32 = 0,
    start: i32 = 0,
    end: i32 = 0,
    /// 1 repeat, 2 canceled, 4 precise, 8 momentum.
    flags: u32 = 0,
    pointer: u32 = 0,
    x: f32 = 0,
    y: f32 = 0,
    pressure: f32 = 0,
    scale: f32 = 0,
    dx: f32 = 0,
    dy: f32 = 0,
    /// UTF-8 text, valid only while the handler runs.
    text_ptr: usize = 0,
    text_len: usize = 0,
};

/// A hit test's question (`ZigEventUIHitTest`).
pub const Hit = extern struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
    px: f32 = 0,
    py: f32 = 0,
};

/// One ui.TextKey as the host marshals it: the key, the text, and a buffer
/// the handler writes the replacement text into.
pub const TextKey = extern struct {
    key: u32 = 0,
    mods: u32 = 0,
    text_ptr: usize = 0,
    text_len: usize = 0,
    out_ptr: usize = 0,
    out_cap: usize = 0,
    /// 0 for no change.
    out_len: usize = 0,
};
