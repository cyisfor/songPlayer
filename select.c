#include "pq.h"
#include "config.h"
#include "waittimeout.h"

#include <stdint.h>

#include <sys/types.h>
#include <signal.h>
#include <string.h>

#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <assert.h>

int playin;
int playout;
int queueout;
int queue, player;

#define AVAILABLE 0
#define NEED 1

static void die(const char* message) {
  fputs(message,stderr);
  fputc('\n',stderr);
  exit(23);
}

void launchplayer(void);

static void play(void) {
  static uint32_t lastId = -1;
  if(0==kill(player,SIGCONT))
    launchplayer();
  waitpid(player,NULL,WUNTRACED);
}

static void next(void);

static void done(void) {
  PGresult *result =
    PQexecPrepared(PQconn,"currentSongPlayed",
                   0,NULL,NULL,NULL,0);
  PQassert(result,result && PQresultStatus(result)==PGRES_TUPLES_OK);
  next();
}

static void error(void) {
  fprintf(stderr,"Uhhhhhhhhh....error happened\n");
  sleep(1);
  next();
}

void killplayer(void) {
  if(player<=0) goto SUCCESS;
  if(0==kill(player,SIGTERM)) goto SUCCESS;
  waittimeout();
  if(0==kill(player,SIGTERM)) goto SUCCESS;
  fprintf(stderr,"Player did not die! %d\n",player);
  waittimeout();
  if(0==kill(player,SIGKILL)) goto SUCCESS;
  fprintf(stderr,"Could not kill player. SOMETHING WRONG %d\n",player);
  exit(2);
 SUCCESS:
  player = -1;
}

static void next(void) {
  for(;;) {
    PGresult* result = PQexecPrepared(PQconn,"popTopSong",
                                      0,NULL,NULL,NULL,0);
    int rows = PQntuples(result);
    int cols = PQnfields(result);
    if(rows==cols==1) 
      break;
    kill(queue,SIGCONT);
    uint8_t done;
    read(queueout,&done,1);
  }
  killplayer();
  play();
}

 void launchplayer(void) {
   if(player>0) killplayer();
   int playup[2];
   int playdown[2];
   pipe(playdown);
   pipe(playup);
   player = fork();
   if(player==0) {
     dup2(playdown[0],STDIN_FILENO);
     close(playdown[1]);
     dup2(playup[1],STDOUT_FILENO);
     close(playup[0]);
     execlp(getenv("player"),"player",NULL);
     die("exec player failed");
   } else {
     if (player < 0)
       die("Player fork failed");
   }
   close(playdown[0]);
   close(playup[1]);
   playin = playdown[1];
   playout = playup[0];
 }


int
main (int argc, char ** argv)
{
  waittimeout_setup();

  PQinit();
  struct {
    const char* name;
    const char* query;
  } queries[5] = {
    { "getTopSong",
      "SELECT recording FROM queue ORDER BY id ASC LIMIT 1" },
    /*    { "aoeuaoeugetTopSong",
          "SELECT files.id,replaygain.gain,replaygain.peak,replaygain.level,files.path FROM files INNER JOIN replaygain ON files.track = replaygain.id WHERE files.track = (SELECT which FROM playing)" }, */
    { "getTracksFor",
      "SELECT replaygain.gain,replaygain.peak,replaygain.level,files.path from files INNER JOIN tracks ON files.track = tracks.id INNER JOIN replaygain ON replaygain.id = tracks.id WHERE tracks.recording = $1 ORDER BY tracks.which ASC" },
    { "currentSongWasPlayed",
      "SELECT currentSongwasPlayed()" },
    { "popTopSong",
      "DELETE FROM queue WHERE recording = (SELECT id FROM playing);" },
    { "notPlaying",
      "DELETE FROM playing" } };

  int i;
  for(i=0;i<4;++i) {
    PGresult* result = 
      PQprepare(PQconn,
                queries[i].name,
                queries[i].query,
                0,
                NULL);
    PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
  }

  sems = semget(ftok(argv[0],getpid()), 2, IPC_CREAT | 0600);
  assert(sems != -1);
  
  queue = fork();
  if(queue==0) {
    execlp(getenv("queue"),"queue",argv[0],NULL);
    die("exec failed");
  } else {
    if (queue < 0) 
      die("queue Fork failed");
  }

  launchplayer();
    
  PQinit();
      
  uint8_t action = 0;

  for(;;) {
    ssize_t amt = read(STDIN_FILENO,&action,1);
    if(amt<0) break;
    switch(action) { 
    case 0: play(); break;     
    case 1: done(); break;
    case 2: error(); break;
    case 3: next(); break;
    };
  }
}
