#ifndef AWESOMUX_GHOSTTY_H
#define AWESOMUX_GHOSTTY_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__GNUC__) && __GNUC__ >= 4
#define AMX_GHOSTTY_API __attribute__((visibility("default")))
#else
#define AMX_GHOSTTY_API
#endif

typedef struct amx_ghostty_app amx_ghostty_app;
typedef struct amx_ghostty_surface amx_ghostty_surface;

typedef struct {
  const char *key;
  const char *value;
} amx_ghostty_env_var;

typedef void (*amx_ghostty_title_cb)(void *userdata, const char *title);
typedef void (*amx_ghostty_cwd_cb)(void *userdata, const char *working_directory);
typedef void (*amx_ghostty_close_cb)(void *userdata, bool process_alive);
typedef void (*amx_ghostty_focus_cb)(void *userdata, bool focused);
typedef enum {
  AMX_GHOSTTY_PERMISSION_CLIPBOARD_WRITE = 1,
  AMX_GHOSTTY_PERMISSION_UNSAFE_PASTE = 2,
} amx_ghostty_permission_kind;
/* The host must resolve the request ID explicitly. Payload bytes never cross this callback. */
typedef void (*amx_ghostty_permission_cb)(void *userdata, uint64_t request_id,
                                           amx_ghostty_permission_kind kind,
                                           size_t character_count,
                                           size_t byte_count);
typedef void (*amx_ghostty_permission_cancel_cb)(void *userdata,
                                                  uint64_t request_id);

typedef struct {
  void *userdata;
  amx_ghostty_title_cb title_changed;
  amx_ghostty_cwd_cb working_directory_changed;
  amx_ghostty_close_cb close_requested;
  amx_ghostty_focus_cb focus_changed;
  amx_ghostty_permission_cb permission_requested;
  amx_ghostty_permission_cancel_cb permission_cancelled;
} amx_ghostty_callbacks;

/* Must be called before GTK initialization so GTK selects desktop OpenGL. */
AMX_GHOSTTY_API bool amx_ghostty_prepare_gtk_environment(void);

AMX_GHOSTTY_API amx_ghostty_app *amx_ghostty_app_create(void);
AMX_GHOSTTY_API void amx_ghostty_app_destroy(amx_ghostty_app *app);

AMX_GHOSTTY_API amx_ghostty_surface *amx_ghostty_surface_create(
    amx_ghostty_app *app,
    const char *working_directory,
    const char *command,
    amx_ghostty_callbacks callbacks);
AMX_GHOSTTY_API amx_ghostty_surface *amx_ghostty_surface_create_with_environment(
    amx_ghostty_app *app,
    const char *working_directory,
    const char *command,
    const amx_ghostty_env_var *environment,
    size_t environment_count,
    amx_ghostty_callbacks callbacks);
AMX_GHOSTTY_API void amx_ghostty_surface_destroy(amx_ghostty_surface *surface);
/* Returns false for stale, cancelled, or destroyed requests. GTK main thread only. */
AMX_GHOSTTY_API bool amx_ghostty_surface_resolve_permission(
    amx_ghostty_surface *surface, uint64_t request_id, bool allow);

/* Returns the GtkWidget pointer as an opaque language-neutral handle. */
AMX_GHOSTTY_API void *amx_ghostty_surface_widget(amx_ghostty_surface *surface);
AMX_GHOSTTY_API void amx_ghostty_surface_set_accessible_label(
    amx_ghostty_surface *surface,
    const char *label,
    const char *description);
AMX_GHOSTTY_API void amx_ghostty_surface_focus(amx_ghostty_surface *surface);
AMX_GHOSTTY_API bool amx_ghostty_surface_is_ready(amx_ghostty_surface *surface);
AMX_GHOSTTY_API bool amx_ghostty_surface_process_exited(
    amx_ghostty_surface *surface);
AMX_GHOSTTY_API bool amx_ghostty_surface_has_seen_prompt(
    amx_ghostty_surface *surface);
AMX_GHOSTTY_API bool amx_ghostty_surface_needs_confirm_quit(
    amx_ghostty_surface *surface);
AMX_GHOSTTY_API uint64_t amx_ghostty_surface_foreground_process_id(
    amx_ghostty_surface *surface);
AMX_GHOSTTY_API bool amx_ghostty_surface_binding_action(
    amx_ghostty_surface *surface,
    const char *action);
AMX_GHOSTTY_API void amx_ghostty_surface_request_close(
    amx_ghostty_surface *surface);
AMX_GHOSTTY_API void amx_ghostty_surface_send_enter(
    amx_ghostty_surface *surface);
AMX_GHOSTTY_API void amx_ghostty_surface_send_text(
    amx_ghostty_surface *surface,
    const char *utf8,
    uint64_t length);

#ifdef __cplusplus
}
#endif

#endif
