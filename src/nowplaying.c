#define _XOPEN_SOURCE
#define _XOPEN_SOURCE_EXTENDED // symlink
#include "nextreactor.h"
#include "pq.h"
#include "preparation.h"

#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <errno.h>
#include <error.h>
#include <time.h>
#include <sys/stat.h> // mkdir
#include <unistd.h> // symlink


#define WRITE(fd,s) write(fd,s,sizeof(s)-1)

static void surelink(const char*src, const char*dest) {
  if(0==symlink(src,dest)) return;
  unlink(dest);
  assert(0==symlink(src,dest));
}

static const char* getbasename(const char* path, ssize_t pathlen, ssize_t* len) {
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

  return basename;
}

static const char* linkhere(const char* path, ssize_t pathlen, ssize_t* len) {
	const char* basename = getbasename(path,pathlen,len);
  surelink(path,basename);
	return basename;
}


char* durationFormat(const char* value, ssize_t* len) {
  static char buf[0x100];
  unsigned long duration = atol(value) / 1000000000;
  if(duration > 60) {
    int seconds = duration % 60;
    int moff = snprintf(buf, 0x100, "%lum",duration / 60);
    if(seconds) {
      *len = moff + snprintf(buf+moff,0x100-moff," %ds",seconds);
    } else {
      *len = moff;
    }
  } else {
    *len = snprintf(buf,0x100,"%lus",duration);
  }
  return buf;
}

preparation getTopSongPath = NULL;
preparation getHistory = NULL;
preparation upcomingSongs = NULL;

static void updateLink(void* udata) {
  PGresult* result =
    prepare_exec(getTopSongPath,
                    0,NULL,NULL,NULL,0);
  if(PQntuples(result) == 0) {
    PQcheckClear(result);
    return;
  }

  PGresult* result2 =
    prepare_exec(getHistory,
                    0,NULL,NULL,NULL,0);

  const char destpath[] = "../index.html.temp";
  int dest = open(destpath,O_WRONLY|O_CREAT|O_TRUNC,0644);
  assert(dest != -1);
  WRITE(dest,"<!DOCTYPE html>\n<html><head>\n");
  WRITE(dest,"<meta http-equiv=\"refresh\" content=\"");

  long duration = atol(PQgetvalue(result,0,4)) / 1000000000;
  struct tm lasttm = {};
  strptime(PQgetvalue(result2,0,2),"%Y-%m-%d %H:%M:%S",&lasttm);
  time_t last = mktime(&lasttm);
  // elapsed is now - last
  // left = duration - elapsed
  long elapsed = time(NULL) - last;
  long left = duration - elapsed;
  printf("ummmm duration %lu elapsed %lu now %lu last %lu left %lu\n",
         duration,elapsed,time(NULL),last,left);
  char refresh[0x10];
  write(dest,refresh,snprintf(refresh,0x10,"%ld",left + 72));
  WRITE(dest,"\"/>");
  WRITE(dest,"<script type=\"text/javascript\">\n");
  WRITE(dest,"var finished = new Date(");
  write(dest,refresh,snprintf(refresh,0x10,"%ld",last+duration+72));
  WRITE(dest,"000);\n"
        "var left = finished - new Date();\n"
        "if(left > 1000) {\n"
        "  console.log('reloading in',left,'on',finished);\n"
        "  var timeout = setTimeout(function() { document.location.reload(true); }, Math.max(1000,left));\n"
        "}\n"
        "</script>");

  WRITE(dest,
        "<link href=\"style.css\" rel=\"stylesheet\" type=\"text/css\"/>\n"
        "<title>Now Playing</title></head>\n<body>\n<p>Now Playing: <a href=\"cache/");
  ssize_t len = 0;
  const char* basename = linkhere(PQgetvalue(result,0,0),PQgetlength(result,0,0),&len);

  write(dest,basename,len);
  WRITE(dest,"\">");
  write(dest,PQgetvalue(result,0,1),PQgetlength(result,0,1));
  WRITE(dest,"</a></p>\n");

	int playlist = open("../playlist.m3u.temp",O_WRONLY|O_CREAT|O_TRUNC,0644);
	assert(playlist > 0);
	WRITE(playlist,
				"http://[fcd9:e703:498e:5d07:e5fc:d525:80a6:a51c]/stuff/nowplaying/cache/");
	write(playlist,basename,len);
	WRITE(playlist,"\n");

	WRITE(playlist,
					"http://[fcd9:e703:498e:5d07:e5fc:d525:80a6:a51c]/stuff/nowplaying/playlist.m3u\n");
	close(playlist);
	assert(0==rename("../playlist.m3u.temp","../playlist.m3u"));
	
  WRITE(dest,"<table id=\"info\">");
  int i;
  int cols = PQnfields(result);
  for(i=2;i<cols;++i) {
    WRITE(dest,"  <tr");
	if(i%2==0) {
	  WRITE(dest," class=\"o\"");
	}
	WRITE(dest,"><th>");
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
      basename = linkhere
				(PQgetvalue(result,i,0),PQgetlength(result,i,0),&len);
      write(dest,basename,len);
      WRITE(dest,"\">");
      write(dest,PQgetvalue(result,i,1),PQgetlength(result,i,1));
      WRITE(dest,"</a></td><td>");
      write(dest,PQgetvalue(result,i,2),PQgetlength(result,i,2));
      WRITE(dest,"</td></tr>\n");
    }
		WRITE(dest,"</table></div>\n");
  }

  result = prepare_exec(upcomingSongs,
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
	pq_application_name = "now playing";
  PQinit();
	getTopSongPath = prepare
		("SELECT recordings.path, "
	  "songs.title, "
#include "nowplaying.fields.ch"
      "FROM queue "
      "INNER JOIN recordings ON recordings.id = queue.recording "
      "INNER JOIN songs ON recordings.song = songs.id "
      "LEFT OUTER JOIN albums ON recordings.album = albums.id "
      "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
      "ORDER BY queue.id ASC LIMIT 1");
	upcomingSongs = prepare
		("SELECT recordings.path, songs.title "
      "FROM queue "
      "INNER JOIN recordings ON recordings.id = queue.recording "
      "INNER JOIN songs ON recordings.song = songs.id "
      "ORDER BY queue.id ASC OFFSET 1");
	getHistory = prepare
		("SELECT recordings.path,songs.title,history.played "
		 "FROM history "
		 "INNER JOIN recordings ON recordings.id = history.recording "
		 "INNER JOIN songs ON recordings.song = songs.id "
		 "LEFT OUTER JOIN albums ON recordings.album = albums.id "
		 "LEFT OUTER JOIN artists ON recordings.artist = artists.id "
		 "ORDER BY played desc LIMIT 16");


  mkdir("/custom/lighttpd/www/stuff/nowplaying",0755);
  chdir("/custom/lighttpd/www/stuff/nowplaying");
	mkdir("cache",0755);
  chdir("cache");
  updateLink(NULL);
  onNext(updateLink,NULL);
  exit(23);
}
