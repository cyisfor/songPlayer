#include "pq.h"
#include "preparation.h"

extern const char gladeFile[];
extern long unsigned int gladeFileSize;

#include <gtk/gtk.h>
#include <glib.h>

#include <stdint.h>
#include <string.h>

static int getpid(uint8_t who) {
  const char* values[] = { { who } };
    const int lengths[] = { 1 };
    const int fmt[] = { 1 };

    PGresult* result = PQexecParams(PQconn,"getpid",1,NULL,values,lengths,fmt,1);
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
  case EACCESS:
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
      "select pid::int4 from pids where id = $1"
    }            
  };
  PQinit();
  prepareQueries(queries);
    
  gtk_init(NULL,NULL);

  GtkBuilder* builder = gtk_builder_new_from_string(gladeFile,gladeFileSize);
  GtkWidget* top = GTK_WIDGET(gtk_builder_get_object(builder,"top"));

  player_pid = getpid(0);
  kill(player_pid, SIGSTOP);
  g_signal_connect(G_OBJECT(top),"clicked",G_CALLBACK(unpause));
  gtk_main();
}
