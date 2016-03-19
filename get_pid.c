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
	  "INSERT INTO pids (application_name,pid) SELECT $1::text,$2::int"},
	{ "postgresqlsucks",
	  "DELETE FROM pids WHERE application_name = $1::text"},
    { "getpid",
      "select pid from pids WHERE application_name = $1::text"}
  };
  PQexecParams
		  (PQconn,
		   "CREATE TABLE pids (\n"
		   "id SERIAL PRIMARY KEY, \n"
		   "pid INTEGER UNIQUE NOT NULL, \n"
		   "application_name TEXT UNIQUE NOT NULL)",
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
  const char* values[1];
  int lengths[1];
  const int fmt[1] = { 1 };
  values[0] = pq_application_name;
  lengths[0] = strlen(pq_application_name); 
  PQexecPrepared
	(PQconn,
	 "postgresqlsucks",
	 1,
	 values,lengths,fmt,1);
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
	atexit(get_pid_done);
  }
  return ok;
}

