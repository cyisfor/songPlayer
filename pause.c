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
  int pid = get_pid("player",sizeof("player")-1);
  if(pid < 0) return 1;
	
  gtk_init(NULL,NULL);

  GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFile_length);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));
	GtkImage* image = GTK_IMAGE(gtk_builder_get_object(builder,"image"));
  gtk_window_stick(GTK_WINDOW(top));
  gtk_window_set_keep_above(GTK_WINDOW(top),TRUE);

	bool stopped = false;
	static void toggle(GtkWidget* top, GdkEventButton* e, gpointer udata) {
		if(e->state & GDK_CONTROL_MASK) {
			gtk_window_begin_move_drag(GTK_WINDOW(top), e->button, e->x_root, e->y_root, e->time);
			return;
		}
		if(stopped) {
			kill(pid,SIGCONT);
			stopped = false;
			gtk_image_set_from_stock(image, "gtk-stop", GTK_ICON_SIZE_BUTTON);
		} else {
			//printf("stop %d\n",pid);
			kill(pid, SIGSTOP);
			stopped = true;
			gtk_image_set_from_stock(image, "gtk-media-play", GTK_ICON_SIZE_BUTTON);
		}
	}

  g_signal_connect(G_OBJECT(top),"button-release-event",G_CALLBACK(toggle),NULL);
	
  gtk_widget_show_all(top);
  gtk_main();
}
