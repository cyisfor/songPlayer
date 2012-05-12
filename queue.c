#include "pq.h"
#include "synchronize.h"
#include "preparation.h"
#include "config.h"

#include <math.h>
#include <stdint.h>
#include <string.h>
#include <fcntl.h>

#include <assert.h>

int randomSource = 0;

#define AVAILABLE 0
#define NEED 1

double A;
double eA;

static void setupOffsetCurve(double halfwayPoint) {
  A = log(0.5) / (halfwayPoint - 1);
  eA = exp(A);
}

#define RESTRICT 0.9

static double offsetCurve(double x) {
  return (1 - exp(A * x) / eA) * RESTRICT;
}

static PGresult* pickBestRecording(void) {
  int rows,cols;
  char* end = NULL;
  PGresult* result = 
    PQexecPrepared(PQconn,"bestSongRange",
                   0,NULL,NULL,NULL,0);
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows==1 && cols==2);
  int maxScore = strtol(PQgetvalue(result,0,1),&end,10);
  int minScore = strtol(PQgetvalue(result,0,0),&end,10);

  PQclear(result);

  uint32_t randVal;
  read(randomSource,&randVal,sizeof(randVal));

  int pivot = minScore + (maxScore - minScore) * 
    offsetCurve(((double)randVal) / (1L<<(sizeof(randVal)<<3)));

  char buf[0x100];
  int length = snprintf(buf,0x100,"%d",pivot);
  const int fmt = 0;

  result = 
    PQexecPrepared(PQconn,"bestSong",
                   1,(const char* const*)(&buf),&length,&fmt,0);
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows>=1 && cols==1);

  // note: this is a serialized integer, not a title or path.
  char* song = PQgetvalue(result,0,0);

  length = strlen(song);

  PGresult* result2 = 
    PQexecPrepared(PQconn,"bestRecordingRange",
                   1,(const char* const*)(&song),&length,&fmt,0);
  PQassert(result2,rows==1 && cols==2);
  maxScore = strtol(PQgetvalue(result,0,1),&end,10);
  maxScore = strtol(PQgetvalue(result,0,0),&end,10);

  PQclear(result2);

  read(randomSource,&randVal,sizeof(randVal));

  pivot = minScore + (maxScore - minScore) * 
    offsetCurve(((double)randVal) / (1L<<(sizeof(randVal)<<3)));
  
  const char* parameters[2] = { song, buf };
  int lengths[2] = { length, snprintf(buf,0x100,"%d",pivot) };
  int formats[2] = { 0, 0 };

  result2 = 
    PQexecPrepared(PQconn,"bestRecording",
                   2,parameters,lengths,formats,0);

  PQclear(result);
  rows = PQntuples(result2);
  cols = PQnfields(result2);
  PQassert(result2,rows==1 && cols==1);

  return result2;
}

static void queueHighestRated(void) {
  PGresult* result = pickBestRecording();

  char* recording = PQgetvalue(result,0,0);
  int len = strlen(recording);
  int fmt = 0;
  PGresult* result2 = 
    PQexecPrepared(PQconn,"insertIntoQueue",
                   1,(const char* const*)(&recording),&len,&fmt,0); 
  PQclear(result);
  PQassert(result2,(long int)result2);
  PQclear(result2);
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
  PQclear(result);
  return numQueued;
}

static void* queueChecker(void* arg) {
  for(;;) {
    fillQueue(queueHighestRated);
    waitUntilQueueNeeded();
  }
}

void queueSetup(void) {
  randomSource = open("/dev/urandom",O_RDONLY);
  preparation_t queries[] = {
    { "numQueued",
      "SELECT COUNT(id) FROM queue" },
    { "bestSongRange",
      "SELECT coalesce(MAX(ratings.score),-1500),coalesce(MIN(ratings.score),-1500) FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id" },
    { "bestSong",
      "SELECT songs.id FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id WHERE score >= $1 ORDER BY score LIMIT 1" },
    { "bestRecordingRange",
      "SELECT coalesce(MAX(ratings.score),-1500),coalesce(MIN(ratings.score),-1500) FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE recordings.song = $1" },
    { "bestRecording",
      "SELECT recordings.id FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE song = $1 AND score >= $2 ORDER BY score LIMIT 1" },
    { "insertIntoQueue",
      "INSERT INTO queue (recording) VALUES ($1)"}
  };

  prepareQueries(queries);

  setNumQueued(getNumQueued());

  pthread_t thread;
  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setdetachstate(attr,PTHREAD_CREATE_DETACHED);

  pthread_create(&thread,&attr,queueChecker);
}

