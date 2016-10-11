#include "preparation.h"
#include "pq.h"

preparation_t* memory = NULL;
int memn = 0;

bool prepare_needed_reset(void) {
	if(!pq_needed_reset()) return false;
	int i;
	for(i=0;i<memn;++i) {
		PGresult* result = 
			PQprepare(PQconn,
                memory[i].name,
                memory[i].query,
                0,
                NULL);
	}
	return true;
}

PGresult *prepare_exec(PGconn *conn,
                         const char *stmtName,
                         int nParams,
                         const char * const *paramValues,
                         const int *paramLengths,
                         const int *paramFormats,
                         int resultFormat) {
	do {
		PGresult* res =
			logExecPrepared(conn,stmtName,nParams,paramValues,paramLengths,paramFormats,resultFormat);
	} while(prepare_needed_reset());
	return res;
}

void prepareQueries_p(preparation_t queries[],ssize_t num) {
  int i;
	memory = realloc(memory,sizeof(preparation_t)*(memn+num));
	memcpy(memory+sizeof(preparation_t)*memn,queries,sizeof(preparation_t)*num);
	memn += num;
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
