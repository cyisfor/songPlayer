#include "nextreactor.h"
#include "pq.h"
#include "preparation.h"

#include <string.h>
#include <stdlib.h>
#include <assert.h>

#define WRITE(fd,s) write(fd,s,sizeof(s)-1)

static void surelink(const char*src, const char*dest) {
  if(0==symlink(src,dest)) return;
  unlink(dest);
  assert(0==symlink(src,dest));
}

static char* linkhere(const char* path, ssize_t pathlen, ssize_t* len) {
  assert(path);
  const char* basename = path+pathlen-1;
  for(;;) {
    if(basename==path) break;
    if(*basename=='/') {
      ++basename;
      break;
    }
    --basename;
  }
  *len = pathlen - (basename - path);
  if(*len == 0) return NULL;

  surelink(path,basename);
  return basename;
}

static void updateLink(void* udata) {
  PGresult* result =
    logExecPrepared(PQconn,"getTopSongPath",
                    0,NULL,NULL,NULL,0);
  if(PQntuples(result) == 0) {
    PQcheckClear(result);
    return;
  }
  
  char destpath[] = "latest.html.XXXXXX";
  int dest = mkstemp(destpath);
  assert(dest != -1);
  WRITE(dest,"<!DOCTYPE html>\n<html><head><title>Now Playing</title></head>\n<body>\n<p>Now Playing: <a href=\"");  
  ssize_t len = 0;  
  const char* basename = linkhere(PQgetvalue(result,0,0),PQgetlength(result,0,0,),&len);
  
  write(dest,basename,len);
  WRITE(dest,"\">");
  write(dest,PQgetvalue(result,0,1),PQgetlength(result,0,1));
  PQcheckClear(result);
  WRITE(dest,"</a></p>\n");

  result = logExecPrepared(PQconn,"getHistory",
                           0,NULL,NULL,NULL,0);
  int i,rows=PQntuples(result);
  if(rows==0) {
  } else {
    WRITE(dest,"<p>Last-played:<ul>");
    for(i=0;i<rows;++i) {
      WRITE(dest,"  <li><a href=\"");
      basename = linkhere(PQgetvalue(result,i,0),PQgetlength(result,i,0),&len);
      write(dest,basename,len);
      WRITE(dest,"\">");
      write(dest,PQgetvalue(result,i,1),PQgetlength(result,i,1));
      WRITE(dest,"</a> ");
      write(dest,PQgetvalue(result,i,2),PQgetlength(result,i,2));
      WRITE(dest,"</li>\n");
    }
    WRITE(dest,"</p>\n");
  }
  PQcheckClear(result);
  WRITE(dest,"</body></html>\n");

  fchmod(dest,0644);
  unlink("index.html");
  rename(destpath,"latest.html");
  close(dest);
}

int main(void) {
  preparation_t query[] = {
    {
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
    "ORDER BY queue.id ASC"},
    {
      "getHistory",
      "SELECT recordings.path,songs.title,artists.name as artist,albums.title as album,recordings.duration,"
      "(SELECT connections.strength FROM connections WHERE connections.blue = songs.id AND connections.red = (select id from mode)) AS rating,"
      "(SELECT AVG(connections.strength) FROM connections WHERE connections.red = (select id from mode)) AS average, "
      "songs.played "
      "FROM history "
    "INNER JOIN recordings ON recordings.id = history.recording "
    "INNER JOIN songs ON recordings.song = songs.id "
    "LEFT OUTER JOIN albums ON recordings.album = albums.id "
    "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
    }
  };
  PQinit();
  
  prepareQueries(query);

  mkdir("/opt/lighttpd/www/stuff/nowplaying",0755);
  chdir("/opt/lighttpd/www/stuff/nowplaying");
  updateLink(NULL);
  onNext(updateLink,NULL);
  exit(23);
}
