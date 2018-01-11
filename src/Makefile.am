AM_CFLAGS = -g 

#bin_PROGRAMS = replay addalbum player import replaygain_scanner scanner dscanner best migrate next graph mode current enqueue enqueuePath testadjust testqueue done ratebytitle ratebyalbum nowplaying nowplaying-make pause playlist

PQ=pq.c preparation.c
# I keep postgresql in ~/.local so hard setting the rpath is convenient
pq_ldflags=-rpath $(shell pkg-config libpq --libs | sed -e's/.*-L//' -e's/ .*//')
# pq.c uses log or something
pq_libs:=$(PQ_LIBS) -lm

QUEUE=$(PQ) queue.c synchronize.c adjust.c

#bin_PROGRAMS = player replay current next enqueue enqueuePath pause import replaygain_scanner scanner duration_scanner best 


bin_PROGRAMS = player replay current
player_CFLAGS = $(PQ_CFLAGS) $(GSTREAMER_CFLAGS)
player_LDADD = $(pq_libs) $(GSTREAMER_LIBS)
player_LDFLAGS = $(pq_ldflags)
player_SOURCES = player.c $(QUEUE) select.c signals.c config.c get_pid.c

replay_CFLAGS = $(PQ_CFLAGS) $(GLIB_CFLAGS)
replay_LDADD = $(pq_libs) $(GLIB_LIBS)
replay_LDFLAGS = -pthread $(pq_ldflags)
replay_SOURCES = replay.c $(QUEUE)

current_CFLAGS = $(PQ_CFLAGS)
current_LDADD = $(pq_libs) 
current_LDFLAGS = $(pq_ldflags)
current_SOURCES = current.c

# current_SOURCES = current.c $(PQ)
# next_SOURCES = next.c $(PQ)
# import_SOURCES = import.c $(PQ)
# replaygain_scanner_SOURCES = replaygain_scanner.c replay.c $(PQ)
# scanner_SOURCES = scanner.c $(PQ)
# duration_scanner_SOURCES = dscanner.c $(PQ)
# best_SOURCES = best.c $(PQ)
# pause_SOURCES = pause.c $(PQ)
# enqueue_SOURCES = enqueue.c $(PQ)
# enqueuePath_SOURCES = enqueuePath.c $(PQ)
