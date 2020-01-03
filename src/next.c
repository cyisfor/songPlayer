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

  do_rating(rating);
  if(atoi(rating)>0) return 0;
  if(getenv("nonext")) return 0;

  int pid = get_pid("player",sizeof("player")-1);
  if(pid > 0)
	kill(pid,SIGUSR1);
  return 0;
}
