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
==========
 Choose according to the number of songs, not the score range.
   If you chose by the mean (least to greatest score) then when you rate
   a song down least, it will decrease the frequency that songs you like are
   played. So like -1,2,2,2,2,10,10 the top 2 will play a lot more than with
   -1000,2,2,2,2,10,10 in which case the top 6 will get about equal treatment.

   If you chose by the median (number of songs) then when you rate a song down
   it won't affect the frequency songs you like more being played.
*/

#undef MEAN

static PGresult* pickBestRecording(void) {
  int rows,cols;
  char* end = NULL;
  PGresult* result, *result2;
  double minScore;
  double maxScore;
  double pivotF;
  double pivot;
  
  uint64_t num;
  double pivotF;
  int32_t offsetpivot;
  
  char buf[0x100];
  char offbuf[0x100];
  int lengths[2];
  const int fmt[] = { 0, 0 };
  char* song;
 TRYAGAIN:
  result =
    logExecPrepared(PQconn,"bestSongScoreRange",
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
  assert(pivotF >= 0 && pivotF <= 1);
  pivot = (maxScore - minScore) * pivotF + minScore;
  g_message("rand goes %lf to %lf %lf",randF,pivotF,pivot);

  { 
      lengths[0] = snprintf(buf,0x100,"%f",pivot);
      const char* values[] = { buf };
      result =
        logExecPrepared(PQconn,"bestSongRange",
                       1,&buf,&length,&fmt,0);
  }
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows==1 && cols==1);
  num = strtol(PQgetvalue(result,0,0),&end,10);
  
  PQclear(result);

  randF = drand48();
  pivotF = offsetCurve(randF);
  offsetpivot = num * pivotF;
  g_message("median rand goes %lf to %lf %d",randF,pivotF,offsetpivot);

  length = snprintf(offbuf,0x100,"%d",offsetpivot);

    g_message("mean pivot is between %lf:%lf is %f",minScore,maxScore,pivot);
    g_message("median offset is between 0:%lu is %d",num,pivot);
#endif /* MEAN */

    { const char* values[] = { buf };
      result =
        logExecPrepared(PQconn,"bestSong",
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

#ifdef MEAN
#else /* MEDIAN */
  length = strlen(song);

#endif /* MEAN */
  { const char* values[] = { song };
    result2 =
      logExecPrepared(PQconn,"bestRecordingRange",
                     1,values,&length,&fmt,0);
  }
  rows = PQntuples(result2);
  cols = PQnfields(result2);
#ifdef MEAN
  PQassert(result2,rows==1 && cols==2);
  minScore = strtod(PQgetvalue(result2,0,0),&end);
  maxScore = strtod(PQgetvalue(result2,0,1),&end);
#else /* MEDIAN */
  PQassert(result2,rows==1 && cols==1);
  num = strtol(PQgetvalue(result2,0,0),&end,10);
#endif /* MEAN */
  PQclear(result2);

  randF = drand48();

  pivotF = offsetCurve(randF);
#ifdef MEAN
  pivot = (maxScore - minScore) * pivotF + minScore;

  {
    const char* parameters[2] = { song, buf };
    int lengths[2] = { length, snprintf(buf,0x100,"%f",pivot) };
#else /* MEDIAN */
  pivot = num * pivotF;

  {
    const char* parameters[2] = { song, buf };
    int lengths[2] = { length, snprintf(buf,0x100,"%d",pivot) };
#endif /* MEAN */
    const int formats[2] = { 0, 0 };

    result2 =
      logExecPrepared(PQconn,"bestRecording",
                     2,parameters,lengths,formats,0);
#ifdef MEAN

  rows = PQntuples(result2);
  if(rows==0) {
      PQclear(result2);
      logExecPrepared(PQconn,"aRecording",
                     1,parameters,lengths,formats,0);

      rows = PQntuples(result2);
      if(rows==0)
          g_error("Song %s has no recordings!\n",song);
  }
#else /* MEDIAN */
  }

  rows = PQntuples(result2);
  if(rows==0) {
      g_error("Song %s has no recordings!\n",song);
#endif /* MEAN */
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
    PQcheckClear(logExecPrepared(PQconn,"resetRatings",0,NULL,NULL,NULL,0));
    PQcheckClear(logExecPrepared(PQconn,"scoreByLast",0,NULL,NULL,NULL,0));
    PQcheckClear(logExecPrepared(PQconn,"rateByPlayer",0,NULL,NULL,NULL,0));

TRYAGAIN:
  queueInterrupted = 0;
  PGresult* result = pickBestRecording();
  if(queueInterrupted) {
      PQclear(result);
      goto TRYAGAIN;
  }
#ifdef MEAN

  int rows = PQntuples(result);
  int cols = PQnfields(result);
  PQassert(result,rows==1 && cols==1);

#else /* MEDIAN */

  int rows = PQntuples(result);
  int cols = PQnfields(result);
  PQassert(result,rows==1 && cols==1);

#endif /* MEAN */

  g_message("Making sure exists");
  { const char* parameters[] = { PQgetvalue(result,0,0), "path not found" };
      int len[] = { strlen(parameters[0]), sizeof("path not found") };
      const int fmt[] = { 0, 0 };
      struct stat buf;
      PGresult* exists = logExecPrepared(PQconn,"getPath",
              1,parameters,len,fmt,0);
      if(!PQgetvalue(exists,0,0) ||
            (0!=stat(PQgetvalue(exists,0,0),&buf))) {
            g_warning("Song %s:%s doesn't exist",parameters[0],PQgetvalue(exists,0,0));
            PQclear(exists);
            PQcheckClear(logExecPrepared(PQconn,"blacklist",
                        2,parameters,len,fmt,0));
            PQclear(result);
            return queueHighestRated();
        }

    }

  g_message("Inserting %s",PQgetvalue(result,0,0));
  const char* parameters[] = { PQgetvalue(result,0,0) };
  int len[] =  { strlen(parameters[0]) };
  const int fmt[] = { 0 };
  PGresult* result2 =
    logExecPrepared(PQconn,"insertIntoQueue",
                   1,parameters,len,fmt,0);
  PQclear(result);
  PQassert(result2,(long int)result2);
  PQclear(result2);
  PQclear(PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0));
  return getNumQueued();
}


static uint8_t getNumQueued(void) {
  PGresult* result =
    logExecPrepared(PQconn,"numQueued",
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

static void expireProblems(void) {
    PQclear(logExecPrepared(PQconn,"expireProblems",
                0,NULL,NULL,NULL,0));
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
      "SELECT rate(0,1)" },
    { "resetRatings",
      "DELETE FROM ratings"},
    { "numQueued",
      "SELECT COUNT(id) FROM queue" },
#define FROM_BEST_SONG "FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id WHERE songs.id NOT IN (SELECT song FROM recordings WHERE id IN (select recording from queue UNION select id from problems)) AND score >= $1"

    { "bestSongScoreRange",
      "SELECT MIN(ratings.score),MAX(ratings.score) " FROM_BEST_SONG },
    { "bestSongRange",
      "SELECT COUNT(songs.id) " FROM_BEST_SONG },
    { "bestSong",
        "SELECT songs.id,songs.title " FROM_BEST_SONG " ORDER BY score,random() OFFSET $2 LIMIT 1" },
#define FROM_BEST_RECORDING "FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE recordings.song = $1"
    { "bestRecordingScoreRange",
      "SELECT MIN(ratings.score),MAX(ratings.score) " FROM_BEST_RECORDING },
    { "bestRecording",
      "SELECT recordings.id " FROM_BEST_RECORDING " AND score >= $2 ORDER BY score LIMIT 1" },
    { "aRecording",
      "SELECT recordings.id FROM recordings WHERE song = $1 ORDER BY random() LIMIT 1"},
    { "insertIntoQueue",
      "INSERT INTO queue (id,recording) SELECT coalesce(max(id)+1,0),$1 FROM queue"},
    { "getPath",
        "SELECT path FROM recordings WHERE id = $1" },
    { "blacklist",
        "INSERT INTO problems (id,reason) VALUES ($1,$2)" },
    { "expireProblems",
        "DELETE FROM problems WHERE clock_timestamp() - created > '1 hour'" }
  };

  prepareQueries(queries);
  setNumQueued(getNumQueued());

  setupOffsetCurve(0.9);

  srand48(time(NULL));

  for(;;) {
    expireProblems();
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

void enqueue(char* id) {
    const char* parameters[] = {id};
    int len[] = {strlen(id)};
    const int fmt[] = { 0 };
    PGresult* result = 
        logExecPrepared(PQconn,"insertIntoQueue",
                   1,parameters,len,fmt,0);
    PQassert(result,(long int)result);
    PQclear(result);
}
