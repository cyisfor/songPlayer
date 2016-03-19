#include "get_pid.h"
#include "preparation.h"
#include "pq.h"
#include <arpa/inet.h> // ntohl
#include <assert.h>

void get_pid_init(void) {
  preparation_t queries[] = {
	{ "setup",
	  "CREATE TABLE pids (\n"
	  "id INTEGER PRIMARY KEY, \n"
	  "pid INTEGER UNIQUE NOT NULL, \n"
	  "dbpid INTEGER REFERENCES pg_stat_activity(pid) "
	  "ON DELETE CASCADE "
	  "ON UPDATE CASCADE)"},
	{ "declare",
	  "INSERT INTO pids (pid,dbpid) SELECT $2::int, "
	  "select pid from pg_stat_activity "
	  "where datname = 'semantics' AND application_name = $1::text"},
    { "getpid",
      "select pid from pids INNER JOIN pg_stat_activity "
	  " ON pids.dbpid = pg_stat_activity.pid "
	  "where datname = 'semantics' AND application_name = $1::text"}
  };
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

bool get_pid_declare(void) {
  const char* values[2];
  int lengths[2];
  const int fmt[2] = { 1, 1 };
  values[0] = application_name;
  lengths[0] = len; 
  values[1] = htonl(getpid());
  lengths[1] = sizeof(long);
  PGresult* result = PQexecPrepared
  (PQconn,
   "declare",
   1,
   values,lengths,fmt,1);
  return PQresultStatus(result) == PGRES_COMMAND_OK;
}
