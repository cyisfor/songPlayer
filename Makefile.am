ACLOCAL_AMFLAGS = -Im4

bin_PROGRAMS = \
addalbum \
best \
current \
done \
dscanner \
enqueue \
enqueuePath \
graph \
import \
migrate \
mode \
next \
nowplaying \
pause \
player \
playlist \
ratebyalbum \
ratebytitle \
replay \
replaygain_scanner \
testadjust \
testqueue

noinst_LTLIBRARIES = libsongdb.la

libsongdb_la_SOURCES = src/pq.c src/preparation.c
libsongdb_la_CFLAGS = $(DB_CFLAGS)
libsongdb_la_LIBADD = src/$(DB_LIBS)

addalbum_SOURCES = src/addalbum.c
addalbum_LIBS = src/libsongdb

best_SOURCES = src/best.c
best_LIBS = src/libsongdb

current_SOURCES src/= csrc/urrent.c
current_LIBS = src/libsongdb

done_SOURCES = src/done.c src/adjust.c src/queue.c src/select.c src/synchronize.c
done_LIBS = src/libsongdb

dscanner_SOURCES = src/dscanner.c
dscanner_LIBS = src/libsongdb

enqueue_SOURCES = src/enqueue.c src/adjust.c src/queue.c src/synchronize.c
enqueue_LIBS = src/libsongdb

enqueuePath_SOURCES = src/enqueuePath.c src/adjust.c src/queue.c src/synchronize.c
enqueuePath_LIBS = src/libsongdb

graph_SOURCES = src/graph.c src/adjust.c

import_SOURCES = src/import.c src/derpstring.c src/hash.c
import_LIBS = src/libsongdb

migrate_SOURCES = src/migrate.c
migrate_LIBS = src/libsongdb

mode_SOURCES = src/mode.c src/adjust.c src/queue.c src/synchronize.c
mode_LIBS = src/libsongdb

next_SOURCES = src/next.c csrc/onfig.c src/get_pid.c
next_LIBS = src/libsongdb

nowplaying_SOURCES = src/nowplaying.c src/nextreactor.c
nowplaying_LIBS = libsongdb src/$(UV_LIBS)

pause_SOURCES = src/pause.c csrc/onfig.c src/get_pid.c

player_SOURCES = src/player.c src/adjust.c csrc/onfig.c src/get_pid.c src/queue.c src/select.c src/signals.c src/synchronize.c
player_LIBS = src/libsongdb

playlist_SOURCES = src/playlist.c src/nextreactor.c
playlist_LIBS = src/libsongdb

ratebyalbum_SOURCES = src/ratebyalbum.c
ratebyalbum_LIBS = src/libsongdb

ratebytitle_SOURCES = src/ratebytitle.c 
ratebytitle_LIBS = src/libsongdb

replay_SOURCES = src/replay.c src/adjust.c src/queue.c src/synchronize.c
replay_LIBS = src/libsongdb

replaygain_scanner_SOURCES = src/replaygain_scanner.c
replaygain_scanner_LIBS = src/libsongdb

testadjust_SOURCES = src/testadjust.c src/adjust.c

testqueue_SOURCES = src/testqueue.c src/adjust.c src/queue.c src/select.c src/synchronize.c
testqueue_LIBS = src/libsongdb

import_SOURCES += src/libguess/src/guess.c src/libguess/src/guess_impl.c src/libguess/src/guess_tab.c src/libguess/src/dfa.c

