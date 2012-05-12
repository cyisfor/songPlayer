#include <stdlib.h>

typedef struct {
  const char* name;
  const char* query;
} preparation_t;

#define prepareQueries(queries) prepareQueries_p(queries,sizeof(queries)/sizeof(preparation_t))

void prepareQueries_p(preparation_t queries[],ssize_t num);
