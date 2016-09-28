#include <gtk/gtk.h>

struct pause_toggle_stuff {
	GtkImage* image;
	gboolean paused;
} *pts;

gboolean pause_toggle(GtkWidget* top, GdkEventButton* e, pts pts);
