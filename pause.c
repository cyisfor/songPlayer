#include "pq.h"
#include "preparation.h"
#include "o/pause.glade.ch"

#include <gtk/gtk.h>
#include <glib.h>

#include <arpa/inet.h> // ntohl
#include <error.h>
#include <assert.h>
#include <fcntl.h>
#include <errno.h>

#include <stdint.h>
#include <string.h>

static void dolock(void) {
  int fd = open("/tmp/pauser.lock", O_WRONLY|O_CREAT,0600);
  if(fd < 0) error(1,0,"Lock wouldn't open.");
  struct flock lock = {
    .l_type = F_WRLCK,
  };
  if(-1 != fcntl(fd,F_SETLK,&lock)) return;
  switch(errno) {
  case EACCES:
  case EAGAIN:
    exit(2);
  default:
    error(3,errno,"Couldn't set a lock.");
  };
}

int player_pid = -1;

static void unpause(GtkWidget* top, void* nothing) {
  kill(player_pid,SIGCONT);
  exit(0);
}

int main(void) {
  dolock();

  PQinit();
  player_pid_init();
  gtk_init(NULL,NULL);

  GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFileSize);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));

  gtk_window_stick(GTK_WINDOW(top));
  gtk_window_set_keep_above(GTK_WINDOW(top),TRUE);
  player_pid = getsqlpid(0);
  kill(player_pid, SIGSTOP);
  g_signal_connect(G_OBJECT(top),"button-release-event",G_CALLBACK(unpause),NULL);
  gtk_widget_show_all(top);
  gtk_main();
}
