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

preparation popTopSong = NULL;
preparation notifyNext = NULL;
preparation currentSongWasPlayed = NULL;

void selectNext(void) {
  PGresult *result =
    prepare_exec(popTopSong,
                   0,NULL,NULL,NULL,0);
  PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
  PQclear(result);
  PQclear(prepare_exec(notifyNext,
                          0,NULL,NULL,NULL,0));

  songOutOfQueue();
}

void selectDone(void) {
  PGresult *result =
    prepare_exec(currentSongWasPlayed,
                   0,NULL,NULL,NULL,0);
  PQassert(result,result && PQresultStatus(result)==PGRES_TUPLES_OK);
  PQclear(result);
  queueRescore();
  PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0);
  selectNext();
}

void select_init(void) {
  queueStart();
  PQinit();
  queue_init();

  currentSongWasPlayed = prepare
		("SELECT songWasPlayed(recording) FROM (select recording FROM queue ORDER BY id ASC LIMIT 1) AS fuckeverything");
	notifyNext = prepare("NOTIFY next");
	popTopSong = prepare("DELETE FROM queue WHERE id = (SELECT id FROM queue ORDER BY id ASC LIMIT 1)");


}
