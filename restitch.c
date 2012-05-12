#include "pq.h"

#include <stdint.h>

#include <sys/types.h>
#include <signal.h>
#include <string.h>

#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <assert.h>

static void die(const char* message) {
  fputs(message,stderr);
  fputc('\n',stderr);
  exit(23);
}

enum filetype {
  UNKNOWN,
  MP3,
  FLAC,
  OGG
};

int
main (int argc, char ** argv)
{
  PQinit();
  struct {
    const char* name;
    const char* query;
  } queries[] = {
    { "multiTrackRecordings",
      "SELECT foo.recording FROM (SELECT recording,count(recording) FROM tracks GROUP BY recording) AS foo WHERE foo.count > 1 ORDER BY recording" },
    { "getTracksFor",
      "SELECT replaygain.gain,replaygain.peak,replaygain.level,tracks.id,which,files.path,(SELECT coalesce(title,'?\?\?') FROM songs WHERE id = (SELECT song FROM recordings WHERE id = $1)) || '::' || coalesce(tracks.title,'?\?\?\?') from files INNER JOIN tracks ON files.track = tracks.id INNER JOIN replaygain ON replaygain.id = tracks.id WHERE tracks.recording = $1 ORDER BY tracks.which ASC" }
  };

  PQinit();

  int i;
  for(i=0;i<sizeof(queries)/sizeof(const char*)/2;++i) {
    fprintf(stderr,"Whee %d\n",i);
    fprintf(stderr,"Preparing %s\n",queries[i].name);
    PGresult* result = 
      PQprepare(PQconn,
                queries[i].name,
                queries[i].query,
                0,
                NULL);
    PQassert(result,result && PQresultStatus(result)==PGRES_COMMAND_OK);
    PQclear(result);
  }

  PGresult* result = PQexecPrepared(PQconn,"multiTrackRecordings",
                                    0,NULL,NULL,NULL,0);
  int rows = PQntuples(result);
  int cols = PQnfields(result);
  const int fmt = 0;
  char* end = NULL;
  for(i=0;i<rows;++i) {
    char* recording = PQgetvalue(result,i,0);
    int len = strlen(recording);
    uint32_t id = strtol(recording,&end,10);
    PGresult* result2 = PQexecPrepared(PQconn,"getTracksFor",
                                       1,(const char* const*)&recording,&len,&fmt,0);
    printf("Recording %d\n",id);
    int j;
    enum filetype type = UNKNOWN;

    for(j=0;j<PQntuples(result2);++j) {
      printf("%s  %s\n",
             PQgetvalue(result2,j,4),
             PQgetvalue(result2,j,6));
      printf("  (%s %s %s %s)\n",
             PQgetvalue(result2,j,0),
             PQgetvalue(result2,j,1),
             PQgetvalue(result2,j,2),
             PQgetvalue(result2,j,3));
      char* path = PQgetvalue(result2,j,5);
      if(type==UNKNOWN) {
        ssize_t len = strlen(path);
        if(0==strcmp(path+len-4,".mp3"))
          type = MP3;
        else if(0==strcmp(path+len-4,".ogg"))
          type = OGG;
        else if(0==strcmp(path+len-5,".flac"))
          type = FLAC;
        else 
          die("Uknown toypoe");
      }
    }

    char dest[0x1000] = "/home/extra/music/restitch/";
    mkdir(dest,0755);
    char* edest = dest + sizeof("/home/extra/music/restitch/") - 1;
    const ssize_t elen = 0x1000 - sizeof("/home/extra/music/restitch/") + 1;

    if(type==UNKNOWN)
      die("Unknown type");

    snprintf(edest,elen,"%x.%s",id,
             type == FLAC ? "flac" : 
             (type == OGG ? "ogg" : 
              (type == MP3 ? "mp3" : "aoeusthoesunhtsnhaoeu")));

    struct stat buf;

    if(stat(dest,&buf)!=0) {

      printf("Dest: %s\n",edest);
        
      char** soxargs = malloc(sizeof(char*)*(PQntuples(result2)+6));
      soxargs[0] = "sox";
      soxargs[1] = "--combine";
      soxargs[2] = "concatenate";
      for(j=0;j<PQntuples(result2);++j) {
        char* path = PQgetvalue(result2,j,5);
        printf("-- %s\n",path);
        soxargs[3+j] = path;
      }
      // output file = ????
      soxargs[j+4] = NULL;
      printf("Type = %x\n",type);

      int status = 0;
#define CHECK(status) if (!WIFEXITED(status) || 0 != WEXITSTATUS(status)) die("Blerpgh");
    
      if(type==MP3) {
        soxargs[j+3] = "-";
      
        int tolame[2];
        pipe(tolame);
        int soxpid = fork();
        assert(soxpid>=0);
        if(soxpid==0) {
          close(tolame[0]);
          dup2(tolame[1],STDOUT_FILENO);
          execvp("echo",soxargs);
          die("exec failed");
        }
        int lamepid = fork();
        assert(lamepid>=0);
        if(lamepid==0) {
          close(tolame[1]);
          dup2(tolame[0],STDIN_FILENO);
          execlp("lame","lame","-",dest,NULL);
        }
        waitpid(soxpid,&status,0);
        CHECK(status);
        waitpid(lamepid,&status,0);
        CHECK(status);
        exit(42);
      } else {
        soxargs[j+3] = dest;
        int jj;
        for(jj=0;jj<j;++jj) {
          printf("arg: %x %s\n",jj,soxargs[jj]);
        }

        int soxpid = fork();
        assert(soxpid>=0);
        if(soxpid==0) {
          execvp("sox",soxargs);
          die("exec faileded");
        }
        waitpid(soxpid,&status,0);
        CHECK(status);
      }
    }
    PQclear(result2);
  }
  PQclear(result);
}

