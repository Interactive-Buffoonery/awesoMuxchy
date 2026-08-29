#include "awesomux_ghostty.h"

#include <gtk/gtk.h>
#include <ghostty.h>
#include <stdlib.h>
#include <string.h>

struct amx_ghostty_app {
  ghostty_app_t core;
  ghostty_config_t config;
};

struct amx_ghostty_surface {
  amx_ghostty_app *app;
  GtkWidget *area;
  GtkIMContext *ime;
  ghostty_surface_t core;
  amx_ghostty_callbacks callbacks;
  char *working_directory;
  char *command;
  ghostty_env_var_s *environment;
  size_t environment_count;
  size_t pending_clipboard_reads;
  bool destroying;
};

typedef struct {
  amx_ghostty_surface *surface;
  void *request;
  bool list_available;
} clipboard_read;

static bool ghostty_initialized = false;

static void finalize_surface(amx_ghostty_surface *surface);
static void clipboard_read_text_finished(GObject *source,
                                         GAsyncResult *result,
                                         void *userdata);

static gboolean tick_on_main(void *data) {
  amx_ghostty_app *app = data;
  if (app != NULL && app->core != NULL) ghostty_app_tick(app->core);
  return G_SOURCE_REMOVE;
}

static void runtime_wakeup(void *userdata) {
  g_main_context_invoke(NULL, tick_on_main, userdata);
}

static amx_ghostty_surface *host_surface(ghostty_target_s target) {
  if (target.tag != GHOSTTY_TARGET_SURFACE || target.target.surface == NULL) {
    return NULL;
  }
  return ghostty_surface_userdata(target.target.surface);
}

static bool runtime_action(ghostty_app_t app,
                           ghostty_target_s target,
                           ghostty_action_s action) {
  (void)app;
  amx_ghostty_surface *surface = host_surface(target);
  if (surface == NULL || surface->destroying) return false;

  switch (action.tag) {
    case GHOSTTY_ACTION_RENDER:
      gtk_gl_area_queue_render(GTK_GL_AREA(surface->area));
      return true;
    case GHOSTTY_ACTION_SET_TITLE:
    case GHOSTTY_ACTION_SET_TAB_TITLE:
    case GHOSTTY_ACTION_SET_WINDOW_TITLE: {
      if (surface->callbacks.title_changed == NULL) return true;
      ghostty_action_set_title_s title = action.action.set_title;
      surface->callbacks.title_changed(surface->callbacks.userdata, title.title);
      return true;
    }
    case GHOSTTY_ACTION_PWD: {
      if (surface->callbacks.working_directory_changed == NULL) return true;
      ghostty_action_pwd_s pwd = action.action.pwd;
      surface->callbacks.working_directory_changed(
          surface->callbacks.userdata, pwd.pwd);
      return true;
    }
    case GHOSTTY_ACTION_CLOSE_WINDOW:
      if (surface->callbacks.close_requested != NULL) {
        surface->callbacks.close_requested(surface->callbacks.userdata, false);
      }
      return true;
    default:
      return false;
  }
}

static ghostty_clipboard_read_result_e read_clipboard(
    void *userdata,
    ghostty_clipboard_e clipboard,
    void *request,
    const char *const *mime_types,
    size_t mime_type_count,
    bool list_available) {
  (void)mime_types;
  (void)mime_type_count;
  (void)list_available;
  amx_ghostty_surface *surface = userdata;
  if (surface == NULL || surface->destroying || surface->core == NULL) {
    return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE;
  }

  GdkDisplay *display = gtk_widget_get_display(surface->area);
  GdkClipboard *source = clipboard == GHOSTTY_CLIPBOARD_SELECTION ||
                                 clipboard == GHOSTTY_CLIPBOARD_PRIMARY
      ? gdk_display_get_primary_clipboard(display)
      : gdk_display_get_clipboard(display);
  GdkContentFormats *formats = gdk_clipboard_get_formats(source);
  if (!gdk_content_formats_contain_gtype(formats, G_TYPE_STRING)) {
    return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE;
  }

  clipboard_read *read = calloc(1, sizeof(*read));
  if (read == NULL) return GHOSTTY_CLIPBOARD_READ_UNAVAILABLE;
  read->surface = surface;
  read->request = request;
  read->list_available = list_available;
  surface->pending_clipboard_reads++;
  gdk_clipboard_read_text_async(source, NULL, clipboard_read_text_finished, read);
  return GHOSTTY_CLIPBOARD_READ_STARTED;
}

static void clipboard_read_text_finished(GObject *source,
                                         GAsyncResult *result,
                                         void *userdata) {
  clipboard_read *read = userdata;
  amx_ghostty_surface *surface = read->surface;
  GError *error = NULL;
  char *text = gdk_clipboard_read_text_finish(
      GDK_CLIPBOARD(source), result, &error);

  if (!surface->destroying && surface->core != NULL) {
    if (error != NULL || text == NULL) {
      ghostty_surface_deny_clipboard_request(surface->core, read->request);
    } else {
      const ghostty_clipboard_content_s content = {
          .mime = "text/plain",
          .data = text,
          .len = strlen(text),
      };
      const char *available[] = {"text/plain"};
      const ghostty_clipboard_complete_s completion = {
          .contents = &content,
          .contents_len = 1,
          .available = read->list_available ? available : NULL,
          .available_len = read->list_available ? 1 : 0,
      };
      ghostty_surface_complete_clipboard_request(
          surface->core, &completion, read->request);
    }
  }

  g_clear_error(&error);
  g_free(text);
  free(read);
  surface->pending_clipboard_reads--;
  if (surface->destroying && surface->pending_clipboard_reads == 0) {
    finalize_surface(surface);
  }
}

static void confirm_read_clipboard(
    void *userdata,
    const ghostty_clipboard_confirm_s *confirmation,
    void *request,
    ghostty_clipboard_request_e request_type) {
  amx_ghostty_surface *surface = userdata;
  if (surface == NULL || surface->destroying || surface->core == NULL) return;

  if (request_type != GHOSTTY_CLIPBOARD_REQUEST_PASTE &&
      request_type != GHOSTTY_CLIPBOARD_REQUEST_LIST) {
    ghostty_surface_deny_clipboard_request(surface->core, request);
    return;
  }

  const ghostty_clipboard_complete_s completion = {
      .contents = confirmation->contents,
      .contents_len = confirmation->contents_len,
      .available = confirmation->available,
      .available_len = confirmation->available_len,
      .confirmed = true,
  };
  ghostty_surface_complete_clipboard_request(surface->core, &completion, request);
}

static void write_clipboard(void *userdata,
                            ghostty_clipboard_e clipboard,
                            const ghostty_clipboard_content_s *contents,
                            size_t contents_len,
                            bool confirm) {
  (void)confirm;
  amx_ghostty_surface *surface = userdata;
  if (surface == NULL || contents_len == 0) return;

  GdkDisplay *display = gtk_widget_get_display(surface->area);
  GdkClipboard *destination = clipboard == GHOSTTY_CLIPBOARD_SELECTION ||
                                      clipboard == GHOSTTY_CLIPBOARD_PRIMARY
      ? gdk_display_get_primary_clipboard(display)
      : gdk_display_get_clipboard(display);
  char *text = g_strndup(contents[0].data, contents[0].len);
  gdk_clipboard_set_text(destination, text);
  g_free(text);
}

static void close_surface(void *userdata, bool process_alive) {
  amx_ghostty_surface *surface = userdata;
  if (surface != NULL && surface->callbacks.close_requested != NULL) {
    surface->callbacks.close_requested(surface->callbacks.userdata, process_alive);
  }
}

amx_ghostty_app *amx_ghostty_app_create(void) {
  if (!ghostty_initialized) {
    char program_name[] = "awesomux";
    char *arguments[] = {program_name, NULL};
    if (ghostty_init(1, arguments) != 0) return NULL;
    ghostty_initialized = true;
  }

  amx_ghostty_app *app = calloc(1, sizeof(*app));
  if (app == NULL) return NULL;

  app->config = ghostty_config_new();
  if (app->config == NULL) goto fail;
  ghostty_config_load_default_files(app->config);
  ghostty_config_finalize(app->config);

  ghostty_runtime_config_s runtime = {
      .userdata = app,
      .supports_selection_clipboard = true,
      .wakeup_cb = runtime_wakeup,
      .action_cb = runtime_action,
      .read_clipboard_cb = read_clipboard,
      .confirm_read_clipboard_cb = confirm_read_clipboard,
      .write_clipboard_cb = write_clipboard,
      .close_surface_cb = close_surface,
  };
  app->core = ghostty_app_new(&runtime, app->config);
  if (app->core == NULL) goto fail;
  return app;

fail:
  if (app->config != NULL) ghostty_config_free(app->config);
  free(app);
  return NULL;
}

void amx_ghostty_app_destroy(amx_ghostty_app *app) {
  if (app == NULL) return;
  if (app->core != NULL) ghostty_app_free(app->core);
  if (app->config != NULL) ghostty_config_free(app->config);
  free(app);
}

static void on_realize(GtkGLArea *area, amx_ghostty_surface *surface) {
  gtk_gl_area_make_current(area);
  const GError *error = gtk_gl_area_get_error(area);
  if (error != NULL) {
    g_printerr("awesomux ghostty: GL context unavailable: %s\n", error->message);
    return;
  }

  ghostty_surface_config_s config = ghostty_surface_config_new();
  config.platform_tag = GHOSTTY_PLATFORM_LINUX;
  config.platform.linux.gl_area = area;
  config.userdata = surface;
  config.scale_factor = gtk_widget_get_scale_factor(GTK_WIDGET(area));
  config.working_directory = surface->working_directory;
  config.command = surface->command;
  config.env_vars = surface->environment;
  config.env_var_count = surface->environment_count;
  surface->core = ghostty_surface_new(surface->app->core, &config);
}

static void on_unrealize(GtkGLArea *area, amx_ghostty_surface *surface) {
  if (surface->core == NULL) return;
  gtk_gl_area_make_current(area);
  ghostty_surface_free(surface->core);
  surface->core = NULL;
}

static gboolean on_render(GtkGLArea *area,
                          GdkGLContext *context,
                          amx_ghostty_surface *surface) {
  (void)area;
  (void)context;
  if (surface->core != NULL) ghostty_surface_draw(surface->core);
  return TRUE;
}

static void on_resize(GtkGLArea *area,
                      int width,
                      int height,
                      amx_ghostty_surface *surface) {
  (void)area;
  if (surface->core != NULL && width > 0 && height > 0) {
    ghostty_surface_set_size(surface->core, (uint32_t)width, (uint32_t)height);
  }
}

static void on_focus_enter(GtkEventControllerFocus *controller,
                           amx_ghostty_surface *surface) {
  (void)controller;
  if (surface->core != NULL) ghostty_surface_set_focus(surface->core, true);
  gtk_im_context_focus_in(surface->ime);
  if (surface->callbacks.focus_changed != NULL) {
    surface->callbacks.focus_changed(surface->callbacks.userdata, true);
  }
}

static void on_focus_leave(GtkEventControllerFocus *controller,
                           amx_ghostty_surface *surface) {
  (void)controller;
  if (surface->core != NULL) ghostty_surface_set_focus(surface->core, false);
  gtk_im_context_focus_out(surface->ime);
  if (surface->callbacks.focus_changed != NULL) {
    surface->callbacks.focus_changed(surface->callbacks.userdata, false);
  }
}

static void on_ime_commit(GtkIMContext *ime,
                          const char *text,
                          amx_ghostty_surface *surface) {
  (void)ime;
  if (surface->core != NULL && text != NULL) {
    ghostty_surface_text(surface->core, text, strlen(text));
  }
}

static void on_ime_preedit(GtkIMContext *ime,
                           amx_ghostty_surface *surface) {
  char *text = NULL;
  gtk_im_context_get_preedit_string(ime, &text, NULL, NULL);
  if (surface->core != NULL) {
    const size_t length = text == NULL ? 0 : strlen(text);
    ghostty_surface_preedit(surface->core, text == NULL ? "" : text, length);
  }
  g_free(text);
}

static ghostty_input_mods_e ghostty_modifiers(GdkModifierType state) {
  unsigned int result = GHOSTTY_MODS_NONE;
  if (state & GDK_SHIFT_MASK) result |= GHOSTTY_MODS_SHIFT;
  if (state & GDK_CONTROL_MASK) result |= GHOSTTY_MODS_CTRL;
  if (state & GDK_ALT_MASK) result |= GHOSTTY_MODS_ALT;
  if (state & GDK_SUPER_MASK) result |= GHOSTTY_MODS_SUPER;
  if (state & GDK_LOCK_MASK) result |= GHOSTTY_MODS_CAPS;
  return (ghostty_input_mods_e)result;
}

static gboolean process_key(GtkEventControllerKey *controller,
                            guint keyval,
                            guint keycode,
                            GdkModifierType state,
                            amx_ghostty_surface *surface) {
  GdkEvent *event = gtk_event_controller_get_current_event(GTK_EVENT_CONTROLLER(controller));
  if (event != NULL && gtk_im_context_filter_keypress(surface->ime, event)) return TRUE;
  if (surface->core == NULL || event == NULL) return FALSE;

  ghostty_input_key_s key = {
      .action = gdk_event_get_event_type(event) == GDK_KEY_RELEASE
          ? GHOSTTY_ACTION_RELEASE
          : GHOSTTY_ACTION_PRESS,
      .mods = ghostty_modifiers(state),
      .consumed_mods = GHOSTTY_MODS_NONE,
      .keycode = keycode,
      .text = NULL,
      .unshifted_codepoint = gdk_keyval_to_unicode(keyval),
      .composing = false,
  };
  return ghostty_surface_key(surface->core, key);
}

static gboolean on_key_pressed(GtkEventControllerKey *controller,
                               guint keyval,
                               guint keycode,
                               GdkModifierType state,
                               amx_ghostty_surface *surface) {
  return process_key(controller, keyval, keycode, state, surface);
}

static void on_key_released(GtkEventControllerKey *controller,
                            guint keyval,
                            guint keycode,
                            GdkModifierType state,
                            amx_ghostty_surface *surface) {
  (void)process_key(controller, keyval, keycode, state, surface);
}

static void on_motion(GtkEventControllerMotion *controller,
                      double x,
                      double y,
                      amx_ghostty_surface *surface) {
  GdkModifierType state = gtk_event_controller_get_current_event_state(GTK_EVENT_CONTROLLER(controller));
  if (surface->core != NULL) {
    ghostty_surface_mouse_pos(surface->core, x, y, ghostty_modifiers(state));
  }
}

static ghostty_input_mouse_button_e mouse_button(guint button) {
  switch (button) {
    case GDK_BUTTON_PRIMARY: return GHOSTTY_MOUSE_LEFT;
    case GDK_BUTTON_MIDDLE: return GHOSTTY_MOUSE_MIDDLE;
    case GDK_BUTTON_SECONDARY: return GHOSTTY_MOUSE_RIGHT;
    default: return GHOSTTY_MOUSE_UNKNOWN;
  }
}

static void on_pressed(GtkGestureClick *gesture,
                       int count,
                       double x,
                       double y,
                       amx_ghostty_surface *surface) {
  (void)count;
  if (surface->core != NULL) {
    ghostty_surface_mouse_pos(surface->core, x, y, GHOSTTY_MODS_NONE);
    ghostty_surface_mouse_button(
        surface->core,
        GHOSTTY_MOUSE_PRESS,
        mouse_button(gtk_gesture_single_get_current_button(GTK_GESTURE_SINGLE(gesture))),
        GHOSTTY_MODS_NONE);
  }
}

static void on_released(GtkGestureClick *gesture,
                        int count,
                        double x,
                        double y,
                        amx_ghostty_surface *surface) {
  (void)count;
  if (surface->core != NULL) {
    ghostty_surface_mouse_pos(surface->core, x, y, GHOSTTY_MODS_NONE);
    ghostty_surface_mouse_button(
        surface->core,
        GHOSTTY_MOUSE_RELEASE,
        mouse_button(gtk_gesture_single_get_current_button(GTK_GESTURE_SINGLE(gesture))),
        GHOSTTY_MODS_NONE);
  }
}

static gboolean on_scroll(GtkEventControllerScroll *controller,
                          double dx,
                          double dy,
                          amx_ghostty_surface *surface) {
  (void)controller;
  if (surface->core != NULL) ghostty_surface_mouse_scroll(surface->core, dx, dy, 0);
  return TRUE;
}

amx_ghostty_surface *amx_ghostty_surface_create(
    amx_ghostty_app *app,
    const char *working_directory,
    const char *command,
    amx_ghostty_callbacks callbacks) {
  return amx_ghostty_surface_create_with_environment(
      app, working_directory, command, NULL, 0, callbacks);
}

amx_ghostty_surface *amx_ghostty_surface_create_with_environment(
    amx_ghostty_app *app,
    const char *working_directory,
    const char *command,
    const amx_ghostty_env_var *environment,
    size_t environment_count,
    amx_ghostty_callbacks callbacks) {
  if (app == NULL || (environment_count > 0 && environment == NULL)) return NULL;
  amx_ghostty_surface *surface = calloc(1, sizeof(*surface));
  if (surface == NULL) return NULL;
  surface->app = app;
  surface->callbacks = callbacks;
  surface->working_directory = g_strdup(working_directory);
  surface->command = g_strdup(command);
  if (environment_count > 0) {
    surface->environment = calloc(environment_count, sizeof(*surface->environment));
    if (surface->environment == NULL) goto fail;
    surface->environment_count = environment_count;
    for (size_t index = 0; index < environment_count; index++) {
      surface->environment[index].key = g_strdup(environment[index].key);
      surface->environment[index].value = g_strdup(environment[index].value);
      if (surface->environment[index].key == NULL ||
          surface->environment[index].value == NULL) goto fail;
    }
  }
  surface->area = gtk_gl_area_new();
  if (surface->area == NULL) goto fail;
  g_object_ref_sink(surface->area);
  surface->ime = gtk_im_multicontext_new();

  gtk_gl_area_set_allowed_apis(GTK_GL_AREA(surface->area), GDK_GL_API_GL);
  gtk_gl_area_set_auto_render(GTK_GL_AREA(surface->area), false);
  gtk_gl_area_set_has_depth_buffer(GTK_GL_AREA(surface->area), false);
  gtk_gl_area_set_has_stencil_buffer(GTK_GL_AREA(surface->area), false);
  gtk_widget_set_focusable(surface->area, true);
  gtk_widget_set_hexpand(surface->area, true);
  gtk_widget_set_vexpand(surface->area, true);
  gtk_im_context_set_client_widget(surface->ime, surface->area);

  g_signal_connect(surface->area, "realize", G_CALLBACK(on_realize), surface);
  g_signal_connect(surface->area, "unrealize", G_CALLBACK(on_unrealize), surface);
  g_signal_connect(surface->area, "render", G_CALLBACK(on_render), surface);
  g_signal_connect(surface->area, "resize", G_CALLBACK(on_resize), surface);
  g_signal_connect(surface->ime, "commit", G_CALLBACK(on_ime_commit), surface);
  g_signal_connect(surface->ime, "preedit-changed", G_CALLBACK(on_ime_preedit), surface);

  GtkEventController *focus = gtk_event_controller_focus_new();
  g_signal_connect(focus, "enter", G_CALLBACK(on_focus_enter), surface);
  g_signal_connect(focus, "leave", G_CALLBACK(on_focus_leave), surface);
  gtk_widget_add_controller(surface->area, focus);

  GtkEventController *key = gtk_event_controller_key_new();
  g_signal_connect(key, "key-pressed", G_CALLBACK(on_key_pressed), surface);
  g_signal_connect(key, "key-released", G_CALLBACK(on_key_released), surface);
  gtk_widget_add_controller(surface->area, key);

  GtkEventController *motion = gtk_event_controller_motion_new();
  g_signal_connect(motion, "motion", G_CALLBACK(on_motion), surface);
  gtk_widget_add_controller(surface->area, motion);

  GtkGesture *click = gtk_gesture_click_new();
  gtk_gesture_single_set_button(GTK_GESTURE_SINGLE(click), 0);
  g_signal_connect(click, "pressed", G_CALLBACK(on_pressed), surface);
  g_signal_connect(click, "released", G_CALLBACK(on_released), surface);
  gtk_widget_add_controller(surface->area, GTK_EVENT_CONTROLLER(click));

  GtkEventController *scroll = gtk_event_controller_scroll_new(
      GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES |
      GTK_EVENT_CONTROLLER_SCROLL_KINETIC);
  g_signal_connect(scroll, "scroll", G_CALLBACK(on_scroll), surface);
  gtk_widget_add_controller(surface->area, scroll);

  return surface;

fail:
  finalize_surface(surface);
  return NULL;
}

void amx_ghostty_surface_destroy(amx_ghostty_surface *surface) {
  if (surface == NULL) return;
  surface->destroying = true;
  if (surface->core != NULL) {
    gtk_gl_area_make_current(GTK_GL_AREA(surface->area));
    ghostty_surface_free(surface->core);
    surface->core = NULL;
  }
  g_signal_handlers_disconnect_by_data(surface->area, surface);
  gtk_im_context_set_client_widget(surface->ime, NULL);
  GtkWidget *parent = gtk_widget_get_parent(surface->area);
  if (parent != NULL) gtk_widget_unparent(surface->area);
  g_object_unref(surface->ime);
  g_object_unref(surface->area);
  if (surface->pending_clipboard_reads == 0) finalize_surface(surface);
}

static void finalize_surface(amx_ghostty_surface *surface) {
  g_clear_pointer(&surface->working_directory, g_free);
  g_clear_pointer(&surface->command, g_free);
  for (size_t index = 0; index < surface->environment_count; index++) {
    g_free((void *)surface->environment[index].key);
    g_free((void *)surface->environment[index].value);
  }
  g_clear_pointer(&surface->environment, free);
  free(surface);
}

void *amx_ghostty_surface_widget(amx_ghostty_surface *surface) {
  return surface == NULL ? NULL : surface->area;
}

void amx_ghostty_surface_set_accessible_label(
    amx_ghostty_surface *surface,
    const char *label,
    const char *description) {
  if (surface == NULL) return;
  gtk_accessible_update_property(
      GTK_ACCESSIBLE(surface->area),
      GTK_ACCESSIBLE_PROPERTY_LABEL, label,
      GTK_ACCESSIBLE_PROPERTY_DESCRIPTION, description,
      -1);
}

void amx_ghostty_surface_focus(amx_ghostty_surface *surface) {
  if (surface != NULL) gtk_widget_grab_focus(surface->area);
}

bool amx_ghostty_surface_is_ready(amx_ghostty_surface *surface) {
  return surface != NULL && surface->core != NULL;
}

bool amx_ghostty_surface_process_exited(amx_ghostty_surface *surface) {
  return surface == NULL || surface->core == NULL ||
      ghostty_surface_process_exited(surface->core);
}

bool amx_ghostty_surface_has_seen_prompt(amx_ghostty_surface *surface) {
  return surface != NULL && surface->core != NULL &&
      ghostty_surface_has_seen_prompt(surface->core);
}

bool amx_ghostty_surface_needs_confirm_quit(amx_ghostty_surface *surface) {
  return surface != NULL && surface->core != NULL &&
      ghostty_surface_needs_confirm_quit(surface->core);
}

uint64_t amx_ghostty_surface_foreground_process_id(
    amx_ghostty_surface *surface) {
  if (surface == NULL || surface->core == NULL) return 0;
  return ghostty_surface_foreground_pid(surface->core);
}

bool amx_ghostty_surface_binding_action(amx_ghostty_surface *surface,
                                        const char *action) {
  return surface != NULL && surface->core != NULL && action != NULL &&
      ghostty_surface_binding_action(surface->core, action, strlen(action));
}

void amx_ghostty_surface_request_close(amx_ghostty_surface *surface) {
  if (surface != NULL && surface->core != NULL) {
    ghostty_surface_request_close(surface->core);
  }
}

void amx_ghostty_surface_send_enter(amx_ghostty_surface *surface) {
  if (surface == NULL || surface->core == NULL) return;
  ghostty_input_key_s key = {
      .action = GHOSTTY_ACTION_PRESS,
      .mods = GHOSTTY_MODS_NONE,
      .consumed_mods = GHOSTTY_MODS_NONE,
      .keycode = 0x24,
      .text = "\r",
      .unshifted_codepoint = '\r',
      .composing = false,
  };
  ghostty_surface_key(surface->core, key);
  key.action = GHOSTTY_ACTION_RELEASE;
  key.text = NULL;
  ghostty_surface_key(surface->core, key);
}

void amx_ghostty_surface_send_text(amx_ghostty_surface *surface,
                                   const char *utf8,
                                   uint64_t length) {
  if (surface != NULL && surface->core != NULL && utf8 != NULL) {
    ghostty_surface_text(surface->core, utf8, length);
  }
}
