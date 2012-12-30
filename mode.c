#include "pq.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

void switchMode(const char* who) {
    short needRestart = 1;
    PGresult* res = PQexecParams(PQconn,"SELECT id FROM mode",
                                 0,NULL,NULL,NULL,NULL,0);
    if(res) {
        if(PQntuples(res)>0) {
            if(atoi(PQgetvalue(res,0,0))==atoi(who))
                needRestart = 0;
        }
        PQclear(res);
    }
  const char* values[] = { who };
  const int lengths[] = { strlen(who) };
  const int fmt[] = { 0 };
  PQclear(PQexecParams(PQconn,"SELECT connectionStrength(0,id,0,false) FROM mode",
                       0,NULL,NULL,NULL,NULL,0));
  PQclear(PQexecParams(PQconn,"UPDATE mode set id = $1",
                       1,NULL,values,lengths,fmt,0));
  PQcheckClear(PQexecParams(PQconn,"SELECT connectionStrength(0,id,2,false) FROM mode",
                       0,NULL,NULL,NULL,NULL,0));
  PQclear(PQexecParams(PQconn,"DELETE FROM queue",
                       0,NULL,NULL,NULL,NULL,0));

  if(0==needRestart) return;

  PGresult* result =
    PQexecParams(PQconn,"SELECT pid FROM pids WHERE id = 0",
                   0,NULL,NULL,NULL,NULL,0);

  if(PQntuples(result)==0) return;
  kill(atoi(PQgetvalue(result,0,0)),SIGUSR2);
}

int main(void) {
    //queueSetup();

  PQinit();

  const char* who = getenv("who");
  assert(who!=NULL);

  if(0==strcmp(who,"m")) {
    puts("beep");
    switchMode("2");
  } else
    switchMode("3");

  printf("%s mode\n",who);
}
