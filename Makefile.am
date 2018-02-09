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

noinst_PROGRAMS = nowplaying-make

lib_LTLIBRARIES = libsongdb.la

# since automake SUCKS you have to do this manually
# all programs using queue.c must manually add GLIB_CFLAGS/LIBS
# all programs using libsongdb must manually add DB_CFLAGS
# all programs using 

libsongdb_la_SOURCES = src/pq.c src/preparation.c
libsongdb_la_CFLAGS = $(DB_CFLAGS)
libsongdb_la_LIBADD = $(DB_LIBS)

addalbum_SOURCES = src/addalbum.c
addalbum_LDADD = libsongdb.la
addalbum_CFLAGS = $(DB_CFLAGS)

best_SOURCES = src/best.c
best_LDADD = libsongdb.la $(MEDIA_LIBS)
best_CFLAGS = $(DB_CFLAGS) $(MEDIA_CFLAGS)

current_SOURCES = src/current.c current.glade.ch
current_LDADD = libsongdb.la $(GUI_LIBS)
current_CFLAGS = $(DB_CFLAGS) $(GUI_CFLAGS)

BUILT_SOURCES = current.glade.ch nowplaying.fields.ch

%.ch: %.xml ./data_to_header_string/pack
	name=gladeFile ./data_to_header_string/pack <$< >$@.temp
	mv $@.temp $@

./data_to_header_string/pack: | ./data_to_header_string/
	$(MAKE) -C $|

./data_to_header_string/:
	git clone ~/code/data_to_header_string/ 

done_SOURCES = src/done.c src/adjust.c src/queue.c src/select.c src/synchronize.c
done_LDADD = libsongdb.la $(GLIB_LIBS)
done_CFLAGS = $(DB_CFLAGS) $(GLIB_CFLAGS) -pthread

dscanner_SOURCES = src/dscanner.c
dscanner_LDADD = libsongdb.la $(MEDIA_LIBS)
dscanner_CFLAGS = $(DB_CFLAGS) $(MEDIA_CFLAGS)

enqueue_SOURCES = src/enqueue.c src/adjust.c src/queue.c src/synchronize.c
enqueue_LDADD = libsongdb.la $(GLIB_LIBS)
enqueue_CFLAGS = $(DB_CFLAGS) $(GLIB_CFLAGS) -pthread

enqueuePath_SOURCES = src/enqueuePath.c src/adjust.c src/queue.c src/synchronize.c
enqueuePath_LDADD = libsongdb.la $(GLIB_LIBS)
enqueuePath_CFLAGS = $(DB_CFLAGS) $(GLIB_CFLAGS) -pthread

graph_SOURCES = src/graph.c src/adjust.c

import_SOURCES = src/import.c src/derpstring.c src/hash.c
import_LDADD = libsongdb.la $(LIBGCRYPT_LIBS)
import_CFLAGS = $(DB_CFLAGS) $(LIBGCRYPT_CFLAGS)

migrate_SOURCES = src/migrate.c
migrate_LDADD = libsongdb.la
migrate_CFLAGS = $(DB_CFLAGS) 

mode_SOURCES = src/mode.c src/adjust.c src/queue.c src/synchronize.c
mode_LDADD = libsongdb.la $(GLIB_LIBS)
mode_CFLAGS = $(DB_CFLAGS) $(GLIB_CFLAGS) -pthread

next_SOURCES = src/next.c src/config.c src/get_pid.c
next_LDADD = libsongdb.la
next_CFLAGS = $(DB_CFLAGS) 

nowplaying_SOURCES = src/nowplaying.c src/nextreactor.c nowplaying.fields.ch
nowplaying_LDADD = libsongdb.la $(UV_LIBS)
nowplaying_CFLAGS = $(DB_CFLAGS) $(UV_CFLAGS)

nowplaying.fields.ch: nowplaying.fields.conf nowplaying-make
	./nowplaying-make <$< >$@.temp
	mv $@.temp $@

nowplaying_make_SOURCES = src/nowplaying-make.c

pause_SOURCES = src/pause.c src/config.c src/get_pid.c pause.glade.ch
pause_LDADD = libsongdb.la $(GUI_LIBS)
pause_CFLAGS = $(DB_CFLAGS) $(GUI_CFLAGS)

player_SOURCES = src/player.c src/adjust.c src/config.c src/get_pid.c src/queue.c src/select.c src/signals.c src/synchronize.c
player_LIBS = libsongdb

playlist_SOURCES = src/playlist.c src/nextreactor.c
playlist_LIBS = libsongdb

ratebyalbum_SOURCES = src/ratebyalbum.c
ratebyalbum_LIBS = libsongdb

ratebytitle_SOURCES = src/ratebytitle.c 
ratebytitle_LIBS = libsongdb

replay_SOURCES = src/replay.c src/adjust.c src/queue.c src/synchronize.c
replay_LIBS = libsongdb

replaygain_scanner_SOURCES = src/replaygain_scanner.c
replaygain_scanner_LIBS = libsongdb

testadjust_SOURCES = src/testadjust.c src/adjust.c

testqueue_SOURCES = src/testqueue.c src/adjust.c src/queue.c src/select.c src/synchronize.c
testqueue_LIBS = libsongdb

import_LDADD += libguess/src/libguess/libguess.so

libguess/src/libguess/libguess.so: libguess/buildsys.mk
	$(MAKE) -C $(dir $@) $(notdir $@)

libguess/buildsys.mk: libguess/configure
	cd $(dir $@) && ./configure --disable-shared

libguess/configure: libguess/configure.ac
	cd $(dir $@) && ./autogen.sh
