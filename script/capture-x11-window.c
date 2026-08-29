#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static Window find_named_window(Display *display, Window parent, const char *needle) {
  char *name = NULL;
  if (XFetchName(display, parent, &name) != 0 && name != NULL) {
    const int matches = strstr(name, needle) != NULL;
    XFree(name);
    if (matches) return parent;
  }

  Window root = 0;
  Window ignored_parent = 0;
  Window *children = NULL;
  unsigned int child_count = 0;
  if (XQueryTree(display, parent, &root, &ignored_parent, &children, &child_count) == 0) {
    return 0;
  }
  for (unsigned int index = 0; index < child_count; index++) {
    const Window match = find_named_window(display, children[index], needle);
    if (match != 0) {
      XFree(children);
      return match;
    }
  }
  if (children != NULL) XFree(children);
  return 0;
}

static unsigned char component(unsigned long pixel, unsigned long mask) {
  if (mask == 0) return 0;
  unsigned int shift = 0;
  while (((mask >> shift) & 1UL) == 0) shift++;
  const unsigned long maximum = mask >> shift;
  return (unsigned char)((((pixel & mask) >> shift) * 255UL) / maximum);
}

int main(int argc, char **argv) {
  if (argc != 3 && argc != 7) {
    fprintf(stderr, "usage: capture-x11-window WINDOW_NAME OUTPUT.png [X Y WIDTH HEIGHT]\n");
    return 2;
  }
  Display *display = XOpenDisplay(NULL);
  if (display == NULL) return 3;
  const Window window = find_named_window(display, DefaultRootWindow(display), argv[1]);
  if (window == 0) {
    XCloseDisplay(display);
    return 4;
  }

  XWindowAttributes attributes;
  if (XGetWindowAttributes(display, window, &attributes) == 0) return 5;
  const int crop_x = argc == 7 ? atoi(argv[3]) : 0;
  const int crop_y = argc == 7 ? atoi(argv[4]) : 0;
  const int crop_width = argc == 7 ? atoi(argv[5]) : attributes.width;
  const int crop_height = argc == 7 ? atoi(argv[6]) : attributes.height;
  if (crop_x < 0 || crop_y < 0 || crop_width <= 0 || crop_height <= 0 ||
      crop_x + crop_width > attributes.width ||
      crop_y + crop_height > attributes.height) return 9;

  /* Rootless XWayland can retain only the most recently damaged portions of
     a GTK surface. Request and wait for one complete expose before reading it
     so visual-QA captures do not preserve transparent/black damage holes. */
  XClearArea(display, window, crop_x, crop_y,
             (unsigned int)crop_width, (unsigned int)crop_height, True);
  XSync(display, False);
  sleep(1);

  XImage *image = XGetImage(display, window, crop_x, crop_y,
                           (unsigned int)crop_width,
                           (unsigned int)crop_height,
                           AllPlanes, ZPixmap);
  if (image == NULL) return 6;

  GdkPixbuf *pixbuf = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8,
                                     crop_width, crop_height);
  if (pixbuf == NULL) return 7;
  guchar *pixels = gdk_pixbuf_get_pixels(pixbuf);
  const int stride = gdk_pixbuf_get_rowstride(pixbuf);
  for (int y = 0; y < crop_height; y++) {
    guchar *row = pixels + (y * stride);
    for (int x = 0; x < crop_width; x++) {
      const unsigned long pixel = XGetPixel(image, x, y);
      row[(x * 4) + 0] = component(pixel, image->red_mask);
      row[(x * 4) + 1] = component(pixel, image->green_mask);
      row[(x * 4) + 2] = component(pixel, image->blue_mask);
      row[(x * 4) + 3] = 255;
    }
  }

  GError *error = NULL;
  const gboolean saved = gdk_pixbuf_save(pixbuf, argv[2], "png", &error, NULL);
  if (!saved && error != NULL) fprintf(stderr, "%s\n", error->message);
  g_clear_error(&error);
  g_object_unref(pixbuf);
  XDestroyImage(image);
  XCloseDisplay(display);
  return saved ? 0 : 8;
}
