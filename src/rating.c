#include "rating.h"
#include "pq.h"
#include "get_pid.h"

#include <signal.h> // SIGSTUFF


void rating_init(void) {
	get_pid_init();
}

void do_rating(const char* rating) {
	const char* values[] = { rating };
	const int lengths[] = { strlen(rating) };
	const int fmt[] = { 0 };
	PQclear(PQexecParams(PQconn,"SELECT connectionStrength(id, \n"
						 "(SELECT song FROM recordings WHERE id = (\n"
						 "SELECT recording from queue order by id limit 1)), "
						 "$1) FROM mode",
						 1,NULL,values,lengths,fmt,0));
  if(atoi(rating)>0) return 0;
  if(getenv("nonext")) return 0;

  int pid = get_pid("player",sizeof("player")-1);
  if(pid > 0)
	kill(pid,SIGUSR1);
	
}
