AM_CFLAGS = -g

#bin_PROGRAMS = replay addalbum player import replaygain_scanner scanner dscanner best migrate next graph mode current enqueue enqueuePath testadjust testqueue done ratebytitle ratebyalbum nowplaying nowplaying-make pause playlist

PQ=pq.c preparation.c

bin_PROGRAMS = player replay current next enqueue enqueuePath pause import replaygain_scanner scanner duration_scanner best 
player_CFLAGS = $(PQ_CFLAGS) $(GSTREAMER_CFLAGS)
player_LDADD = $(PQ_LIBS) $(GSTREAMER_LIBS) -lm
player_SOURCES = player.c $(PQ) select.c synchronize.c signals.c queue.c adjust.c config.c get_pid.c

replay_SOURCES = replay.c $(PQ)
current_SOURCES = current.c $(PQ)
next_SOURCES = next.c $(PQ)
import_SOURCES = import.c $(PQ)
replaygain_scanner_SOURCES = replaygain_scanner.c replay.c $(PQ)
scanner_SOURCES = scanner.c $(PQ)
duration_scanner_SOURCES = dscanner.c $(PQ)
best_SOURCES = best.c $(PQ)
pause_SOURCES = pause.c $(PQ)
enqueue_SOURCES = enqueue.c $(PQ)
enqueuePath_SOURCES = enqueuePath.c $(PQ)
