#include "pq.h"
#include "config.h"

#include <fcntl.h>
#include <string.h>
#include <assert.h>
#include <malloc.h>
#include <stdlib.h>

__thread PGconn* PQconn = NULL;

void PQinit(void) {
  /*const char* keywords[] = {"port","dbname","user","password",NULL};
  const char* values[] = {"5433","semantics","ion",password,NULL};
  */
  const char* keywords[] = {"port","dbname","user",NULL};
  const char* values[] = {"5433","semantics","ion",NULL};
  PQconn = PQconnectdbParams(keywords,values, 0);
  assert(PQconn);
}
void PQassert_p(PGresult* result, int test, const char* tests, const char* file, int line) {
  if(!test) {
    fprintf(stderr,"%s:%d\n",file,line);
    fprintf(stderr,"PQ error %s %s\n%s %s\n%s\n%s",
            tests,
            PQerrorMessage(PQconn),
            PQresStatus(PQresultStatus(result)),PQresultErrorMessage(result),
            PQresultErrorField(result,PG_DIAG_MESSAGE_DETAIL),
            PQresultErrorField(result,PG_DIAG_MESSAGE_HINT));
    abort();
  }
}

void PQbegin(void) {
    PQcheckClear(PQexecParams(PQconn,"BEGIN",0,NULL,NULL,NULL,NULL,0));
}
void PQcommit(void) {
    PQcheckClear(PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0));
}

void PQcheckClear(PGresult* r) {
    PQassert(r,
             r && ( PQresultStatus(r)==PGRES_COMMAND_OK ||
                    PQresultStatus(r)==PGRES_TUPLES_OK));
    PQclear(r);
}
