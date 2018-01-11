#include "pq.h"

#include <stdlib.h>
#include <unistd.h>

typedef struct preparation *preparation;

preparation prepare(const char* query);
PGresult *prepare_exec(preparation self,
											 int nParams,
											 const char * const *paramValues,
											 const int *paramLengths,
											 const int *paramFormats,
											 int resultFormat);
