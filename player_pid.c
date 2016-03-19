void player_pid_init(void) {
  preparation_t queries[] = {
    { "getpid",
      "select pid from pids where id = $1::smallint"
    }
  };
  prepareQueries(queries);
}

int player_pid(uint16_t who) {
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
  uint32_t pid = (uint32_t)ntohl(*((uint32_t*)PQgetvalue(result,0,0)));
  PQclear(result);
  return pid;
}
