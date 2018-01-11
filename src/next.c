#include "pq.h"
#include "config.h"
#include "get_pid.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int main(void) {
  PQinit();
  configInit();
  
  const char* rating = getenv("rating");
  assert(rating!=NULL);

  const char* values[] = { rating };
  const int lengths[] = { strlen(rating) };
  const int fmt[] = { 0 };
  PQclear(PQexecParams(PQconn,"SELECT connectionStrength(id, \
(SELECT song FROM recordings WHERE id = (SELECT recording from queue order by id limit 1)),\
$1) FROM mode",
                       1,NULL,values,lengths,fmt,0));

  if(atoi(rating)>0) return 0;
	if(getenv("nonext")) return 0;

  int pid = get_pid("player",sizeof("player")-1);
  if(pid > 0)
	kill(pid,SIGUSR1);
  return 0;
}
