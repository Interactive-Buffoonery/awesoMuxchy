/* Synthetic clipboard permission coverage for the private callback boundary. */
#define ghostty_surface_complete_clipboard_request test_complete_clipboard_request
#define ghostty_surface_deny_clipboard_request test_deny_clipboard_request
#include "../src/awesomux_ghostty.c"

#include <assert.h>

static unsigned paste_completions;
static unsigned paste_denials;
static bool paste_confirmed;
static size_t last_available_count;
static char pasted_data[128];
void test_complete_clipboard_request(ghostty_surface_t core,
                                     const ghostty_clipboard_complete_s *completion,
                                     void *request) {
  (void)core;
  assert(request != NULL && completion->contents_len <= 1);
  if (completion->contents_len == 1) {
    assert(completion->contents[0].len < sizeof(pasted_data));
    memcpy(pasted_data, completion->contents[0].data, completion->contents[0].len);
    pasted_data[completion->contents[0].len] = 0;
  }
  last_available_count = completion->available_len;
  paste_confirmed = completion->confirmed;
  paste_completions++;
}
void test_deny_clipboard_request(ghostty_surface_t core, void *request) {
  (void)core;
  assert(request != NULL);
  paste_denials++;
}

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
  assert(kind == AMX_GHOSTTY_PERMISSION_CLIPBOARD_WRITE ||
         kind == AMX_GHOSTTY_PERMISSION_UNSAFE_PASTE);
  assert(characters <= bytes);
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

  /* Ghostty owns unsafe classification. This callback must keep its borrowed
   * fixture until explicit approval and reject stale/replaced requests. */
  surface.core = (ghostty_surface_t)&surface;
  const unsigned ordinary_before = paste_completions;
  int ordinary_request;
  assert(read_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD,
                        &ordinary_request, NULL, 0, false) ==
         GHOSTTY_CLIPBOARD_READ_STARTED);
  while (paste_completions == ordinary_before) g_main_context_iteration(NULL, TRUE);
  assert(!paste_confirmed && strcmp(pasted_data, "synthetic-one") == 0);
  const unsigned before_list_read = paste_completions;
  int ordinary_list_request;
  assert(read_clipboard(&surface, GHOSTTY_CLIPBOARD_STANDARD,
                        &ordinary_list_request, NULL, 0, true) ==
         GHOSTTY_CLIPBOARD_READ_STARTED);
  while (paste_completions == before_list_read) g_main_context_iteration(NULL, TRUE);
  assert(!paste_confirmed && last_available_count == 1);
  const unsigned confirmation_before = paste_completions;
  char unsafe_text[] = "printf safe\\n\n";
  ghostty_clipboard_content_s unsafe_content = {
      .mime = "text/plain", .data = unsafe_text, .len = strlen(unsafe_text)};
  ghostty_clipboard_confirm_s unsafe = {
      .contents = &unsafe_content, .contents_len = 1};
  int request_one, request_two, request_three;
  confirm_read_clipboard(&surface, &unsafe, &request_one,
                         GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  const uint64_t first_paste_id = seen.requested;
  assert(paste_completions == confirmation_before && paste_denials == 0);
  strcpy(unsafe_text, "overwritten");
  assert(amx_ghostty_surface_resolve_permission(&surface, first_paste_id, false));
  assert(paste_denials == 1 && paste_completions == confirmation_before);
  assert(!amx_ghostty_surface_resolve_permission(&surface, first_paste_id, true));

  ghostty_clipboard_content_s oversized_paste = {
      .mime = "text/plain", .data = "x",
      .len = MAX_PENDING_CLIPBOARD_WRITE_BYTES + 1};
  ghostty_clipboard_confirm_s oversized_confirmation = {
      .contents = &oversized_paste, .contents_len = 1};
  confirm_read_clipboard(&surface, &oversized_confirmation, &request_three,
                         GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  assert(paste_denials == 2 && paste_completions == confirmation_before);
  char *bounded_paste = g_malloc(MAX_PENDING_CLIPBOARD_WRITE_BYTES);
  memset(bounded_paste, 'a', MAX_PENDING_CLIPBOARD_WRITE_BYTES);
  ghostty_clipboard_content_s bounded_paste_content = {
      .mime = "text/plain", .data = bounded_paste,
      .len = MAX_PENDING_CLIPBOARD_WRITE_BYTES};
  ghostty_clipboard_confirm_s bounded_paste_confirmation = {
      .contents = &bounded_paste_content, .contents_len = 1};
  confirm_read_clipboard(&surface, &bounded_paste_confirmation,
                         &request_three, GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  assert(seen.byte_count == MAX_PENDING_CLIPBOARD_WRITE_BYTES);
  assert(amx_ghostty_surface_resolve_permission(&surface, seen.requested, false));
  g_free(bounded_paste);

  confirm_read_clipboard(&surface, &unsafe, &request_one,
                         GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  const uint64_t replaced_paste_id = seen.requested;
  char bracket_escape[] = "safe\x1b[201~";
  ghostty_clipboard_content_s bracket_content = {
      .mime = "text/plain", .data = bracket_escape,
      .len = strlen(bracket_escape)};
  ghostty_clipboard_confirm_s bracket_confirmation = {
      .contents = &bracket_content, .contents_len = 1};
  confirm_read_clipboard(&surface, &bracket_confirmation, &request_two,
                         GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  assert(paste_denials == 4 && seen.cancelled == replaced_paste_id);
  assert(!amx_ghostty_surface_resolve_permission(&surface, replaced_paste_id, true));
  assert(amx_ghostty_surface_resolve_permission(&surface, seen.requested, true));
  assert(paste_completions == confirmation_before + 1 && paste_confirmed);
  assert(strcmp(pasted_data, bracket_escape) == 0);

  const char *available[] = {"text/plain"};
  ghostty_clipboard_confirm_s list = {
      .available = available, .available_len = 1};
  const unsigned events_before_list = seen.requests;
  const unsigned completions_before_list = paste_completions;
  const unsigned denials_before_list = paste_denials;
  confirm_read_clipboard(&surface, &list, &request_three,
                         GHOSTTY_CLIPBOARD_REQUEST_LIST);
  assert(paste_denials == denials_before_list + 1 &&
         paste_completions == completions_before_list &&
         seen.requests == events_before_list);
  const unsigned requests_before_unsupported = seen.requests;
  const unsigned denials_before_unsupported = paste_denials;
  confirm_read_clipboard(&surface, &unsafe, &request_one,
                         GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ);
  assert(paste_denials == denials_before_unsupported + 1 &&
         seen.requests == requests_before_unsupported);
  confirm_read_clipboard(&surface, &unsafe, &request_three,
                         GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  const uint64_t teardown_paste_id = seen.requested;
  const unsigned denials_before_teardown = paste_denials;
  cancel_pending_permission(&surface); /* Called by unrealize and destroy. */
  assert(paste_denials == denials_before_teardown + 1);
  assert(!amx_ghostty_surface_resolve_permission(&surface, teardown_paste_id, true));
  surface.core = NULL;
  amx_ghostty_surface *retiring = calloc(1, sizeof(*retiring));
  assert(retiring != NULL);
  retiring->area = gtk_gl_area_new();
  g_object_ref_sink(retiring->area);
  retiring->ime = gtk_im_multicontext_new();
  retiring->callbacks = surface.callbacks;
  const unsigned cancellations_before_teardown = seen.cancellations;
  write_clipboard(retiring, GHOSTTY_CLIPBOARD_STANDARD, &second, 1, true);
  const uint64_t teardown_id = seen.requested;
  amx_ghostty_surface_destroy(retiring);
  assert(seen.cancelled == teardown_id &&
         seen.cancellations == cancellations_before_teardown + 1);
  assert(!amx_ghostty_surface_resolve_permission(&surface, teardown_id, true));
  expect_clipboard(clipboard, "synthetic-one");
  amx_ghostty_surface *retiring_paste = calloc(1, sizeof(*retiring_paste));
  assert(retiring_paste != NULL);
  retiring_paste->area = gtk_gl_area_new();
  g_object_ref_sink(retiring_paste->area);
  retiring_paste->ime = gtk_im_multicontext_new();
  retiring_paste->callbacks = surface.callbacks;
  retiring_paste->core = (ghostty_surface_t)retiring_paste;
  confirm_read_clipboard(retiring_paste, &unsafe, &request_one,
                         GHOSTTY_CLIPBOARD_REQUEST_PASTE);
  const uint64_t destroyed_paste_id = seen.requested;
  retiring_paste->core = NULL; /* Simulate Ghostty core release before host cleanup. */
  const unsigned cancellations_before_paste_destroy = seen.cancellations;
  amx_ghostty_surface_destroy(retiring_paste);
  assert(seen.cancelled == destroyed_paste_id &&
         seen.cancellations == cancellations_before_paste_destroy + 1);
  assert(!amx_ghostty_surface_resolve_permission(&surface, destroyed_paste_id, true));
  gtk_window_destroy(GTK_WINDOW(window));
  puts("clipboard permission: ordinary text/MIME-list reads, bounded writes, PASTE approval/denial, unexpected LIST denial, replacement, stale IDs, and teardown passed");
  return 0;
}
