#include "pq.h"
#include "preparation.h"

#include <gst/gst.h> // just for GST_SECOND

//#define DEBUG

#ifdef DEBUG
#define SONG_COLUMNS "songs.id,songs.title,ratings.score"
#else
#define SONG_COLUMNS "songs.id"
#endif

void main(int argc, char** argv) {
    if(argc<2) exit(1);
    double maxDuration = strtod(argv[1],NULL) * 3600; // hours -> seconds
    preparation_t queries[] = {
        { "noTime",
            "delete from connections where red = 1" },
        { "resetRatings",
            "DELETE FROM ratings" },
        { "doRate",
            "select rate(0,100)" },
        { "zeroRated",
            "insert into ratings (id,score) select songs.id,0 from songs left outer join ratings on ratings.id = songs.id where ratings.id IS NULL" },
        { "listSongs",
"select " SONG_COLUMNS " from songs inner join ratings on songs.id = ratings.id order by score+10*random() DESC" },
        { "aRecording",
            "SELECT path,duration FROM recordings WHERE song = $1 ORDER BY random() LIMIT 1" },
    };
    PQinit();
    prepareQueries(queries);
    PQbegin();
    PQcheckClear(logExecPrepared(PQconn,"noTime",
                 0,NULL,NULL,NULL,0));
    PQcheckClear(logExecPrepared(PQconn,"resetRatings",
                 0,NULL,NULL,NULL,0));
    PQcheckClear(logExecPrepared(PQconn,"doRate",
                 0,NULL,NULL,NULL,0));
    PQcheckClear(logExecPrepared(PQconn,"zeroRated",
                 0,NULL,NULL,NULL,0));
    PGresult* songs = logExecPrepared(PQconn,"listSongs",
            0,NULL,NULL,NULL,0);


    double currentDuration = 0.0;

    int i;
    for(i=0;i<PQntuples(songs);++i) {
        const char* values[] = { PQgetvalue(songs,i,0) };
        int lengths[] = { PQgetlength(songs,i,0) };
        int fmt[] = { 0 };
        PGresult* recordings = logExecPrepared(PQconn,"aRecording",
                1,values,lengths,fmt,0);
        puts(PQgetvalue(recordings,0,0));
        currentDuration += strtod(PQgetvalue(recordings,0,1),NULL) / GST_SECOND;
        PQclear(recordings);
#ifdef DEBUG
        printf("%s %s %s %lf/%lf\n",PQgetvalue(songs,i,0),PQgetvalue(songs,i,2),PQgetvalue(songs,i,1),currentDuration,maxDuration);
#endif
        if(currentDuration >= maxDuration) break;
    }

    PQclear(songs);
    exit(0);
}
