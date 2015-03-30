#include "nextreactor.h"
#include "pq.h"
#include "preparation.h"

#include <string.h>
#include <stdlib.h>
#include <assert.h>

struct context {
  char* lastname;
};

#define WRITE(fd,s) write(fd,s,sizeof(s))

static void updateLink(void* udata) {
  struct context* ctx = (struct context*) udata;
  
  PGresult* result =
    logExecPrepared(PQconn,"getTopSongPath",
                    0,NULL,NULL,NULL,0);
  const char* path = PQgetvalue(result,0,0);
  assert(path);
  const char* basename = strrchr(path,'/');
  if(basename == NULL) return;
  basename++;
  if(*basename == '\0') return;

  if(ctx->lastname) {
    unlink(ctx->lastname);
    free(ctx->lastname);
  }
  symlink(path,basename);
  ctx->lastname = strdup(basename);  
  
  char destpath[] = "index.html.XXXXXX";
  int dest = mkstemp(destpath);
  assert(dest != -1);
  WRITE(dest,"<!DOCTYPE html>\n<html><head><title>Now Playing</title></head>\n<body>\n<p>Now Playing: <a href=\"");
  write(dest,basename,strlen(basename));
  WRITE(dest,"\">");
  write(dest,PQgetvalue(result,0,1),PQgetlength(result,0,1));
  PQcheckClear(result);
  WRITE(dest,"</a></p>\n</body></html>\n");
  fchmod(dest,0644);
  unlink("index.html");
  rename(destpath,"index.html");
  close(dest);
}

int main(void) {
  preparation_t query = {
    "getTopSongPath",
    "SELECT recordings.path,songs.title,artists.name as artist,albums.title as album,recordings.duration,"
    "(SELECT connections.strength FROM connections WHERE connections.blue = songs.id AND connections.red = (select id from mode)) AS rating,"
    "(SELECT AVG(connections.strength) FROM connections WHERE connections.red = (select id from mode)) AS average, "
    "songs.played "
    "FROM queue "
    "INNER JOIN recordings ON recordings.id = queue.recording "
    "INNER JOIN songs ON recordings.song = songs.id "
    "LEFT OUTER JOIN albums ON recordings.album = albums.id "
    "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
    "ORDER BY queue.id ASC LIMIT 2"
  };
  PQinit();
  
  prepareQueries(&query);

  struct context ctx = {};

  mkdir("/opt/lighttpd/stuff/nowplaying",0755);
  chdir("/opt/lighttpd/stuff/nowplaying");  
  onNext(updateLink,&ctx);
  exit(23);
}
