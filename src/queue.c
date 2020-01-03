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

preparation bestSongScoreRange = NULL;
preparation bestSongRange = NULL;
#if 0
preparation bestSongs = NULL;
#endif
preparation bestSong = NULL;
preparation bestRecordingScoreRange = NULL;
preparation bestRecording = NULL;
preparation resetRatings = NULL;
preparation scoreByLast = NULL;
preparation rateByPlayer = NULL;
preparation updatePath = NULL;
preparation getPath = NULL;
preparation insertIntoQueue = NULL;
preparation byPath = NULL;
preparation numQueued = NULL;
preparation _expireProblems = NULL;
preparation _expireSongProblems = NULL;
preparation problem = NULL;
preparation song_problem = NULL;

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
    prepare_exec(bestSongScoreRange,
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
        prepare_exec(bestSongRange,
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
          prepare_exec(bestSong,
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
      prepare_exec(bestRecordingScoreRange,
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
      prepare_exec(bestRecording,
                     2,values,lengths,fmt,1);
  }

  rows = PQntuples(result2);
  if(rows==0) {
	  lengths[0] = PQgetlength(result,0,0);
		const char* values[] = { PQgetvalue(result,0,0), "has no recordings!" };
		PQcheckClear(prepare_exec(song_problem,
															2,values,lengths,fmt,0));
		PQclear(result);
		PQclear(result2);
		g_warning("Song %s has no recordings!\n",song);
		return pickBestRecording();
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
    PQcheckClear(prepare_exec(resetRatings,0,NULL,NULL,NULL,0));
    PQcheckClear(prepare_exec(scoreByLast,0,NULL,NULL,NULL,0));
    PQcheckClear(prepare_exec(rateByPlayer,0,NULL,NULL,NULL,0));
}

#define LITLEN(a) a, sizeof(a)-1

bool try_to_find(const char* oldpath, const char* recording, int rlen) {
  struct stat derp;
  const char* parameters[] = { NULL, recording };
  int len[] = { 0, rlen };
  const int fmt[] = { 0, 1 };

	const char* path = oldpath;
	int pathlen = strlen(oldpath);
	/*
		strip leading /extra, /shared /home, then try
		/old/old/extra/
		/old/old/extra/shared/
		etc
	*/

	bool advance(const char* test, int len) {
		if(0!=strncmp(path,test,len)) return false;
		path += len;
		pathlen -= len;
	}
#define ADVANCE(a) advance(LITLEN(a))
	ADVANCE("/old");
	ADVANCE("/old");

	bool check(const char* middle, int mlen) {
		bool check_one(const char* prefix, int plen) {
			char destpath[pathlen+plen+mlen];
			memcpy(destpath, prefix, plen);
			memcpy(destpath+plen, middle, mlen);
			memcpy(destpath+plen+mlen, path, pathlen);
			destpath[plen+mlen+pathlen] = 0;
			struct stat derp;
			if(0 == stat(destpath, &derp)) {
				g_warning("found %s in %s\n",path,destpath);
				parameters[0] = destpath;
				len[0] = plen+mlen+pathlen;
				PQcheckClear(prepare_exec(updatePath,
																	2,parameters,len,fmt,0));

				return true;
			}
			return false;
		}
		return check_one(LITLEN("/old/")) ||
			check_one(LITLEN("/old/old/"));
	}
#define CHECK(a) check(LITLEN(a))
	
	if(ADVANCE("/extra")) {
		/* /extra/stuff could be the old "shared" or the decrypted
			 /extra/home stuff, so check for it in /old/extra, /old/old/extra,
			 /old/shared /old/old/shared */
		if(CHECK("extra") || CHECK("shared")) return true;
	} else if(ADVANCE("/shared")) {
		/* /shared becomes $old/extra/shared when not remounted */
		if(CHECK("extra/shared") || CHECK("shared") || CHECK("extra")) return true;
	} else if(CHECK("extra") || CHECK("extra/home") || CHECK("shared") ||
						CHECK("extra/shared") || CHECK("home")) {
		return true;
	}

	g_warning("Can't find %s",path);
	return false;
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
      int len[] = { PQgetlength(result,0,0), sizeof("path not found")-1 };
      const int fmt[] = { 1, 0 };
      struct stat buf;

      PGresult* exists = prepare_exec(getPath,
              1,parameters,len,fmt,1);
			g_warning("tnnnn %s\n",PQgetvalue(exists,0,0));
      if(!PQgetvalue(exists,0,0) ||
            (0!=stat(PQgetvalue(exists,0,0),&buf))) {
            g_warning("Song %s:%s doesn't exist",parameters[0],PQgetvalue(exists,0,0));
            if(false==try_to_find(PQgetvalue(exists,0,0),parameters[0],len[0])) {
              PQclear(exists);
              PQcheckClear(prepare_exec(problem,
										   2,parameters,len,fmt,0));
              PQclear(result);
              return queueHighestRated();
            }
            PQclear(exists);
        }

    }

  g_message("Inserting %s",PQgetvalue(result,0,0));
  const char* parameters[] = { PQgetvalue(result,0,0) };
  int len[] =  { PQgetlength(result,0,0) };
  const int fmt[] = { 1 };
  PGresult* result2 =
    prepare_exec(insertIntoQueue,
                   1,parameters,len,fmt,1);
  PQclear(result);
  PQassert(result2,(long int)result2);
  PQclear(result2);
  PQclear(PQexecParams(PQconn,"COMMIT",0,NULL,NULL,NULL,NULL,0));
  return getNumQueued();
}

static uint8_t getNumQueued(void) {
  PGresult* result =
    prepare_exec(numQueued,
                   0,NULL,NULL,NULL,0);
  int rows = PQntuples(result);
  int cols = PQnfields(result);
  PQassert(result,rows>=1 && cols==1);
  char* end;
  uint8_t num = strtol(PQgetvalue(result,0,0),&end,10);
  g_message("Num queued is now %d",num);
  PQclear(result);
  return num;
}

static void expireProblems(void) {
    PQclear(prepare_exec(_expireProblems,
                0,NULL,NULL,NULL,0));
		PQclear(prepare_exec(_expireSongProblems,
												 0,NULL,NULL,NULL,0));
}

void queue_init(void) {
  /* these are used by queueRescore outside of the queuing thread */
	scoreByLast = prepare("SELECT timeConnectionThingy(1)");
	rateByPlayer = prepare("SELECT rate(0,1)");
	resetRatings = prepare("DELETE FROM ratings");
	// used by command line queueing utilities
	insertIntoQueue = prepare("INSERT INTO queue (id,recording) SELECT coalesce(max(id)+1,0),$1 FROM queue");
	byPath = prepare("select id from recordings where path = $1");
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
  queue_init();
	numQueued = prepare("SELECT COUNT(id) FROM queue");
	
#define FROM_BEST_SONG "FROM songs LEFT OUTER JOIN ratings ON ratings.id = songs.id WHERE songs.id NOT IN (" \
		"SELECT song FROM recordings WHERE id IN ("													\
		"SELECT id FROM problems"																		\
		" UNION "																														\
		"select recording from queue)"																			\
		" UNION "																														\
		"SELECT id FROM song_problems UNION select id from problems"				\
		" UNION "																														\
		"SELECT song FROM recordings WHERE lost)"

  bestSongScoreRange = prepare
		("SELECT MIN(ratings.score),MAX(ratings.score) " FROM_BEST_SONG);
	
#define FROM_BEST_SONG_SCORE FROM_BEST_SONG " AND (score >= $1 OR (score IS NULL AND $1 = 0.0))"
	
	bestSongRange = prepare
		("SELECT COUNT(songs.id) " FROM_BEST_SONG_SCORE);
#if 0
	/* can't select multiple, since selecting changes the sort order with each one */
	bestSongs = prepare
		("SELECT songs.id,songs.title " FROM_BEST_SONG_SCORE " ORDER BY score,random() OFFSET ????");
#endif
	bestSong = prepare
		("SELECT songs.id,songs.title " FROM_BEST_SONG_SCORE " ORDER BY score,random() OFFSET $2 LIMIT 1");
	
#define FROM_BEST_RECORDING "FROM recordings LEFT OUTER JOIN ratings ON ratings.id = recordings.id WHERE recordings.song = $1"
	bestRecordingScoreRange = prepare
		("SELECT MIN(ratings.score),MAX(ratings.score) " FROM_BEST_RECORDING);
	bestRecording = prepare
		("SELECT recordings.id " FROM_BEST_RECORDING " AND (score >= $2 OR (score IS NULL AND $2 = 0.0)) ORDER BY score LIMIT 1");
	getPath = prepare
		("SELECT path FROM recordings WHERE id = $1");
	updatePath = prepare
		("UPDATE recordings SET path = $1 WHERE id = $2");
	problem = prepare
		("INSERT INTO problems (id,reason) VALUES ($1,$2)");
	song_problem = prepare
		("INSERT INTO song_problems (id,reason) VALUES ($1,$2)");
	_expireProblems = prepare
		("DELETE FROM problems WHERE clock_timestamp() - created > '1 hour'");
	_expireSongProblems = prepare
		("DELETE FROM song_problems WHERE clock_timestamp() - created > '1 hour'");

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

void enqueue(const char* id,uint32_t len) {
    const char* parameters[] = {id};
    int lens[] = {len};
    const int fmt[] = { 0 };
    PGresult* result = 
        prepare_exec(insertIntoQueue,
                   1,parameters,lens,fmt,0);
    PQassert(result,(long int)result);
    PQclear(result);
}

void enqueuePath(const char* path) {
	const char* parameters[] = {path};
    int len[] = {strlen(path)};
    const int fmt[] = { 0 };
    PGresult* result = 
        prepare_exec(byPath,
                   1,parameters,len,fmt,0);
    PQassert(result,(long int)result);
		puts(path);
		assert(NULL != PQgetvalue(result,0,0));
		enqueue(PQgetvalue(result,0,0),PQgetlength(result,0,0));
    PQclear(result);
}
