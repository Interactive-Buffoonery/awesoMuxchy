#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
  if (argc != 3) {
    fprintf(stderr, "usage: capture-x11-window WINDOW_NAME OUTPUT.png\n");
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
  XImage *image = XGetImage(display, window, 0, 0,
                           (unsigned int)attributes.width,
                           (unsigned int)attributes.height,
                           AllPlanes, ZPixmap);
  if (image == NULL) return 6;

  GdkPixbuf *pixbuf = gdk_pixbuf_new(GDK_COLORSPACE_RGB, TRUE, 8,
                                     attributes.width, attributes.height);
  if (pixbuf == NULL) return 7;
  guchar *pixels = gdk_pixbuf_get_pixels(pixbuf);
  const int stride = gdk_pixbuf_get_rowstride(pixbuf);
  for (int y = 0; y < attributes.height; y++) {
    guchar *row = pixels + (y * stride);
    for (int x = 0; x < attributes.width; x++) {
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
