#include <libpq-fe.h>

// need one connection per thread :/
extern __thread PGconn* PQconn;

void PQinit(void);

void PQassert_p(PGresult* result, int test, const char* tests, const char* file, int line);

#define PQassert(a,b) PQassert_p(a,b,#b,__FILE__,__LINE__)

void PQbegin(void);
void PQcommit(void);

void PQcheckClear(PGresult*);
