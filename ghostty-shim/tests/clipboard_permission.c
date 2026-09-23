/* Synthetic clipboard permission coverage for the private callback boundary. */
#include "../src/awesomux_ghostty.c"

#include <assert.h>

typedef struct {
  uint64_t requested;
  uint64_t cancelled;
  size_t byte_count;
  unsigned requests;
  unsigned cancellations;
} observation;

static void permission_requested(void *userdata, uint64_t id,
                                 amx_ghostty_permission_kind kind,
                                 size_t characters, size_t bytes) {
  observation *seen = userdata;
  assert(kind == AMX_GHOSTTY_PERMISSION_CLIPBOARD_WRITE);
  assert(characters == bytes);
  seen->requested = id;
  seen->byte_count = bytes;
  seen->requests++;
}

static void permission_cancelled(void *userdata, uint64_t id) {
  observation *seen = userdata;
  seen->cancelled = id;
  seen->cancellations++;
}

typedef struct { char *text; bool done; } read_result;

static void read_finished(GObject *source, GAsyncResult *result, void *userdata) {
  read_result *read = userdata;
  read->text = gdk_clipboard_read_text_finish(GDK_CLIPBOARD(source), result, NULL);
  read->done = true;
}

static void expect_clipboard(GdkClipboard *clipboard, const char *expected) {
  read_result read = {0};
  gdk_clipboard_read_text_async(clipboard, NULL, read_finished, &read);
  while (!read.done) g_main_context_iteration(NULL, TRUE);
  assert(read.text != NULL && strcmp(read.text, expected) == 0);
  g_free(read.text);
}

int main(void) {
  gtk_init();
  GtkWidget *window = gtk_window_new();
  gtk_window_present(GTK_WINDOW(window));
  GdkClipboard *clipboard = gdk_display_get_clipboard(gtk_widget_get_display(window));
  observation seen = {0};
  amx_ghostty_surface surface = {
      .area = window,
      .callbacks = {.userdata = &seen,
                    .permission_requested = permission_requested,
                    .permission_cancelled = permission_cancelled},
  };
  gdk_clipboard_set_text(clipboard, "original");
  ghostty_clipboard_content_s first = {.mime = "text/plain", .data = "synthetic-one", .len = 13};
  ghostty_clipboard_content_s second = {.mime = "text/plain", .data = "synthetic-two", .len = 13};

  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &first, 1, true);
  assert(seen.requests == 1 && seen.byte_count == first.len);
  const uint64_t cancelled_id = seen.requested;
  expect_clipboard(clipboard, "original");
  assert(amx_ghostty_surface_resolve_permission(&surface, cancelled_id, false));
  expect_clipboard(clipboard, "original");
  assert(!amx_ghostty_surface_resolve_permission(&surface, cancelled_id, true));

  const unsigned requests_before_invalid = seen.requests;
  ghostty_clipboard_content_s oversized = {
      .mime = "text/plain", .data = "x",
      .len = MAX_PENDING_CLIPBOARD_WRITE_BYTES + 1};
  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &oversized, 1, true);
  const char invalid_utf8[] = {(char)0xff};
  ghostty_clipboard_content_s malformed = {
      .mime = "text/plain", .data = invalid_utf8, .len = sizeof(invalid_utf8)};
  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &malformed, 1, true);
  assert(seen.requests == requests_before_invalid);
  expect_clipboard(clipboard, "original");

  char *at_limit = g_malloc(MAX_PENDING_CLIPBOARD_WRITE_BYTES + 1);
  memset(at_limit, 'a', MAX_PENDING_CLIPBOARD_WRITE_BYTES);
  at_limit[MAX_PENDING_CLIPBOARD_WRITE_BYTES] = '\0';
  ghostty_clipboard_content_s bounded = {
      .mime = "text/plain", .data = at_limit,
      .len = MAX_PENDING_CLIPBOARD_WRITE_BYTES};
  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &bounded, 1, true);
  assert(seen.requests == requests_before_invalid + 1);
  assert(seen.byte_count == MAX_PENDING_CLIPBOARD_WRITE_BYTES);
  assert(amx_ghostty_surface_resolve_permission(&surface, seen.requested, false));
  g_free(at_limit);
  expect_clipboard(clipboard, "original");

  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &first, 1, true);
  const uint64_t replaced_id = seen.requested;
  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &second, 1, true);
  assert(seen.cancelled == replaced_id && seen.cancellations == 1);
  assert(!amx_ghostty_surface_resolve_permission(&surface, replaced_id, true));
  expect_clipboard(clipboard, "original");
  assert(amx_ghostty_surface_resolve_permission(&surface, seen.requested, true));
  expect_clipboard(clipboard, "synthetic-two");

  write_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD, &first, 1, false);
  expect_clipboard(clipboard, "synthetic-one");
  amx_ghostty_surface *retiring = calloc(1, sizeof(*retiring));
  assert(retiring != NULL);
  retiring->area = gtk_gl_area_new();
  g_object_ref_sink(retiring->area);
  retiring->ime = gtk_im_multicontext_new();
  retiring->callbacks = surface.callbacks;
  write_clipboard(retiring, GHOSTTY_CLIPBOARD_STANDARD, &second, 1, true);
  const uint64_t teardown_id = seen.requested;
  amx_ghostty_surface_destroy(retiring);
  assert(seen.cancelled == teardown_id && seen.cancellations == 2);
  assert(!amx_ghostty_surface_resolve_permission(&surface, teardown_id, true));
  expect_clipboard(clipboard, "synthetic-one");
  gtk_window_destroy(GTK_WINDOW(window));
  puts("clipboard permission: synthetic ask, approve, deny, replacement, and teardown passed");
  return 0;
}
