#include "player.h"
#include "preparation.h"
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
  playerPlay();
}

void selectDone(void) {
  PGresult *result =
    PQexecPrepared(PQconn,"currentSongWasPlayed",
                   0,NULL,NULL,NULL,0);
  PQassert(result,result && PQresultStatus(result)==PGRES_TUPLES_OK);
  PQclear(result);
  PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0);
  selectNext();
}

void selectSetup(void) {
  queueSetup();

  PQinit();

  preparation_t queries[] = {
    { "currentSongWasPlayed",
      "SELECT songWasPlayed(recording) FROM queue ORDER BY id ASC LIMIT 1" },
    { "popTopSong",
      "DELETE FROM queue WHERE id = (SELECT id FROM queue ORDER BY id ASC LIMIT 1)" },
  };

  prepareQueries(queries);

}
