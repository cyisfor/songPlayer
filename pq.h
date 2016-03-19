#include <libpq-fe.h>

// need one connection per thread :/
extern __thread PGconn* PQconn;

extern const char* pq_application_name;
void PQinit(void);

void PQassert_p(PGresult* result, int test, const char* tests, const char* file, int line);

#define PQassert(a,b) PQassert_p(a,b,#b,__FILE__,__LINE__)

void PQbegin(void);
void PQcommit(void);

void PQcheckClear(PGresult*);

#ifdef DEBUG_STATEMENTS
PGresult *logExecPrepared(PGconn *conn,
                         const char *stmtName,
                         int nParams,
                         const char * const *paramValues,
                         const int *paramLengths,
                         const int *paramFormats,
                         int resultFormat);
#else
#define logExecPrepared PQexecPrepared
#endif
