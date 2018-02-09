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

addalbum_SOURCES = pq.c preparation.c
best_SOURCES = pq.c preparation.c
current_SOURCES = pq.c preparation.c
done_SOURCES = adjust.c pq.c preparation.c queue.c select.c synchronize.c
dscanner_SOURCES = pq.c preparation.c
enqueue_SOURCES = adjust.c pq.c preparation.c queue.c synchronize.c
enqueuePath_SOURCES = adjust.c pq.c preparation.c queue.c synchronize.c
graph_SOURCES = adjust.c
import_SOURCES = derpstring.c hash.c pq.c preparation.c
migrate_SOURCES = pq.c
mode_SOURCES = adjust.c pq.c preparation.c queue.c synchronize.c
next_SOURCES = config.c get_pid.c pq.c
nowplaying_SOURCES = nextreactor.c pq.c preparation.c
nowplaying_LIBS = $(UV_LIBS)
pause_SOURCES = config.c get_pid.c
player_SOURCES = adjust.c config.c get_pid.c pq.c preparation.c queue.c select.c signals.c synchronize.c
playlist_SOURCES = nextreactor.c pq.c preparation.c
ratebyalbum_SOURCES = pq.c
ratebytitle_SOURCES = pq.c preparation.c
replay_SOURCES = adjust.c pq.c preparation.c queue.c synchronize.c
replaygain_scanner_SOURCES = pq.c preparation.c
testadjust_SOURCES = adjust.c
testqueue_SOURCES = adjust.c pq.c preparation.c queue.c select.c synchronize.c


import_SOURCES += libguess/src/guess.c libguess/src/guess_impl.c libguess/src/guess_tab.c libguess/src/dfa.c

