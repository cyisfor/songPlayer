#include "preparation.h"
#include "pq.h"

void prepareQueries(preparation_t queries[]) {
  for(i=0;i<sizeof(queries)/sizeof(preparation_t);++i) {
    PGresult* result = 
      PQprepare(PQconn,
                queries[i].name,
                queries[i].query,
                0,
                NULL);
    PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
  }
}
