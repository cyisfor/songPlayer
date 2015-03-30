#include "nextreactor.h"
#include "pq.h"
#include "preparation.h"

#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>
#include <error.h>

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

char* durationFormat(const char* value, ssize_t* len) {
  static char buf[0x100];
  unsigned long duration = atol(value) / 1000000000;          
  if(duration > 60) {
    int seconds = duration % 60;
    int moff = snprintf(buf, 0x100, "%um",duration / 60);
    if(seconds) {
      *len = moff + snprintf(buf+moff,0x100-moff," %us",seconds);
    } else {
      *len = moff;
    }
  } else {
    *len = snprintf(buf,0x100,"%us",duration);
  }
  return buf;
}

static void updateLink(void* udata) {
  PGresult* result =
    logExecPrepared(PQconn,"getTopSongPath",
                    0,NULL,NULL,NULL,0);
  if(PQntuples(result) == 0) {
    PQcheckClear(result);
    return;
  }

  PGresult* result2 =
    logExecPrepared(PQconn,"getHistory",
                    0,NULL,NULL,NULL,0);
  
  const char destpath[] = "../index.html.temp";
  int dest = open(destpath,O_WRONLY|O_CREAT|O_TRUNC,0644);
  assert(dest != -1);
  WRITE(dest,"<!DOCTYPE html>\n<html><head>\n");
  WRITE(dest,"<meta http-equiv=\"refresh\" content=\"");

  long duration = atol(PQgetvalue(result,0,4)) / 1000000000;
  struct tm last;
  strptime(PQgetvalue(result2,0,2),"%Y-%m-%d %H:%M:%S",&last);
  // elapsed is now - last
  // left = duration - elapsed
  long left = duration + mktime(&last) - time(NULL); 
  char refresh[0x10];
  write(dest,refresh,snprintf(refresh,0x10,"%u",left + 2));
  WRITE(dest,"\"/>");
           
  WRITE(dest,
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
    WRITE(dest,"  <tr><th>");
    const char* name = PQfname(result,i);
    write(dest,name,strlen(name));
    WRITE(dest,"</th><td>");
    if(i==4) {
      const char* value = durationFormat(PQgetvalue(result,0,i),&len);
      write(dest,value,len);
    } else {
      if(!PQgetisnull(result,0,i)) {
        write(dest,PQgetvalue(result,0,i),PQgetlength(result,0,i));
      }
    }
    WRITE(dest,"</td></tr>\n");
  }
  PQcheckClear(result);
  WRITE(dest,"</table>");
  
  result = result2;
  int rows = PQntuples(result);
  if(rows > 0) {
    WRITE(dest,"<div>Last-played:<table id=\"played\">\n");
    for(i=0;i<rows;++i) {
      WRITE(dest,"  <tr");
      if(i%2==1) {
        WRITE(dest," class=\"o\"");
      }
      WRITE(dest,"><td><a href=\"cache/");
      basename = linkhere(PQgetvalue(result,i,0),PQgetlength(result,i,0),&len);
      write(dest,basename,len);
      WRITE(dest,"\">");
      write(dest,PQgetvalue(result,i,1),PQgetlength(result,i,1));
      WRITE(dest,"</a></td><td>");
      write(dest,PQgetvalue(result,i,2),PQgetlength(result,i,2));
      WRITE(dest,"</td></tr>\n");
    }
    WRITE(dest,"</table></div>\n");
  }

  result = logExecPrepared(PQconn,"upcomingSongs",
                           0,NULL,NULL,NULL,0);
  rows = PQntuples(result);
  if(rows > 0) {
    WRITE(dest,"<div>Upcoming:<ul>\n");
    for(i=0;i<rows;++i) {
      WRITE(dest,"  <li");
      /*if(i%2==1) {
        WRITE(dest," class=\"o\"");
        }*/
      WRITE(dest,"><a href=\"cache/");
      basename = linkhere(PQgetvalue(result,i,0),PQgetlength(result,i,0),&len);
      write(dest,basename,len);
      WRITE(dest,"\">");
      write(dest,PQgetvalue(result,i,1),PQgetlength(result,i,1));
      WRITE(dest,"</a></li>\n");
    }
    WRITE(dest,"</ul></div>\n");
  }
  
  PQcheckClear(result);
  WRITE(dest,"</body></html>\n");

  link("../index.html","../index.save");
  unlink("../index.html");
  if(0!=rename(destpath,"../index.html")) {
    link("../index.save","../index.html");
    unlink("../index.save");
    error(5,errno,"rename fail?");
  }
  close(dest);
}

int main(void) {
  preparation_t query[] = {
    {
      "getTopSongPath",
      "SELECT recordings.path,songs.title,artists.name as artist,albums.title as album, "
      "recordings.duration,"
      "(SELECT connections.strength FROM connections WHERE connections.blue = songs.id AND connections.red = (select id from mode)) AS rating,"
      "songs.played AS \"last played\""
      "FROM queue "
      "INNER JOIN recordings ON recordings.id = queue.recording "
      "INNER JOIN songs ON recordings.song = songs.id "
      "LEFT OUTER JOIN albums ON recordings.album = albums.id "
      "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
      "ORDER BY queue.id ASC LIMIT 1"},
    { "upcomingSongs",
      "SELECT recordings.path, songs.title "
      "FROM queue "
      "INNER JOIN recordings ON recordings.id = queue.recording "
      "INNER JOIN songs ON recordings.song = songs.id "
      "ORDER BY queue.id ASC OFFSET 1"},
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
