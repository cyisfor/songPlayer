ACLOCAL_AMFLAGS = -Im4

lib_LTLIBRARIES = libsongdb.la

# since automake SUCKS you have to do this manually
# all programs using queue.c must manually add GLIB_CFLAGS/LIBS
# all programs using queue.c also add adjust.c but not vice versa
# all programs using libsongdb must manually add DB_CFLAGS

libsongdb_la_SOURCES = src/pq.c src/preparation.c
libsongdb_la_CFLAGS = $(DB_CFLAGS)
libsongdb_la_LIBADD = $(DB_LIBS)

%.ch: %.xml ./data_to_header_string/pack
	name=gladeFile ./data_to_header_string/pack <$< >$@.temp
	mv $@.temp $@

./data_to_header_string/pack: | ./data_to_header_string/
	$(MAKE) -C $|

./data_to_header_string/:
	git clone ~/code/data_to_header_string/ 

nowplaying.fields.ch: nowplaying.fields.conf nowplaying-make
	./nowplaying-make <$< >$@.temp
	mv $@.temp $@

libguess	/src/libguess/libguess.so: libguess/buildsys.mk
	$(MAKE) -C $(dir $@) $(notdir $@)

libguess/buildsys.mk: libguess/configure
	cd $(dir $@) && ./configure --disable-shared

libguess/configure: libguess/configure.ac
	cd $(dir $@) && ./autogen.sh

bin_PROGRAMS =  \
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
	move_location \
  next \
  nowplaying \
  pause \
  player \
  playlist \
  ratebyalbum \
  ratebytitle \
  replay \
  replaygain_scanner

noinst_PROGRAMS =\
  nowplaying-make\
  testadjust\
  testqueue

BUILT_SOURCES = \
  current.glade.ch \
  nowplaying.fields.ch \
  pause.glade.ch \
  ratebytitle.glade.ch

addalbum_SOURCES = src/addalbum.c
addalbum_CFLAGS = $(DB_CFLAGS)
addalbum_LDADD = libsongdb.la

best_SOURCES = src/best.c
best_CFLAGS = $(DB_CFLAGS) $(MEDIA_CFLAGS)
best_LDADD = libsongdb.la $(MEDIA_LIBS)

current_SOURCES = src/current.c current.glade.ch
current_CFLAGS = $(DB_CFLAGS) $(GUI_CFLAGS) $(GUI_CFLAGS)
current_LDADD = libsongdb.la $(GUI_LIBS) $(GUI_LIBS)

done_SOURCES = src/done.c src/queue.c src/adjust.c src/synchronize.c src/select.c
done_CFLAGS = $(DB_CFLAGS) $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread
done_LDADD = libsongdb.la $(GLIB_LIBS) libsongdb.la

dscanner_SOURCES = src/dscanner.c
dscanner_CFLAGS = $(DB_CFLAGS) $(MEDIA_CFLAGS)
dscanner_LDADD = libsongdb.la $(MEDIA_LIBS)

enqueue_SOURCES = src/enqueue.c src/queue.c src/adjust.c src/synchronize.c
enqueue_CFLAGS = $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread
enqueue_LDADD = $(GLIB_LIBS) libsongdb.la

enqueuePath_SOURCES = src/enqueuePath.c src/queue.c src/adjust.c src/synchronize.c
enqueuePath_CFLAGS = $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread
enqueuePath_LDADD = $(GLIB_LIBS) libsongdb.la

graph_SOURCES = src/graph.c src/adjust.c

import_SOURCES = src/import.c src/derpstring.c src/hash.c
import_CFLAGS = $(DB_CFLAGS) $(LIBGCRYPT_CFLAGS) -Ilibguess/src/
import_LDADD = libsongdb.la $(LIBGCRYPT_LIBS) libguess/src/libguess/libguess.so
import_LDFLAGS = -rpath $(abspath $(srcdir))/libguess/src/libguess

migrate_SOURCES = src/migrate.c
migrate_CFLAGS = $(DB_CFLAGS)
migrate_LDADD = libsongdb.la

mode_SOURCES = src/mode.c src/queue.c src/adjust.c src/synchronize.c
mode_CFLAGS = $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread
mode_LDADD = $(GLIB_LIBS) libsongdb.la

move_location_SOURCES = src/move_location.c
move_location_CFLAGS =$(DB_CFLAGS)
move_location_LDADD = libsongdb.la

next_SOURCES = src/next.c src/config.c src/get_pid.c
next_CFLAGS = $(DB_CFLAGS)
next_LDADD = libsongdb.la

nowplaying_SOURCES = src/nowplaying.c src/nextreactor.c nowplaying.fields.ch
nowplaying_CFLAGS = $(DB_CFLAGS)
nowplaying_LDADD = libsongdb.la

nowplaying_make_SOURCES = src/nowplaying-make.c

pause_SOURCES = src/pause.c pause.glade.ch src/get_pid.c src/config.c
pause_CFLAGS = $(DB_CFLAGS) $(GUI_CFLAGS)
pause_LDADD = libsongdb.la $(GUI_LIBS)

player_SOURCES = src/player.c src/config.c src/get_pid.c src/queue.c src/adjust.c src/synchronize.c src/select.c src/signals.c
player_CFLAGS = $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread $(MEDIA_CFLAGS)
player_LDADD = $(GLIB_LIBS) libsongdb.la $(MEDIA_LIBS)

playlist_SOURCES = src/playlist.c src/nextreactor.c
playlist_CFLAGS = $(DB_CFLAGS) $(GLIB_CFLAGS)
playlist_LDADD = libsongdb.la $(GLIB_LIBS)

ratebyalbum_SOURCES = src/ratebyalbum.c
ratebyalbum_CFLAGS = $(DB_CFLAGS)
ratebyalbum_LDADD = libsongdb.la

ratebytitle_SOURCES = src/ratebytitle.c ratebytitle.glade.ch
ratebytitle_CFLAGS = $(DB_CFLAGS) $(GUI_CFLAGS)
ratebytitle_LDADD = libsongdb.la $(GUI_LIBS)

replay_SOURCES = src/replay.c src/queue.c src/adjust.c src/synchronize.c
replay_CFLAGS = $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread
replay_LDADD = $(GLIB_LIBS) libsongdb.la

replaygain_scanner_SOURCES = src/replaygain_scanner.c
replaygain_scanner_CFLAGS = $(DB_CFLAGS) $(MEDIA_CFLAGS)
replaygain_scanner_LDADD = libsongdb.la $(MEDIA_LIBS)

testadjust_SOURCES = src/testadjust.c src/adjust.c

testqueue_SOURCES = src/testqueue.c src/queue.c src/adjust.c src/synchronize.c src/select.c
testqueue_CFLAGS = $(GLIB_CFLAGS) $(DB_CFLAGS) -pthread
testqueue_LDADD = $(GLIB_LIBS) libsongdb.la

