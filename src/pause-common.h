#include <gtk/gtk.h>

struct pause_toggle_state {
	GtkImage* image;
	gboolean paused;
};

gboolean pause_toggle(GtkWidget* top, GdkEventButton* e, struct pause_toggle_state* pts);
