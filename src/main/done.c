#include "pq.h"
#include "select.h"

#include <stdlib.h> // atoi
#include <signal.h>

int main(void) {

  selectSetup();

  PGresult* result =
    PQexecParams(PQconn,"SELECT pid FROM pids WHERE id = 0",
                   0,NULL,NULL,NULL,NULL,0);

  if(PQntuples(result)==0) return 3;

  selectDone();
  kill(atoi(PQgetvalue(result,0,0)),SIGUSR1);
  return 0;
}
