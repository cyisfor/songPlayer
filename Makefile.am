ACLOCAL_AMFLAGS = -Im4

vpath %.c src

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

libsongdb_la_SOURCES = pq.c preparation.c

addalbum_SOURCES = addalbum.c
addalbum_LIBS = libsongdb

best_SOURCES = best.c
best_LIBS = libsongdb

current_SOURCES = current.c
current_LIBS = libsongdb

done_SOURCES = done.c adjust.c queue.c select.c synchronize.c
done_LIBS = libsongdb

dscanner_SOURCES = dscanner.c
dscanner_LIBS = libsongdb

enqueue_SOURCES = enqueue.c adjust.c queue.c synchronize.c
enqueue_LIBS = libsongdb

enqueuePath_SOURCES = enqueuePath.c adjust.c queue.c synchronize.c
enqueuePath_LIBS = libsongdb

graph_SOURCES = graph.c adjust.c

import_SOURCES = import.c derpstring.c hash.c
import_LIBS = libsongdb

migrate_SOURCES = migrate.c pq.c

mode_SOURCES = mode.c adjust.c queue.c synchronize.c
mode_LIBS = libsongdb

next_SOURCES = next.c config.c get_pid.c pq.c

nowplaying_SOURCES = nowplaying.c nextreactor.c
nowplaying_LIBS = libsongdb $(UV_LIBS)

pause_SOURCES = pause.c config.c get_pid.c

player_SOURCES = player.c adjust.c config.c get_pid.c queue.c select.c signals.c synchronize.c
player_LIBS = libsongdb

playlist_SOURCES = playlist.c nextreactor.c
playlist_LIBS = libsongdb

ratebyalbum_SOURCES = ratebyalbum.c pq.c

ratebytitle_SOURCES = ratebytitle.c 
ratebytitle_LIBS = libsongdb

replay_SOURCES = replay.c adjust.c queue.c synchronize.c
replay_LIBS = libsongdb

replaygain_scanner_SOURCES = replaygain_scanner.c
replaygain_scanner_LIBS = libsongdb

testadjust_SOURCES = testadjust.c adjust.c

testqueue_SOURCES = testqueue.c adjust.c queue.c select.c synchronize.c
testqueue_LIBS = libsongdb

import_SOURCES += libguess/src/guess.c libguess/src/guess_impl.c libguess/src/guess_tab.c libguess/src/dfa.c

