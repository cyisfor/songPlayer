#define _XOPEN_SOURCE 900      /* See feature_test_macros(7) */
#define _GNU_SOURCE

#include "pq.h"
#include "preparation.h"
#include "hash.h"

#include "stringderp.h"

#include <sys/wait.h> // waitpid

#include <stdio.h>
#include <time.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

#include <limits.h>
#include <stdlib.h>
#include <stdbool.h>

#define min(a,b) ((a) < (b) ? (a) : (b))
#define STRCMP(a,b,l) (strcasestr(a,b)==NULL ? 1 : 0)

int forkpipe(int notpipe[2]) {
    int in[2];
    int out[2];
    pipe(in);
    pipe(out);
    int pid = fork();
    if(pid==0) {
        dup2(in[0],0);
        dup2(out[1],1);
        dup2(out[1],2);
        close(in[1]);
        close(out[0]);
    } else {
        notpipe[0] = out[0];
        notpipe[1] = in[1];
        close(out[1]);
        close(in[0]);
    }
    return pid;
}

preparation emptyHashes,
	setHash,
	_checkPath,
	_findRecording,
	updateRecording,
	setPath,
	setAlbum,
	findSong,
	findArtist,
	findAlbum;

static void fixEmptyHashes(void) {
    for(;;) {
        PGresult* empties = prepare_exec(emptyHashes,
                                           0,
                                           NULL,
                                           NULL,
                                           NULL,
                                           0);
        PQassert(empties,empties && PQresultStatus(empties)==PGRES_TUPLES_OK);
        if(PQntuples(empties)==0) break;
        PQbegin();
        int i = 0;
        for(;i<PQntuples(empties);++i) {
            char* id = PQgetvalue(empties,i,0);
            char* path = PQgetvalue(empties,i,1);
            if(path[0]=='\0') continue;
            printf("Path %s\n",path);

            char* h = hash(path);
            const char* values[2] = { id, h };
            int lengths[2] = { strlen(id), strlen(h) };
            int fmt[2] = { 0, 0 };
            PQcheckClear(prepare_exec(setHash,
                                   2,
                                   values,
                                   lengths,
                                   fmt,
                                   0));
            free(h);
        }
        PQcommit();
    }

}

char* findWhatB(preparation what, const char* uniq, ssize_t len) {
    if(uniq==NULL) return NULL;
    const char* values[1] = { uniq };
    int lengths[1] = { len };
    int fmt[1] = { 1 };
    PGresult* r = prepare_exec(what,
															 1,
															 values, lengths, fmt, 0);
    PQassert(r,r && PQresultStatus(r)==PGRES_TUPLES_OK);
    assert(PQntuples(r)==1);
    char* id = strdup(PQgetvalue(r,0,0));
    PQclear(r);
    return id;
}

#define findWhat(a,b) findWhatB(a,b,strlen(b))

void setWhat(preparation what, const char* thing, ssize_t len, const char* id) {
    if(thing==NULL) return;
    const char* values[2] = { id, thing };
    int lengths[2] = { strlen(id), len };
    int fmt[2] = { 0, 1 };
    PGresult* r = prepare_exec(what,
															 2,
															 values, lengths, fmt, 0);
    PQassert(r,r && PQresultStatus(r)==PGRES_COMMAND_OK);
    PQclear(r);
}

char* findRecording(const char* song, const char* recorded, const char* artist, const char* path) {
    char* id = findWhatB(_findRecording,hash(path),hash_length);

    const char* values[4] = { song, recorded, artist, id};
    int lengths[4] = { strlen(song), recorded ? strlen(recorded) : 0, artist ? strlen(artist) : 0, strlen(id) };
    int fmt[4] = { 0, 0, 0, 0};
    PGresult* r = prepare_exec(updateRecording,
                                 4,
                                 values,lengths,fmt,0);
    puts("beep");
    PQassert(r,r&&PQresultStatus(r)==PGRES_COMMAND_OK);
    PQclear(r);
    return id;
}

bool checkPath(const char* path) {
    const char* values[1] = { path };
    int lengths[1] = { strlen(path) };
    int fmt[1] = {0};
    PGresult* r = prepare_exec(_checkPath,
                                 1,
                                 values,lengths,fmt,0);
    if(PQresultStatus(r)==PGRES_TUPLES_OK) {
        if(PQntuples(r) == 1) {
            PQclear(r);
            return true;
        }
    }
    PQclear(r);
    return false;
}

int main(void) {
    srandom(time(NULL));
    PQinit();
		emptyHashes = prepare
			("SELECT id,path FROM recordings WHERE hash IS NULL LIMIT 5");
		setHash = prepare
			("UPDATE recordings SET hash = $2 WHERE id = $1");
		_checkPath = prepare
			("SELECT id FROM recordings WHERE path = $1" );
		_findRecording = prepare
			("SELECT selinsThingRecordings($1)");
		updateRecording = prepare
			("UPDATE recordings SET song=$1, recorded=$2, artist=$3 WHERE id=$4");
		setPath = prepare
			("UPDATE recordings SET path = $2 WHERE id = $1" );
		setAlbum = prepare
			("UPDATE recordings SET album = $2 WHERE id = $1");
		findSong = prepare
			("SELECT selinsThingSongs($1)");
		findArtist = prepare
			("SELECT selinsThingArtists($1)");
		findAlbum = prepare
			("SELECT selinsThingAlbums($1)");
    fixEmptyHashes();
    char* line = NULL;
    char* relpath = NULL;
    size_t amt = 0;
    size_t pathamt = 0;
    for(;;) {
        string title = {};
        string artist = {};
        string album = {};
        struct tm date;
        ssize_t len = getline(&relpath,&pathamt,stdin);
        char path[PATH_MAX];

        if(len<=0) break;
        if(relpath[len-1]=='\n')
            relpath[len-1] = '\0';
        realpath(relpath,path);
        printf("real path %s\n",path);
        if(checkPath(path)) continue;
        char* name = strrchr(path,'/');
        if(name) {
            char* dot = strrchr(path,'.');
            long wheredot = (long)dot - (long)path;
            if(wheredot>7) {
                if(memcmp(dot-7,".vorbis",7)==0)
                    dot = dot - 7;
            }
            name = strndup(name+1,dot?(long)dot-(long)name-1:strlen(name));
        }
        int io[2];
        int pid = forkpipe(io);
        if(pid==0) {
            execlp("ffmpeg","ffmpeg","-i",path,NULL);
            exit(23);
        }
        close(io[1]);
        FILE* info = fdopen(io[0],"r");
        assert(info);
        uint8_t gotDate = 0;
        for(;;) {
            len = getline(&line,&amt,info);
            if(len<=0) break;
            if(line[len-1]=='\n')
                line[len-1] = '\0';
            char* eqs = strchr(line,':');
            if(eqs==NULL) continue;
            *eqs = '\0';
            ++eqs; // the space
            if(0==STRCMP(line,"title",len)) 
							STRINGDUP(title,eqs+1,line+amt-(eqs+1));
            else if(0==STRCMP(line,"artist",len))
							STRINGDUP(artist,eqs+1,line+amt-(eqs+1));
            else if(0==STRCMP(line,"creation_time",len)) {
                memset(&date,0,sizeof(struct tm));
                strptime(eqs+1,"%Y-%m-%d %H:%M:%S",&date);
                gotDate = 1;
            } else if(0==STRCMP(line,"album",len))
							album = STRINGDUP(title,eqs+1,line+amt-(eqs+1));

            if(artist && title && album && gotDate) break;
        }
        if(gotDate==0) {
            time_t now = time(NULL);
            gmtime_r(&now,&date);
            gotDate = 1;
        }
        fclose(info);
        waitpid(pid,NULL,0);
        if(title && title[0]=='\0') {
            free(title);
            title = NULL;
        }
        puts("beep");

        if(title==NULL) {
            title = name;
            printf("yay %s\n",title);
        } else {
            free(name);
            name = NULL;
        }
        printf("Whee '%s' '%s' '%s' '%d'\n",title,artist,album,date.tm_year);

        PQbegin();

        char* songid = findWhat(findSong,UNSTR(title));
        free(title.base);
        char* artistid = findWhat(findArtist,UNSTR(artist));
        free(artist.base);
        char* albumid = findWhat(findAlbum,UNSTR(album));
        free(album.base);

        PQcommit();
        PQbegin();

        printf("loul %s %s %s\n",songid,artistid,albumid);

        char* recorded = NULL;
        if(gotDate) {
            char* template = alloca(0x26); // bleh
            assert(strftime(template,23,"%Y-%m-%d %H:%M:%S",&date)>0);
            strcat(template,".%d");
            recorded = alloca(0x40);
            snprintf(recorded,0x40,template,random());
            printf("got date %s\n",recorded);
            // these are the ends you bring me to postgresql!
        }
        char* recording = findRecording(songid,recorded,artistid,path);
        assert(recording);
        free(songid);
        free(artistid);
        printf("Recording %s\n",recording);
        setWhat(setPath,path,recording);
        if(albumid)
            setWhat(setAlbum,albumid,recording);
        free(albumid);

        PQcommit();

    }
    return 0;
}
