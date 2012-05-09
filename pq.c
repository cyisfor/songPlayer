#include "pq.h"
#include "config.h"

#include <fcntl.h>
#include <string.h>
#include <assert.h>
#include <malloc.h>

PGconn* PQconn = NULL;

void PQinit(void) {
  /*const char* keywords[] = {"port","dbname","user","password",NULL};
  const char* values[] = {"5433","semantics","ion",password,NULL};
  */
  const char* keywords[] = {"port","dbname","user",NULL};
  const char* values[] = {"5433","semantics","ion",NULL};
  PQconn = PQconnectdbParams(keywords,values, 0);
  assert(PQconn);
}
void PQassert_p(PGresult* result, int test, const char* tests) {
  if(!test) {
    fprintf(stderr,"PQ error %s %s\n%s %s\n%s\n%s",
            tests,
            PQerrorMessage(PQconn),
            PQresStatus(PQresultStatus(result)),PQresultErrorMessage(result),
            PQresultErrorField(result,PG_DIAG_MESSAGE_DETAIL),
            PQresultErrorField(result,PG_DIAG_MESSAGE_HINT));
  }
}
