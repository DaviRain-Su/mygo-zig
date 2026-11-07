#ifndef MYGO_H
#define MYGO_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef const char* mygo_chars_t;
typedef const uint8_t* mygo_bytes_ptr_t;

typedef struct mygo_str {
    mygo_chars_t data;
    size_t len;
} mygo_str_t;

static inline mygo_str_t mygo_cstr(const char* s) {
    mygo_str_t out;
    out.data = s;
    out.len = s ? strlen(s) : 0;
    return out;
}

/* DevTools modes (matches mygo.DevTools). */
enum {
    MYGO_DEVTOOLS_AUTO     = 0,
    MYGO_DEVTOOLS_ENABLED  = 1,
    MYGO_DEVTOOLS_DISABLED = 2
};

/* Window event kinds for mygo_window_on_event. */
enum {
    MYGO_WINDOW_EVENT_CLOSE     = 1, /* return non-zero to prevent close */
    MYGO_WINDOW_EVENT_CLOSED    = 2,
    MYGO_WINDOW_EVENT_FOCUS     = 3,
    MYGO_WINDOW_EVENT_BLUR      = 4,
    MYGO_WINDOW_EVENT_RESIZE    = 5,
    MYGO_WINDOW_EVENT_FILE_DROP = 6  /* payload_json = {"paths":[...],"x":...,"y":...} */
};

typedef struct mygo_window_options {
    mygo_str_t title;
    mygo_str_t url;
    mygo_str_t background_color;
    int32_t width;
    int32_t height;
    int32_t min_width;
    int32_t min_height;
    int32_t max_width;
    int32_t max_height;
    int32_t devtools;
    uint8_t use_content_size;
    uint8_t hidden;
    uint8_t frameless;
    uint8_t disable_resize;
    uint8_t always_on_top;
    uint8_t transparent;
} mygo_window_options_t;

typedef const mygo_window_options_t* mygo_window_options_ptr_t;

typedef void (*mygo_ready_fn)(void* userdata);

/* Delivers transient byte/UTF-8 data (valid for the duration of the call)
 * back to the host without cross-runtime malloc/free ownership issues. */
typedef void (*mygo_bytes_fn)(mygo_chars_t data, size_t len, void* userdata);

typedef void (*mygo_ipc_fn)(
    int32_t caller_window_id,
    mygo_chars_t args_json,
    size_t args_len,
    uintptr_t reply,
    void* userdata
);

typedef int32_t (*mygo_window_event_fn)(
    int32_t win_id,
    int32_t event_kind,
    mygo_chars_t payload_json,
    size_t payload_len,
    void* userdata
);

typedef void (*mygo_menu_click_fn)(
    mygo_chars_t item_id,
    size_t id_len,
    int32_t win_id,
    uint8_t checked,
    void* userdata
);

typedef void (*mygo_protocol_fn)(
    int32_t caller_window_id,
    mygo_chars_t method_ptr,
    size_t method_len,
    mygo_chars_t url_ptr,
    size_t url_len,
    uintptr_t request_handle,
    void* userdata
);

/* ============================================================================
 * Step 3: Native GPU UI (`ui`) CommandBuffer ABI
 * ============================================================================ */

/* Packed sRGB color: 0xRRGGBBAA. */
typedef uint32_t mygo_ui_color_t;

/* Modifier flags (matches ui.Modifiers). */
enum {
    MYGO_MOD_SHIFT = 1 << 0,
    MYGO_MOD_CTRL  = 1 << 1,
    MYGO_MOD_ALT   = 1 << 2,
    MYGO_MOD_SUPER = 1 << 3
};

/* Key codes (matches ui.Key / internal/platform.Key). */
enum {
    MYGO_KEY_UNKNOWN   = 0,
    MYGO_KEY_ENTER     = 1,
    MYGO_KEY_ESCAPE    = 2,
    MYGO_KEY_BACKSPACE = 3,
    MYGO_KEY_TAB       = 4,
    MYGO_KEY_SPACE     = 5,
    MYGO_KEY_DELETE    = 6,
    MYGO_KEY_INSERT    = 7,
    MYGO_KEY_HOME      = 8,
    MYGO_KEY_END       = 9,
    MYGO_KEY_PAGE_UP   = 10,
    MYGO_KEY_PAGE_DOWN = 11,
    MYGO_KEY_LEFT      = 12,
    MYGO_KEY_RIGHT     = 13,
    MYGO_KEY_UP        = 14,
    MYGO_KEY_DOWN      = 15
};

/* Binary CommandBuffer opcodes decoded by mygo_ui_flush. */
enum {
    /* Containers & Primitives */
    MYGO_UI_OP_COLUMN         = 1,  /* [str key] */
    MYGO_UI_OP_ROW            = 2,  /* [str key] */
    MYGO_UI_OP_SCROLL         = 3,  /* [str key] */
    MYGO_UI_OP_SPACER         = 4,  /* [] */
    MYGO_UI_OP_DIVIDER        = 5,  /* [] */
    MYGO_UI_OP_TEXT           = 6,  /* [str text] */
    MYGO_UI_OP_BUTTON         = 7,  /* [str key][str label] */
    MYGO_UI_OP_PRIMARY_BUTTON = 8,  /* [str key][str label] */
    MYGO_UI_OP_CHECKBOX       = 9,  /* [str key][u8 checked][str label] -> sets query.bool_val */
    MYGO_UI_OP_TOGGLE         = 10, /* [str key][u8 on][str label]      -> sets query.bool_val */
    MYGO_UI_OP_SWITCH         = 11, /* [str key][u8 on]                 -> sets query.bool_val */
    MYGO_UI_OP_SLIDER         = 12, /* [str key][f64 val][f64 lo][f64 hi]-> sets query.num_val, query.bool_val(changed) */
    MYGO_UI_OP_TEXT_INPUT     = 13, /* [str key][str val]               -> sets query.bool_val(changed), query.text */

    /* Tree Scoping */
    MYGO_UI_OP_PUSH_PARENT    = 20, /* enters current element's Children scope */
    MYGO_UI_OP_POP_PARENT     = 21, /* exits current Children scope */

    /* Style & Layout Modifiers (0 FFI calls until flushed!) */
    MYGO_UI_OP_FILL               = 30, /* [] */
    MYGO_UI_OP_FILL_WIDTH         = 31, /* [] */
    MYGO_UI_OP_FILL_HEIGHT        = 32, /* [] */
    MYGO_UI_OP_GROW               = 33, /* [f32 factor] */
    MYGO_UI_OP_CENTER             = 34, /* [] */
    MYGO_UI_OP_GAP                = 35, /* [f32 gap] */
    MYGO_UI_OP_PADDING_ALL        = 36, /* [f32 p] */
    MYGO_UI_OP_PADDING_XY         = 37, /* [f32 x][f32 y] */
    MYGO_UI_OP_PADDING_TRBL       = 38, /* [f32 top][f32 right][f32 bottom][f32 left] */
    MYGO_UI_OP_WIDTH              = 39, /* [f32 w] */
    MYGO_UI_OP_HEIGHT             = 40, /* [f32 h] */
    MYGO_UI_OP_MIN_WIDTH          = 41, /* [f32 w] */
    MYGO_UI_OP_MAX_WIDTH          = 42, /* [f32 w] */
    MYGO_UI_OP_BACKGROUND         = 43, /* [u32 rgba] */
    MYGO_UI_OP_RADIUS             = 44, /* [f32 r] */
    MYGO_UI_OP_BORDER             = 45, /* [f32 width][u32 rgba] */
    MYGO_UI_OP_FONT_SIZE          = 46, /* [f32 size] */
    MYGO_UI_OP_BOLD               = 47, /* [] */
    MYGO_UI_OP_TEXT_COLOR         = 48, /* [u32 rgba] */
    MYGO_UI_OP_DISABLED           = 49, /* [u8 disabled] */
    MYGO_UI_OP_LABEL              = 50, /* [str label] */
    MYGO_UI_OP_PLACEHOLDER        = 51, /* [str placeholder] */
    MYGO_UI_OP_NUMERIC_TRANSITION = 52, /* [u8 down] */

    /* Synchronous Queries (flushes tape and populates mygo_ui_query_t) */
    MYGO_UI_OP_QUERY_CLICKED   = 80, /* [] -> query.bool_val */
    MYGO_UI_OP_QUERY_HOVERED   = 81, /* [] -> query.bool_val */
    MYGO_UI_OP_QUERY_CHANGED   = 82, /* [] -> query.bool_val */
    MYGO_UI_OP_QUERY_SUBMITTED = 83, /* [] -> query.bool_val */
    MYGO_UI_OP_QUERY_SHORTCUT  = 84  /* [u8 mods][u16 key] -> query.bool_val */
};

typedef struct mygo_ui_theme {
    uint8_t dark;
    mygo_ui_color_t background;
    mygo_ui_color_t surface;
    mygo_ui_color_t surface_hover;
    mygo_ui_color_t surface_pressed;
    mygo_ui_color_t border;
    mygo_ui_color_t text;
    mygo_ui_color_t text_muted;
    mygo_ui_color_t accent;
    mygo_ui_color_t accent_text;
    mygo_ui_color_t danger;
    mygo_ui_color_t warning;
    mygo_ui_color_t success;
    float radius;
    float spacing;
    float font_size;
} mygo_ui_theme_t;

typedef struct mygo_ui_frame {
    int32_t window_id;
    float width;
    float height;
    uint8_t window_active;
    mygo_ui_theme_t theme;
} mygo_ui_frame_t;

typedef const mygo_ui_frame_t* mygo_ui_frame_ptr_t;

typedef struct mygo_ui_query {
    uint8_t bool_val;
    double num_val;
    mygo_chars_t text_ptr;
    size_t text_len;
} mygo_ui_query_t;

typedef void (*mygo_ui_view_fn)(
    uintptr_t frame_handle,
    mygo_ui_frame_ptr_t info,
    void* userdata
);

#ifndef MYGO_BUILDING_FFI

/* Application lifecycle */
void mygo_app_set_name(mygo_chars_t name_ptr, size_t name_len);
int32_t mygo_app_run(mygo_ready_fn on_ready, void* userdata);
void mygo_app_quit(void);
size_t mygo_last_error(char* buf, size_t cap);

/* Windows & Pages */
int32_t mygo_window_new(mygo_window_options_ptr_t opts);
void mygo_window_set_title(int32_t win_id, mygo_chars_t title_ptr, size_t title_len);
void mygo_window_show(int32_t win_id);
void mygo_window_hide(int32_t win_id);
void mygo_window_close(int32_t win_id);
void mygo_window_center(int32_t win_id);
void mygo_window_minimize(int32_t win_id);
void mygo_window_maximize(int32_t win_id);
void mygo_window_unmaximize(int32_t win_id);
void mygo_window_set_fullscreen(int32_t win_id, uint8_t fullscreen);
int32_t mygo_window_get_bounds(int32_t win_id, int32_t* x, int32_t* y, int32_t* w, int32_t* h);
void mygo_window_set_bounds(int32_t win_id, int32_t x, int32_t y, int32_t w, int32_t h);
void mygo_window_invalidate(int32_t win_id);
int32_t mygo_window_on_event(
    int32_t win_id,
    int32_t event_kind,
    mygo_window_event_fn callback,
    void* userdata
);

int32_t mygo_page_load_url(int32_t win_id, mygo_chars_t url_ptr, size_t url_len);
void mygo_page_load_html(
    int32_t win_id,
    mygo_chars_t html_ptr,
    size_t html_len,
    mygo_chars_t base_url_ptr,
    size_t base_url_len
);

/* Raw JSON IPC & Events */
int32_t mygo_bind_raw(
    mygo_chars_t method_ptr,
    size_t method_len,
    mygo_ipc_fn callback,
    void* userdata
);
void mygo_ipc_defer(uintptr_t reply);
void mygo_ipc_resolve(uintptr_t reply, mygo_chars_t json_ptr, size_t json_len);
void mygo_ipc_reject(uintptr_t reply, mygo_chars_t err_ptr, size_t err_len);
int32_t mygo_emit_raw(
    int32_t win_id,
    mygo_chars_t event_ptr,
    size_t event_len,
    mygo_chars_t json_ptr,
    size_t json_len
);

/* Desktop Shell: Clipboard, Dialogs, Menus, Tray, Shortcuts, Shell, Protocols */
void mygo_clipboard_read_text(mygo_bytes_fn out, void* userdata);
void mygo_clipboard_write_text(mygo_chars_t text_ptr, size_t text_len);
void mygo_clipboard_clear(void);

int32_t mygo_dialog_open(mygo_chars_t opts_json, size_t opts_len, mygo_bytes_fn out, void* userdata);
int32_t mygo_dialog_save(mygo_chars_t opts_json, size_t opts_len, mygo_bytes_fn out, void* userdata);
int32_t mygo_dialog_message(mygo_chars_t opts_json, size_t opts_len, mygo_bytes_fn out, void* userdata);

int32_t mygo_app_set_menu(
    mygo_chars_t items_json,
    size_t items_len,
    mygo_menu_click_fn on_click,
    void* userdata
);
int32_t mygo_window_popup_menu(
    int32_t win_id,
    mygo_chars_t items_json,
    size_t items_len,
    mygo_menu_click_fn on_click,
    void* userdata
);

int32_t mygo_tray_new(
    mygo_chars_t opts_json,
    size_t opts_len,
    mygo_bytes_ptr_t icon_png,
    size_t icon_len,
    mygo_menu_click_fn on_menu,
    mygo_ready_fn on_click,
    void* userdata
);
void mygo_tray_set_title(int32_t tray_id, mygo_chars_t title_ptr, size_t title_len);
void mygo_tray_set_tooltip(int32_t tray_id, mygo_chars_t tip_ptr, size_t tip_len);
void mygo_tray_destroy(int32_t tray_id);

int32_t mygo_shortcut_register(
    mygo_chars_t acc_ptr,
    size_t acc_len,
    mygo_ready_fn callback,
    void* userdata
);
void mygo_shortcut_unregister(mygo_chars_t acc_ptr, size_t acc_len);
void mygo_shortcut_unregister_all(void);

int32_t mygo_shell_open_external(mygo_chars_t url_ptr, size_t url_len);
int32_t mygo_shell_open_path(mygo_chars_t path_ptr, size_t path_len);
void mygo_shell_beep(void);

/* Registers a static embedded asset (e.g. Rust include_bytes! / Zig @embedFile)
 * served directly at mygo://localhost/<path> with zero heap copy when static_lifetime != 0. */
int32_t mygo_frontend_add_asset(
    mygo_chars_t path_ptr,
    size_t path_len,
    mygo_bytes_ptr_t data_ptr,
    size_t data_len,
    uint8_t static_lifetime
);

int32_t mygo_protocol_handle(
    mygo_chars_t scheme_ptr,
    size_t scheme_len,
    mygo_protocol_fn handler,
    void* userdata
);
void mygo_protocol_respond(
    uintptr_t request_handle,
    int32_t status_code,
    mygo_chars_t content_type_ptr,
    size_t content_type_len,
    mygo_bytes_ptr_t body_ptr,
    size_t body_len
);

/* Native GPU UI (`ui`) */
int32_t mygo_window_new_ui(
    mygo_window_options_ptr_t opts,
    mygo_ui_view_fn view,
    void* userdata
);
void mygo_ui_flush(
    uintptr_t frame_handle,
    mygo_bytes_ptr_t cmd_ptr,
    size_t cmd_len,
    mygo_ui_query_t* out
);

#endif /* !MYGO_BUILDING_FFI */

#ifdef __cplusplus
}
#endif

#endif /* MYGO_H */
