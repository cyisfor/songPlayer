#include "player_pid.h"
#include "preparation.h"
#include "pq.h"
#include <arpa/inet.h> // ntohl

void player_pid_init(void) {
  preparation_t queries[] = {
    { "getpid",
      "select pid from pg_stat_activity where datname = 'semantics' AND application_name = 'player'"
    }
  };
  prepareQueries(queries);
}

int player_pid(void) {
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
  int pid = (int)ntohl(*((int*)PQgetvalue(result,0,0)));
  PQclear(result);
  return pid;
}
