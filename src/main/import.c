#define _GNU_SOURCE
#define _XOPEN_SOURCE 900      /* See feature_test_macros(7) */

#include "libguess/libguess.h"
#include "../pq.h"
#include "../preparation.h"
#include "../hash.h"

#include "../derpstring.h"

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
    assert(0==pipe(in));
    assert(0==pipe(out));
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

#define DERPVAL(a) PQgetvalue(a,0,0)
#define DERPLEN(a) PQgetlength(a,0,0)

#define STRING_FOR_PRINTF(str) (int)str.len, str.base

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
                                           1);
        PQassert(empties,empties && PQresultStatus(empties)==PGRES_TUPLES_OK);
        if(PQntuples(empties)==0) break;
        PQbegin();
        int i = 0;
        for(;i<PQntuples(empties);++i) {
            char* id = PQgetvalue(empties,i,0);
						char* path = PQgetvalue(empties,i,1);
            if(path[0]=='\0') continue;

            const char* values[2] = { id, hash(path) };
            int lengths[2] = { PQgetlength(empties,i,0), hash_length };
            int fmt[2] = { 1, 1 };
            PQcheckClear(prepare_exec(setHash,
                                   2,
                                   values,
                                   lengths,
                                   fmt,
                                   1));
        }
        PQcommit();
				PQcheckClear(empties);
    }

}

PGresult* findWhat(preparation what, string uniq) {
    if(uniq.base==NULL) return NULL;
    const char* values[1] = { uniq.base };
    int lengths[1] = { uniq.len };
    int fmt[1] = { 1 };
		printf("mtat %s %d\n",uniq.base,uniq.base[uniq.len-1]);
    PGresult* r = prepare_exec(what,
															 1,
															 values, lengths, fmt, 1);
    PQassert(r,r && PQresultStatus(r)==PGRES_TUPLES_OK);
    assert(PQntuples(r)==1);
		return r;
}

PGresult* findWhatArgh(preparation what, string uniq) {
    if(uniq.base==NULL) return NULL;
    const char* values[1] = { uniq.base };
    int lengths[1] = { uniq.len };
    int fmt[1] = { 0 };
		printf("mtat %s %d\n",uniq.base,uniq.base[uniq.len-1]);
    PGresult* r = prepare_exec(what,
															 1,values, lengths, fmt, 1);
    PQassert(r,r && PQresultStatus(r)==PGRES_TUPLES_OK);
    assert(PQntuples(r)==1);
		return r;
}

void setWhat(preparation what, string thing, PGresult* id) {
    if(thing.base==NULL) return;
    const char* values[2] = { DERPVAL(id), thing.base };
    int lengths[2] = { DERPLEN(id), thing.len };
    int fmt[2] = { 1, 1 };
    PGresult* r = prepare_exec(what,
															 2,
															 values, lengths, fmt, 1);
    PQassert(r,r && PQresultStatus(r)==PGRES_COMMAND_OK);
    PQclear(r);
}
void setWhatCsux(preparation what, PGresult* thing, PGresult* id) {
    if(thing==NULL) return;
    const char* values[2] = { DERPVAL(id), DERPVAL(thing) };
    int lengths[2] = { DERPLEN(id), DERPLEN(thing) };
    int fmt[2] = { 1, 1 };
    PGresult* r = prepare_exec(what,
															 2,
															 values, lengths, fmt, 1);
    PQassert(r,r && PQresultStatus(r)==PGRES_COMMAND_OK);
    PQclear(r);
}

PGresult* findRecording(string title, string artist, string album, string recorded, string path) {

	assert(path.len > 2);
	
	const char* values[6] = { hash(path.base),
														title.base,
														artist.base,
														album.base,
														recorded.base,														
														path.base
	};
	int lengths[6] = { hash_length,
										 title.len,
										 artist.len,
										 album.len,
										 recorded.len,
										 path.len
	};
	int fmt[6] = { 1, 1, 1, 1, 0, 1};
	PGresult* id = prepare_exec(_findRecording,
														 6,
														 values,lengths,fmt,1);
	PQassert(id,id&&PQresultStatus(id)==PGRES_TUPLES_OK);
	return id;
}

bool checkPath(string path) {
    const char* values[1] = { path.base };
    int lengths[1] = { path.len };
    int fmt[1] = {1};
    PGresult* r = prepare_exec(_checkPath,
                                 1,
                                 values,lengths,fmt,1);
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
			("SELECT findRecording($1::bytea,$2,$3,$4,$5,$6::bytea)");
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

        if(len<=0) break;
        if(relpath[len-1]=='\n')
            relpath[len-1] = '\0';
				char derp[PATH_MAX];
				string path = {
					derp,
					0
				};
        realpath(relpath,path.base);
        printf("real path %s\n",path.base);
//        if(checkPath(path)) continue;
				path.len = strlen(path.base);
				string csux(void) {
					char* name = strrchr(path.base,'/');
					struct string csux = {};
					if(name) {
            char* dot = strrchr(path.base,'.');
            long wheredot = (long)dot - (long)path.base;
            if(wheredot>7) {
                if(memcmp(dot-7,".vorbis",7)==0)
                    dot = dot - 7;
            }

						csux.len = dot?(long)dot-(long)name-1:strlen(name);
            csux.base = memdup(name+1,csux.len);
					}
					return csux;
				}
        string name = csux();
        int io[2];
        int pid = forkpipe(io);
        if(pid==0) {
            execlp("ffmpeg","ffmpeg","-i",path.base,NULL);
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
            if(0==STRCMP(line,"title",len)) {
							STRINGDUP(title,eqs+1,line+amt-(eqs+3));
						} else if(0==STRCMP(line,"artist",len)) {
							STRINGDUP(artist,eqs+1,line+amt-(eqs+3));
						} else if(0==STRCMP(line,"creation_time",len)) {
                memset(&date,0,sizeof(struct tm));
                strptime(eqs+1,"%Y-%m-%d %H:%M:%S",&date);
                gotDate = 1;
            } else if(0==STRCMP(line,"album",len)) {
							STRINGDUP(album,eqs+1,line+amt-(eqs+3));
						}
            if(artist.base && title.base && album.base && gotDate) break;
        }
        if(gotDate==0) {
            time_t now = time(NULL);
            gmtime_r(&now,&date);
            gotDate = 1;
        }
        fclose(info);
        waitpid(pid,NULL,0);
        if(title.len == 0) {
            free(title.base);
            title.base = NULL;
        }
				if(title.base==NULL) {
            title.base = name.base;
						title.len = name.len;
        } else {
            free(name.base);
            name.base = NULL;
        }
        printf("Whee '%.*s' '%.*s' '%.*s' '%d'\n",
			   STRING_FOR_PRINTF(title),
			   STRING_FOR_PRINTF(artist),
			   STRING_FOR_PRINTF(album),
			   date.tm_year);
		
		const char* charset = libguess_determine_encoding(title.base,title.len,"Baltic");
		if(0!=strcmp(charset,"UTF-8")) {
			puts(charset);
			exit(23);
		}

		printf("charset: %s\n", charset);

        PQbegin();

        string recorded = {};
        if(gotDate) {
            char* template = alloca(0x26); // bleh
            assert(strftime(template,23,"%Y-%m-%d %H:%M:%S",&date)>0);
            strcat(template,".%d");
            recorded.base = alloca(0x40);
            recorded.len = snprintf(recorded.base,0x40,template,random());
            printf("got date %.*s\n",STRING_FOR_PRINTF(recorded));
            // these are the ends you bring me to postgresql!
        }
        PQcheckClear(findRecording(title,artist,album,recorded,path));

        PQcommit();

    }
    return 0;
}
