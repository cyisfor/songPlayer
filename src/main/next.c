#include "../pq.h"
#include "../config.h"
#include "../get_pid.h"
#include "../rating.h"

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

int main(void) {
  PQinit();
  rating_init();
  
  const char* rating = getenv("rating");
  assert(rating!=NULL);

  do_rating(rating);
  return 0;
}
