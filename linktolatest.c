#include "nextreactor.h"
#include "pq.h"
#include "preparation.h"

#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#define WRITE(fd,s) write(fd,s,sizeof(s)-1)

static void surelink(const char*src, const char*dest) {
  if(0==symlink(src,dest)) return;
  unlink(dest);
  assert(0==symlink(src,dest));
}

static const char* linkhere(const char* path, ssize_t pathlen, ssize_t* len) {
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
  
  const char destpath[] = "../index.html.temp";
  int dest = open(destpath,O_WRONLY|O_CREAT|O_TRUNC,0644);
  assert(dest != -1);
  WRITE(dest,"<!DOCTYPE html>\n<html><head>\n"
        "<link href=\"style.css\" rel=\"stylesheet\" type=\"text/css\"/>\n"
        "<title>Now Playing</title></head>\n<body>\n<p>Now Playing: <a href=\"cache/");  
  ssize_t len = 0;  
  const char* basename = linkhere(PQgetvalue(result,0,0),PQgetlength(result,0,0),&len);
  
  write(dest,basename,len);
  WRITE(dest,"\">");
  write(dest,PQgetvalue(result,0,1),PQgetlength(result,0,1));
  WRITE(dest,"</a></p>\n");
  WRITE(dest,"<table id=\"info\">");
  int i;
  int cols = PQnfields(result);
  for(i=2;i<cols;++i) {
    WRITE(dest,"  <td>");
    const char* name = PQfname(result,i);
    write(dest,name,strlen(name));
    WRITE(dest,"</td><td>");
    if(!PQgetisnull(result,0,i)) {
      write(dest,PQgetvalue(result,0,i),PQgetlength(result,0,i));
    }
    WRITE(dest,"</td>\n");
  }
  PQcheckClear(result);
  WRITE(dest,"</table>");
    
  result = logExecPrepared(PQconn,"getHistory",
                           0,NULL,NULL,NULL,0);
  int rows = PQntuples(result);
  if(rows==0) {
  } else {
    WRITE(dest,"<p>Last-played:<ul>");
    for(i=0;i<rows;++i) {
      WRITE(dest,"  <li><a href=\"cache/");
      basename = linkhere(PQgetvalue(result,i,0),PQgetlength(result,i,0),&len);
      write(dest,basename,len);
      WRITE(dest,"\">");
      write(dest,PQgetvalue(result,i,1),PQgetlength(result,i,1));
      WRITE(dest,"</a> ");
      write(dest,PQgetvalue(result,i,2),PQgetlength(result,i,2));
      WRITE(dest,"</li>\n");
    }
    WRITE(dest,"</ul></p>\n");
  }
  PQcheckClear(result);
  WRITE(dest,"</body></html>\n");

  unlink("../index.html");
  rename(destpath,"../index.html");
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
      "SELECT recordings.path,songs.title,history.played "
      "FROM history "
      "INNER JOIN recordings ON recordings.id = history.recording "
      "INNER JOIN songs ON recordings.song = songs.id "
      "LEFT OUTER JOIN albums ON recordings.album = albums.id "
      "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
      "ORDER BY played desc LIMIT 16"
    }
  };
  PQinit();
  
  prepareQueries(query);

  mkdir("/opt/lighttpd/www/stuff/nowplaying",0755);
  mkdir("/opt/lighttpd/www/stuff/nowplaying/cache",0755);
  chdir("/opt/lighttpd/www/stuff/nowplaying/cache");
  updateLink(NULL);
  onNext(updateLink,NULL);
  exit(23);
}
