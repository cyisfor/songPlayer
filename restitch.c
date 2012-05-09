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

int
main (int argc, char ** argv)
{
  PQinit();
  struct {
    const char* name;
    const char* query;
  } queries[] = {
    { "multiTrackRecordings",
      "SELECT foo.recording FROM (SELECT recording,count(recording) FROM tracks GROUP BY recording) AS foo WHERE foo.count > 1" },
    { "getTracksFor",
      "SELECT replaygain.gain,replaygain.peak,replaygain.level,which,files.path from files INNER JOIN tracks ON files.track = tracks.id INNER JOIN replaygain ON replaygain.id = tracks.id WHERE tracks.recording = $1 ORDER BY tracks.which ASC" }
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
    for(j=0;j<PQntuples(result2);++j) {
      printf("  %s (%s %s %s %s)\n",
             PQgetvalue(result2,j,4),
             PQgetvalue(result2,j,0),
             PQgetvalue(result2,j,1),
             PQgetvalue(result2,j,2),
             PQgetvalue(result2,j,3));
    }
    PQclear(result2);
  }
  PQclear(result);
}

