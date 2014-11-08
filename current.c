#include "pq.h"
#include "preparation.h"
#include "settitle.h"

#include <stdio.h>

int main (int argc, char ** argv)
{
  settitle("current");
  PQinit();
  preparation_t queries[] = {
    "getTopSong",
      "SELECT songs.title,artists.name as artist,albums.title as album,recordings.duration,"
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
  prepareQueries(queries);
  for(;;) {
      system("clear");
      PGresult* result = 
          logExecPrepared(PQconn,"getTopSong",
                  0,NULL,NULL,NULL,0);
      int i = 0;
      if(PQntuples(result) == 0) {
          puts("(no reply)");
      } else for(;i<PQnfields(result);++i) {
          fputs(PQfname(result,i),stdout);
          fputs(": ",stdout);
          if(i==3) {
              unsigned long duration = atol(PQgetvalue(result,0,i)) / 1000000000;          
              if(duration > 60) {
                  int seconds = duration % 60;
                  printf("%um",duration / 60);
                  if(seconds) {
                      printf(" %us\n",seconds);
                  } else {
                      putchar('\n');
                  }
              } else {
                  printf("%us\n",duration);
              }
          } else {
              const char* val = PQgetvalue(result,0,i);
              if(val) puts(val);
              else puts("(null)");
          }
      }
      sleep(2); // can't set window title using "watch"
  }

  return 0;
}
