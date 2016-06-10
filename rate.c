#include "pq.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int main(void) {
  PQinit();

  const char* id = getenv("id");
  assert(id!=NULL);
  const char* stmt = getenv("rating");
  assert(rating!=NULL);

  const char* values[] = { id, rating };
  const int lengths[] = { strlen(id), strlen(rating) };
  const int fmt[] = { 0, 0 };
  PQclear(PQexecParams(PQconn,"SELECT connectionStrength($1,$2)",
                       2,NULL,values,lengths,fmt,0));
  return 0;
}
