#include "pause-common.h"
#include "get_pid.h"

gboolean pause_toggle(GtkWidget* top, GdkEventButton* e, struct pause_toggle_state* self) {
	if(e->button > 1) return FALSE;
	g_warning("derp");
  int pid = get_pid("player",sizeof("player")-1);
	if(self->paused) {
		kill(pid,SIGCONT);
		self->paused = false;
		gtk_image_set_from_stock(self->image, "gtk-media-stop", GTK_ICON_SIZE_SMALL_TOOLBAR);
		gtk_widget_set_tooltip_text(top, "Pause");
	} else {
		//printf("stop %d\n",pid);
		kill(pid, SIGSTOP);
		self->paused = true;
		gtk_image_set_from_stock(self->image, "gtk-media-play", GTK_ICON_SIZE_SMALL_TOOLBAR);
		gtk_widget_set_tooltip_text(top, "Play");
	}
	return TRUE;
}
