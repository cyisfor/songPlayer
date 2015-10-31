#include "pq.h"
#include "preparation.h"

extern const char gladeFile[];
extern long unsigned int gladeFileSize;

#include <gtk/gtk.h>
#include <glib.h>

#include <arpa/inet.h> // ntohl
#include <error.h>
#include <assert.h>
#include <fcntl.h>
#include <errno.h>

#include <stdint.h>
#include <string.h>

static int getsqlpid(uint16_t who) {
  const char* values[1];
  int lengths[1];
  int fmt[1];
  values[0] = (const char*) &who;
  lengths[0] = sizeof(who); 
  fmt[0] = 1;

  PGresult* result = PQexecPrepared
    (
     PQconn,
     "getpid",
     1,
     values,
     lengths,fmt,1);
     
  assert(PQntuples(result)==1);
  uint32_t pid = (uint32_t)ntohl(*((uint32_t*)PQgetvalue(result,0,0)));
  PQclear(result);
  return pid;
}

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

  preparation_t queries[] = {
    { "getpid",
      "select pid from pids where id = $1::smallint"
    }
  };
  PQinit();
  prepareQueries(queries);

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
