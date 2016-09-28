#include "pause-common.h"
#include "get_pid.h"

gboolean pause_toggle(GtkWidget* top, GdkEventButton* e, struct pause_toggle_state* self) {
	if(e->button > 1) return FALSE;
  int pid = get_pid("player",sizeof("player")-1);
	if(self->stopped) {
		kill(pid,SIGCONT);
		self->stopped = false;
		gtk_image_set_from_icon_name(self->image, "gtk-stop", GTK_ICON_SIZE_LARGE_TOOLBAR);
		gtk_widget_set_tooltip_text(top, "Pause");
	} else {
		//printf("stop %d\n",pid);
		kill(pid, SIGSTOP);
		self->stopped = true;
		gtk_image_set_from_icon_name(self->image, "gtk-media-play", GTK_ICON_SIZE_LARGE_TOOLBAR);
		gtk_widget_set_tooltip_text(top, "Play");
	}
	return TRUE;
}
