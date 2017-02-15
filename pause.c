#include "pq.h"
#include "preparation.h"
#include "get_pid.h"
#include "o/pause.glade.ch"
#include "config.h"

#include <gtk/gtk.h>
#include <glib.h>

#include <arpa/inet.h> // ntohl
#include <error.h>
#include <assert.h>
#include <fcntl.h>
#include <errno.h>

#include <stdint.h>
#include <string.h>

int main(void) {
  configInit();
  if(!declare_pid("pauser")) {
	puts("already pausing");
	return 1;
  }
	
  gtk_init(NULL,NULL);

  GtkBuilder* builder = gtk_builder_new_from_string((gchar*)gladeFile,gladeFile_length);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));
	GtkImage* image = GTK_IMAGE(gtk_builder_get_object(builder,"image"));
  gtk_window_stick(GTK_WINDOW(top));
  gtk_window_set_keep_above(GTK_WINDOW(top),TRUE);

	bool stopped = false;
	gboolean toggle() {
		int pid = get_pid("player",sizeof("player")-1);
		if(pid < 0) {
			g_timeout_add_seconds(10,toggle,NULL);
			return G_SOURCE_REMOVE;
		}
		if(stopped) {
			fputs("starting player ",stdout);
			kill(pid,SIGCONT);
			stopped = false;
			gtk_image_set_from_icon_name(image, "gtk-stop", GTK_ICON_SIZE_LARGE_TOOLBAR);
			gtk_widget_set_tooltip_text(top, "Pause");
		} else {
			fputs("stopping player ",stdout);
			kill(pid, SIGSTOP);
			stopped = true;
			gtk_image_set_from_icon_name(image, "gtk-media-play", GTK_ICON_SIZE_LARGE_TOOLBAR);
			gtk_widget_set_tooltip_text(top, "Play");
		}
		printf("%d\n",pid);
	}
	
	gboolean onkey(GtkWidget* top, GdkEventButton* e, gpointer udata) {
		if(e->state & GDK_CONTROL_MASK) {
			gtk_window_begin_move_drag(GTK_WINDOW(top), e->button, e->x_root, e->y_root, e->time);
			return FALSE;
		}
		if(e->state & GDK_SHIFT_MASK) {
			gtk_main_quit();
			return TRUE;
		}
		toggle(NULL);
		return TRUE;
	}

#if INITAL_DRAG
	gulong first_configure = 0;
	gboolean drag_it(GtkWidget* top, GdkEventConfigure* e, gpointer udata) {
		gtk_window_begin_move_drag(GTK_WINDOW(top), 0, e->x, e->y, time(NULL));
		g_signal_handler_disconnect(top, first_configure);
		return FALSE;
	}
	first_configure = g_signal_connect(G_OBJECT(top),"configure-event",G_CALLBACK(drag_it),NULL);
#else
	// just edit the source to configure
	gtk_window_move(GTK_WINDOW(top),0,300-32);
#endif
  g_signal_connect(G_OBJECT(top),"button-release-event",G_CALLBACK(onkey),NULL);
	
  gtk_widget_show_all(top);
  gtk_main();
}
