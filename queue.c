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
#include <stdbool.h>
#include <sys/stat.h>

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

   So... choose by the mean, for a cutoff point below which songs don't get picked
   then choose by the median above that cutoff point!
*/

static PGresult* pickBestRecording(void) {
  int rows,cols;
  char* end = NULL;
  PGresult* result, *result2;
  double minScore;
  double maxScore;
  double pivotF;
  double pivot;
  
  uint64_t num;
  int32_t offsetpivot;
  
  char buf[0x100];
  char offbuf[0x100];
  int lengths[2];
  const int fmt[] = { 0, 0 };
  char* song;

  result =
    prepare_exec(PQconn,"bestSongScoreRange",
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
  g_message("mean pivot is between %lf:%lf is %f",minScore,maxScore,pivot);
  g_message("rand goes %lf to %lf",randF,pivotF);

  { 
      lengths[0] = snprintf(buf,0x100,"%f",pivot);
      const char* values[] = { buf };
      result =
        prepare_exec(PQconn,"bestSongRange",
                       1,values,lengths,fmt,0);
  }
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows==1 && cols==1);
  num = strtol(PQgetvalue(result,0,0),&end,10);
  
  PQclear(result);

  randF = drand48();
  pivotF = offsetCurve(randF);
  offsetpivot = num * pivotF;
  g_message("median offset is between 0:%lu is %d",num,offsetpivot);
  g_message("median rand goes %lf to %lf",randF,pivotF);

  lengths[1] = snprintf(offbuf,0x100,"%d",offsetpivot);

  { const char* values[] = { buf, offbuf };
      result =
          prepare_exec(PQconn,"bestSong",
                  2,values,lengths,fmt,0);
  }
  rows = PQntuples(result);
  cols = PQnfields(result);
  PQassert(result,rows>=1 && cols==2);

  // note: this is a serialized integer, not a title or path.
  song = PQgetvalue(result,0,0);
  lengths[0] = PQgetlength(result,0,0);
  g_message("Best song: %s %s",song,PQgetvalue(result,0,1));


  { const char* values[] = { song };
    result2 =
      prepare_exec(PQconn,"bestRecordingScoreRange",
                     1,values,lengths,fmt,0);
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

  g_message("recordings for %s min %lf max %lf pivot %lf (%lf)",song,minScore,maxScore,pivot,pivotF);

  {
    lengths[1] = snprintf(buf,0x100,"%f",pivot);
    const char* values[2] = { song, buf };

    result2 =
      prepare_exec(PQconn,"bestRecording",
                     2,values,lengths,fmt,0);
  }

  rows = PQntuples(result2);
  if(rows==0) {
      g_error("Song %s has no recordings!\n",song);
  }
  cols = PQnfields(result2);
  PQclear(result);

  if(!(rows==1 && cols == 1))
    g_error("rows %d cols %d\n",rows,cols);

  return result2;
}


static uint8_t getNumQueued(void);

volatile uint8_t queueInterrupted = 0;

void queueRescore(void) {
    PQcheckClear(prepare_exec(PQconn,"resetRatings",0,NULL,NULL,NULL,0));
    PQcheckClear(prepare_exec(PQconn,"scoreByLast",0,NULL,NULL,NULL,0));
    PQcheckClear(prepare_exec(PQconn,"rateByPlayer",0,NULL,NULL,NULL,0));
}

bool try_to_find(const char* path, const char* recording, int rlen) {
  struct stat derp;
  char buf[0x1000];
  const char* parameters[] = { buf, recording };      
  int len[] = { 0, rlen };
  const int fmt[] = { 0, 0 };

  bool for_format(const char* fmtderp) {
    len[0] = snprintf(buf,0x1000,fmtderp,path);
	g_warning("trying place %s", fmtderp);
    if(0==stat(buf,&derp)) {
      g_warning("found %s in %s\n",path,buf);
      PQcheckClear(prepare_exec(PQconn,"updatePath", 
  	2,parameters,len,fmt,0));
      return true;
    }
    return false;
  }
#define advance(s) \
  if(0!=strncmp(path,s,sizeof(s)-1)) return false; \
  path += sizeof(s)-1;
  advance("/");
  if(for_format("/old/%s") || for_format("/old/old/%s")) return true;
  advance("extra/");
  if(for_format("/old/extra/%s") || for_format("/extra/old/%s")) return true;
  advance("user/");
  return for_format("/home/%s") || for_format("/extra/%s");
}

static uint8_t queueHighestRated(void) {
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

  g_message("Making sure exists");
  { const char* parameters[] = { PQgetvalue(result,0,0), "path not found" };
      int len[] = { PQgetlength(result,0,0), sizeof("path not found") };
      const int fmt[] = { 0, 0 };
      struct stat buf;
      PGresult* exists = prepare_exec(PQconn,"getPath",
              1,parameters,len,fmt,0);
      if(!PQgetvalue(exists,0,0) ||
            (0!=stat(PQgetvalue(exists,0,0),&buf))) {
            g_warning("Song %s:%s doesn't exist",parameters[0],PQgetvalue(exists,0,0));
            if(false==try_to_find(PQgetvalue(exists,0,0),parameters[0],len[0])) {
              PQclear(exists);
              PQcheckClear(prepare_exec(PQconn,"blacklist",
										   2,parameters,len,fmt,0));
              PQclear(result);
              return queueHighestRated();
            }
            PQclear(exists);
        }

    }

  g_message("Inserting %s",PQgetvalue(result,0,0));
  const char* parameters[] = { PQgetvalue(result,0,0) };
  int len[] =  { strlen(parameters[0]) };
  const int fmt[] = { 0 };
  PGresult* result2 =
    prepare_exec(PQconn,"insertIntoQueue",
                   1,parameters,len,fmt,0);
  PQclear(result);
  PQassert(result2,(long int)result2);
  PQclear(result2);
  PQclear(PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0));
  return getNumQueued();
}


static uint8_t getNumQueued(void) {
  PGresult* result =
    prepare_exec(PQconn,"numQueued",
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
    PQclear(prepare_exec(PQconn,"expireProblems",
                0,NULL,NULL,NULL,0));
}

void queuePrepare(void) {
  /* these are used by queueRescore outside of the queuing thread */
  preparation_t queries[] = {
    { "scoreByLast",
      "SELECT timeConnectionThingy(1)" },
    { "rateByPlayer",
      "SELECT rate(0,1)" },
    { "resetRatings",
      "DELETE FROM ratings"},
		// used by command line queueing utilities
		{ "insertIntoQueue",
			"INSERT INTO queue (id,recording) SELECT coalesce(max(id)+1,0),$1 FROM queue"},
  };
  prepareQueries(queries);
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
  queuePrepare();
  preparation_t queries[] = {
    { "numQueued",
      "SELECT COUNT(id) FROM queue" },
#define FROM_BEST_SONG "FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id WHERE songs.id NOT IN (SELECT song FROM recordings WHERE id IN (select recording from queue UNION select id from problems))"

    { "bestSongScoreRange",
      "SELECT MIN(ratings.score),MAX(ratings.score) " FROM_BEST_SONG },
#define FROM_BEST_SONG_SCORE FROM_BEST_SONG " AND (score >= $1 OR (score IS NULL AND $1 = 0.0))"
    { "bestSongRange",
      "SELECT COUNT(songs.id) " FROM_BEST_SONG_SCORE },
    { "bestSong",
        "SELECT songs.id,songs.title " FROM_BEST_SONG_SCORE " ORDER BY score,random() OFFSET $2 LIMIT 1" },
#define FROM_BEST_RECORDING "FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE recordings.song = $1"
    { "bestRecordingScoreRange",
      "SELECT MIN(ratings.score),MAX(ratings.score) " FROM_BEST_RECORDING },
    { "bestRecording",
      "SELECT recordings.id " FROM_BEST_RECORDING " AND (score >= $2 OR (score IS NULL AND $2 = 0.0)) ORDER BY score LIMIT 1" },
    { "getPath",
        "SELECT path FROM recordings WHERE id = $1" },
    { "updatePath",
        "UPDATE recordings SET path = $1 WHERE id = $2" },
    { "blacklist",
        "INSERT INTO problems (id,reason) VALUES ($1,$2)" },
    { "expireProblems",
        "DELETE FROM problems WHERE clock_timestamp() - created > '1 hour'" }
  };

  prepareQueries(queries);
  setNumQueued(getNumQueued());

  setupOffsetCurve(0.99);

  srand48(time(NULL));

  for(;;) {
    expireProblems();
    queueRescore();
    fillQueue(queueHighestRated);
    waitUntilQueueNeeded(getNumQueued);
  }
}

void queueStart(void) {
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
        prepare_exec(PQconn,"insertIntoQueue",
                   1,parameters,len,fmt,0);
    PQassert(result,(long int)result);
    PQclear(result);
}
