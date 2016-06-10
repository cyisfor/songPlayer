#include "preparation.h"
#include "pq.h"

void prepareQueries_p(preparation_t queries[],ssize_t num) {
  int i;
  for(i=0;i<num;++i) {
    fprintf(stderr,"Preparing query %s %p\n",queries[i].name,PQconn);
    PGresult* result = 
      PQprepare(PQconn,
                queries[i].name,
                queries[i].query,
                0,
                NULL);
    PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
  }
}
