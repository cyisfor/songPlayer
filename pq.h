#include <libpq-fe.h>

extern PGconn* PQconn;

void PQinit(void);

void PQassert_p(PGresult* result, int test, const char* tests);

#define PQassert(a,b) PQassert_p(a,b,#b)
