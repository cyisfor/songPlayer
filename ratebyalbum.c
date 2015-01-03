#include "pq.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int main(void) {
  PQinit();

  const char* rating = getenv("rating");
  assert(rating!=NULL);

  const char* values[] = { rating };
  const int lengths[] = { strlen(rating) };
  const int fmt[] = { 0 };
  PQclear(PQexecParams(PQconn,"SELECT connectionStrength(id, \
(SELECT song FROM recordings WHERE album = (SELECT album from queue inner join recordings on queue.recording = recordings.id where queue.id = (select min(id) from queue))), \
$1) FROM mode",
                       1,NULL,values,lengths,fmt,0));

  if(atoi(rating)>0) return 0;

  PGresult* result =
    PQexecParams(PQconn,"SELECT pid FROM pids WHERE id = 0",
                   0,NULL,NULL,NULL,NULL,0);

  if(PQntuples(result)==0) return 3;
  kill(atoi(PQgetvalue(result,0,0)),SIGUSR1);
  return 0;
}
