#include "pq.h"
#include "synchronize.h"
#include "preparation.h"
#include "config.h"
#include "adjust.h"

#include <pthread.h>
#include <glib.h>

#include <math.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>

#include <assert.h>

void* myPQtest = NULL;

/* Choose according to the number of songs, not the score range.
   If you chose by the mean (least to greatest score) then when you rate
   a song down least, it will decrease the frequency that songs you like are
   played. So like -1,2,2,2,2,10,10 the top 2 will play a lot more than with
   -1000,2,2,2,2,10,10 in which case the top 6 will get about equal treatment.

    Median means you can't fucking get rid of half your songs though...

    So the mean is better... at least in that it's possible to have an album
    of 99% crap and only listen to the 1% you like.

   If you chose by the median (number of songs) then when you rate a song down
   it won't affect the frequency songs you like more being played.


   I dunno! Going w/ mean.
*/

static PGresult* pickBestRecording(void) {
  int rows,cols;
  char* end = NULL;
  PGresult* result, *result2;
  double minScore;
  double maxScore;
  uint32_t randVal;
  double pivotF;
  double pivot;
  char buf[0x100];
  int length;
  const int fmt = 0;
  char* song;
 TRYAGAIN:
  result =
    PQexecPrepared(PQconn,"bestSongRange",
                   0,NULL,NULL,NULL,0);
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows==1 && cols==2);
  minScore = strtod(PQgetvalue(result,0,0),&end);
  maxScore = strtod(PQgetvalue(result,0,1),&end);
  PQclear(result);

  double randF = drand48();
  assert(randF >= 0 && randF <= 1);

  pivotF = offsetCurve(randF);
  pivot = (maxScore - minScore) * pivotF + minScore;

  int tries = 0;
  for(;;) {
    length = snprintf(buf,0x100,"%f",pivot);

    g_message("rand goes %lf to %lf",randF,pivotF);
    g_message("pivot offset is between %lf:%lf is %f",minScore,maxScore,pivot);

    { const char* values[] = { buf };
      result =
        PQexecPrepared(PQconn,"bestSong",
                     1,values,&length,&fmt,0);
    }
    rows = PQntuples(result);
    break;
  }
  cols = PQnfields(result);
  PQassert(result,rows>=1 && cols==2);

  // note: this is a serialized integer, not a title or path.
  song = PQgetvalue(result,0,0);

  g_message("Best song: %s %s",song,PQgetvalue(result,0,1));

  length = strlen(song);

  { const char* values[] = { song };
    result2 =
      PQexecPrepared(PQconn,"bestRecordingRange",
                     1,values,&length,&fmt,0);
  }
  rows = PQntuples(result2);
  cols = PQnfields(result2);
  PQassert(result2,rows==1 && cols==2);
  minScore = strtod(PQgetvalue(result2,0,0),&end);
  maxScore = strtod(PQgetvalue(result2,0,1),&end);
  PQclear(result2);

  randF = drand48();

  pivotF = offsetCurve(randF);
  pivot = (maxScore - minScore) * pivotF + minScore;

  {
    const char* parameters[2] = { song, buf };
    int lengths[2] = { length, snprintf(buf,0x100,"%f",pivot) };
    const int formats[2] = { 0, 0 };

    result2 =
      PQexecPrepared(PQconn,"bestRecording",
                     2,parameters,lengths,formats,0);

  rows = PQntuples(result2);
  if(rows==0) {
      PQclear(result2);
      PQexecPrepared(PQconn,"aRecording",
                     1,parameters,lengths,formats,0);

      rows = PQntuples(result2);
      if(rows==0)
          g_error("Song %s has no recordings!\n",song);
  }
  }
  cols = PQnfields(result2);
  PQclear(result);

  if(!(rows==1 && cols == 1))
    g_error("rows %d cols %d\n",rows,cols);

  return result2;
}

static uint8_t getNumQueued(void);

volatile uint8_t queueInterrupted = 0;

static uint8_t queueHighestRated(void) {
    PQcheckClear(PQexecPrepared(PQconn,"resetRatings",0,NULL,NULL,NULL,0));
    PQcheckClear(PQexecPrepared(PQconn,"scoreByLast",0,NULL,NULL,NULL,0));
    PQcheckClear(PQexecPrepared(PQconn,"rateByPlayer",0,NULL,NULL,NULL,0));

TRYAGAIN:
  queueInterrupted = 0;
  PGresult* result = pickBestRecording();
  if(queueInterrupted) {
      PQclear(result);
      goto TRYAGAIN;
  }

  int rows = PQntuples(result);
  int cols = PQnfields(result);
  PQassert(result,rows==1 && cols==1);

  g_message("Inserting %s",PQgetvalue(result,0,0));
  const char* parameters[] = { PQgetvalue(result,0,0) };
  int len[] =  { strlen(parameters[0]) };
  const int fmt[] = { 0 };
  PGresult* result2 =
    PQexecPrepared(PQconn,"insertIntoQueue",
                   1,parameters,len,fmt,0);
  PQclear(result);
  PQassert(result2,(long int)result2);
  PQclear(result2);
  PQclear(PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0));
  return getNumQueued();
}

static uint8_t getNumQueued(void) {
  PGresult* result =
    PQexecPrepared(PQconn,"numQueued",
                   0,NULL,NULL,NULL,0);
  int rows = PQntuples(result);
  int cols = PQnfields(result);
  PQassert(result,rows>=1 && cols==1);
  char* end;
  uint8_t numQueued = strtol(PQgetvalue(result,0,0),&end,10);
  g_message("Num queued is now %d",numQueued);
  PQclear(result);
  return numQueued;
}

static void* queueChecker(void* arg) {
    int truerand = open("/dev/random",O_RDONLY);
    unsigned short seed16v[3];
    assert(sizeof(seed16v)==sizeof(short)*3);
    read(truerand,seed16v,sizeof(seed16v));
    close(truerand);
    seed48(seed16v);
    memset(seed16v,0,sizeof(seed16v));


  assert(myPQtest==NULL);
  PQinit();
  g_message("PQ Queue conn %p",PQconn);
  myPQtest = PQconn;
  preparation_t queries[] = {
    { "scoreByLast",
      "SELECT timeConnectionThingy(1)" },
    { "rateByPlayer",
      "SELECT rate(0,100)" },
    { "resetRatings",
      "DELETE FROM ratings"},
    { "numQueued",
      "SELECT COUNT(id) FROM queue" },
    { "bestSongRange",
      "SELECT MIN(ratings.score),MAX(ratings.score) FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id WHERE songs.id NOT IN (SELECT song FROM recordings WHERE id IN (select recording from queue))" },
    { "bestSong",
        "SELECT songs.id,songs.title FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id WHERE songs.id NOT IN (SELECT song FROM recordings WHERE id IN (select recording from queue)) AND score >= $1 ORDER BY score,random() LIMIT 1" },
    { "bestRecordingRange",
      "SELECT MIN(ratings.score),MAX(ratings.score) FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE recordings.song = $1" },
    { "bestRecording",
      "SELECT recordings.id FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE song = $1 AND score >= $2 ORDER BY score LIMIT 1" },
    { "aRecording",
      "SELECT recordings.id FROM recordings WHERE song = $1 ORDER BY random() LIMIT 1"},
    { "insertIntoQueue",
      "INSERT INTO queue (id,recording) SELECT coalesce(max(id)+1,0),$1 FROM queue"}
  };

  prepareQueries(queries);
  setNumQueued(getNumQueued());

  setupOffsetCurve(0.9);

  for(;;) {
    fillQueue(queueHighestRated);
    waitUntilQueueNeeded(getNumQueued);
  }
}

void queueSetup(void) {
  pthread_t thread;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(&attr,PTHREAD_CREATE_DETACHED);

  pthread_create(&thread,&attr,queueChecker,NULL);
}
