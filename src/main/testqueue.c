#include "../select.h"
#include "../pq.h"
#include "../preparation.h"
#include "../synchronize.h"
#include "../queue.h"

#include <sys/time.h>
#include <signal.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include <assert.h>

void playerPlay(void) {}

int main(void) {
	selectSetup();
  preparation getTopRecording = prepare
		("SELECT queue.recording FROM queue ORDER BY queue.id ASC LIMIT 1");

  PGresult* result;
  struct timeval start,done;
  int rows,cols;

  gettimeofday(&start,NULL);
  for(;;) {
      for(;;) {
          waitUntilSongInQueue();
          result =
						prepare_exec(getTopRecording,
                             0,NULL,NULL,NULL,0);
          rows = PQntuples(result);
          if(rows>0) break;
          PQclear(result);
          sleep(1);
      }

      cols = PQnfields(result);
      fprintf(stderr,"rows %x cols %x\n",rows,cols);
      PQassert(result,rows>=1 && cols==1);

      char* recording = PQgetvalue(result,0,0);
      gettimeofday(&done,NULL);
      struct timeval res;
      timersub(&done,&start,&res);
      printf("%lu Would play %s\n",res.tv_sec * 1000000L + res.tv_usec,recording);
      gettimeofday(&start,NULL);
      PQclear(result);
      selectDone();
  }
}
