#include "player.h"
#include "queue.h"
#include "synchronize.h"
#include "pq.h"

#include <stdint.h>

#include <sys/types.h>
#include <signal.h>
#include <string.h>

#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <assert.h>

void selectNext(void) {
  PGresult *result =
    PQexecPrepared(PQconn,"popTopSong",
                   0,NULL,NULL,NULL,0);
  PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
  PQclear(result);
  songOutOfQueue();
  waitUntilSongInQueue();  
  playerPlay();
}

void selectDone(void) {
  PGresult *result =
    PQexecPrepared(PQconn,"currentSongWasPlayed",
                   0,NULL,NULL,NULL,0);
  PQassert(result,result && PQresultStatus(result)==PGRES_TUPLES_OK);
  PQclear(result);
  selectNext();
}

void selectSetup(void) {
{
  preparation_t queries[] = {
    { "currentSongWasPlayed",
      "SELECT songWasPlayed(SELECT recording FROM queue ORDER BY id LIMIT 1)" },
    { "popTopSong",
      "DELETE FROM queue WHERE id = (SELECT id FROM queue ORDER BY id LIMIT 1)" },
  };

  prepareQueries(queries);

  queueSetup();
}
