#include "get_pid.h"
#include "preparation.h"
#include "pq.h"
#include <arpa/inet.h> // ntohl
#include <assert.h>
#include <string.h> // strlen
#include <stdint.h>
#include <stdlib.h> // atexit

void get_pid_init(void) {
  preparation_t queries[] = {
	{ "declare",
	  "INSERT INTO pids (dbpid,pid) SELECT pid,$2::int from pg_stat_activity where application_name = $1::text"},
    { "getpid",
      "select pids.pid from pids INNER JOIN pg_stat_activity "
	  "ON pids.dbpid = pg_stat_activity.pid "
	  "WHERE application_name = $1::text"}
  };
  // sure would be nice if postgresql didn't suck
  PQexecParams
	(PQconn,
	 "DELETE FROM pids WHERE dbpid NOT IN (SELECT pid FROM pg_stat_activity)",
	 0, NULL, NULL, NULL, NULL, 0);
  prepareQueries(queries);
}

int get_pid(const char* application_name, ssize_t len) {
  const char* values[1];
  int lengths[1];
  int fmt[1];
  values[0] = application_name;
  lengths[0] = len; 
  fmt[0] = 1;

  PGresult* result = PQexecPrepared
    (
     PQconn,
     "getpid",
     1,
     values,
     lengths,fmt,1);

  if(PQntuples(result) > 1) return -2;
  if(PQntuples(result)==0) return -1;
  int pid = (int)ntohl(*((int64_t*)PQgetvalue(result,0,0)));
  PQclear(result);
  return pid;
}

static void get_pid_done(void) {
  printf("do it? %s\n",pq_application_name);
  const char* values[1];
  int lengths[1];
  const int fmt[1] = { 1 };
  int32_t ival = htonl(getpid());
  values[0] = (const char*)&ival;
  lengths[0] = sizeof(ival);
  PQcheckClear(PQexecParams
			   (PQconn,
				"DELETE FROM pids WHERE pid = $1::int",
				1,
				NULL,values,lengths,fmt,1));
}

bool get_pid_declare(void) {
  const char* values[2];
  int lengths[2];
  const int fmt[2] = { 1, 1 };
  values[0] = pq_application_name;
  lengths[0] = strlen(pq_application_name);
  int32_t ival = htonl(getpid());
  values[1] = (const char*)&ival;
  lengths[1] = sizeof(ival);
  PGresult* result = PQexecPrepared
  (PQconn,
   "declare",
   2,
   values,lengths,fmt,1);
  bool ok = PQresultStatus(result) == PGRES_COMMAND_OK;
  if(ok) {
	printf("yay?");
	atexit(get_pid_done);
  }
  return ok;
}

