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
testqueue \

addalbum_SOURCES = src/pq.c src/preparation.c
best_SOURCES = src/pq.c src/preparation.c
current_SOURCES = src/pq.c src/preparation.c
done_SOURCES = src/adjust.c src/pq.c src/preparation.c src/queue.c src/select.c src/synchronize.c
dscanner_SOURCES = src/pq.c src/preparation.c
enqueue_SOURCES = src/adjust.c src/pq.c src/preparation.c src/queue.c src/synchronize.c
enqueuePath_SOURCES = src/adjust.c src/pq.c src/preparation.c src/queue.c src/synchronize.c
graph_SOURCES = src/adjust.c
import_SOURCES = src/derpstring.c src/hash.c src/pq.c src/preparation.c
migrate_SOURCES = src/pq.c
mode_SOURCES = src/adjust.c src/pq.c src/preparation.c src/queue.c src/synchronize.c
next_SOURCES = src/config.c src/get_pid.c src/pq.c
nowplaying_SOURCES = src/nextreactor.c src/pq.c src/preparation.c
pause_SOURCES = src/config.c src/get_pid.c
player_SOURCES = src/adjust.c src/config.c src/get_pid.c src/pq.c src/preparation.c src/queue.c src/select.c src/signals.c src/synchronize.c
playlist_SOURCES = src/nextreactor.c src/pq.c src/preparation.c
ratebyalbum_SOURCES = src/pq.c
ratebytitle_SOURCES = src/pq.c src/preparation.c
replay_SOURCES = src/adjust.c src/pq.c src/preparation.c src/queue.c src/synchronize.c
replaygain_scanner_SOURCES = src/pq.c src/preparation.c
testadjust_SOURCES = src/adjust.c
testqueue_SOURCES = src/adjust.c src/pq.c src/preparation.c src/queue.c src/select.c src/synchronize.c

guessdir:=libguess/src/libguess
guesses:=$(patsubst %.c, %.o, $(wildcard $(guessdir)/*.c)) $(guessdir)/guess.lib.o

derp: libguess/Makefile data_to_header_string/pack
	$(MAKE) -C $(guessdir) $(patsubst $(guessdir)/%,%,$(guesses))
	$(MAKE) all

data_to_header_string/pack: | data_to_header_string/
	$(MAKE) -C $?

data_to_header_string/:
	git clone ~/code/data_to_header_string

white := $(shell echo -ne "\x1b[1m")
yellow := $(shell echo -ne "\x1b[1;33m")
reset := $(shell echo -ne "\x1b[0m")
status = $(info $(white)$(strip $(1))$(yellow) $(strip $(2))$(reset))

ifeq ($(origin V), undefined)
MAKEFLAGS:=-s
endif


CFLAGS+=-g -fdiagnostics-color=always -Wall -I.

PROGRAMS:=replay addalbum player import replaygain_scanner scanner dscanner	best migrate next graph mode current enqueue enqueuePath testadjust testqueue done ratebytitle ratebyalbum nowplaying nowplaying-make pause playlist

SOURCES:=$(wildcard src/*.c)
OBJECTS:=$(patsubst src/%.c,o/%.o,$(SOURCES))

BINPROG:=$(patsubst %,bin/%,$(PROGRAMS))

$(BINPROG): $(OBJECTS) | bin/

bin/:
	mkdir $@

export OBJECTS


REBUILD=o/.rebuild

all:: $(REBUILD) make/config.mk build
	$(call status, DONE)

build: $(BINPROG) lib/lxpause.so

include make/implicit.mk

make/config.mk: | o/
	$(call status, CONFIG)
	echo -n CFLAGS+="-g -fdiagnostics-color=always " > $@.temp
	libgcrypt-config --cflags | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	xml2-config --cflags | head -c -1 >> $@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 libpq --cflags >>$@.temp
	echo LDFLAGS+="-Wl,-rpath -Wl,$(shell pkg-config --libs libpq | sed -e 's/.*-L//' -e 's/ .*//') " >>$@.temp
	echo -n LDLIBS+="-lm " >>$@.temp
	libgcrypt-config --libs | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	xml2-config --libs | head -c -1 >> $@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 libpq --libs >>$@.temp
	TEMP="$@.temp" DEST="$@"	REBUILD="$(REBUILD)" ./make/maybe-reconfig

bin/nowplaying bin/playlist: TARGETLIBS := -luv

-include make/config.mk

clean:
	$(call status, CLEAN)
	rm -Rf o/ bin/ deps/ make/config.mk

o/:
	$(call status, MKDIR,$@)
	mkdir $@

o/current.o: o/current.glade.ch

bin/import: o/libguess.a
bin/import: LDLIBS:=$(LDLIBS) o/libguess.a

o/libguess.a: $(guesses)
	ar crs $@ $(guesses)

libguess/Makefile: libguess/configure
	cd libguess && ./configure
	touch $@

libguess/configure: libguess/configure.ac | libguess
	cd libguess && sh autogen.sh

libguess:
	git submodule update --init

$(REBUILD): | o/
	touch $@

deps/:
	$(call status, MKDIR, $@)
	mkdir $@

o/ratebytitle.o: o/ratebytitle.glade.ch
o/pause.o: o/pause.glade.ch
o/current.o: o/current.glade.ch

o/nowplaying.o: o/nowplaying.fields.ch

o/nowplaying.fields.ch: nowplaying.fields.conf ./bin/nowplaying-make 
	$(call status, FIELDING, nowplaying)
	./bin/nowplaying-make <nowplaying.fields.conf >$@.temp
	mv $@.temp $@
.SECONDARY: $(REBUILD)
.PHONY: clean all configure build
