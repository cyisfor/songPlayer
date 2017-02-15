guessdir:=libguess/src/libguess
guesses:=$(patsubst %.c, %.o, $(wildcard $(guessdir)/*.c)) $(guessdir)/guess.lib.o

derp: libguess/Makefile
	$(MAKE) -C $(guessdir) $(patsubst $(guessdir)/%,%,$(guesses))
	$(MAKE) all

white := $(shell echo -ne "\x1b[1m")
yellow := $(shell echo -ne "\x1b[1;33m")
reset := $(shell echo -ne "\x1b[0m")
status = $(info $(white)$(strip $(1))$(yellow) $(strip $(2))$(reset))

ifeq ($(origin V), undefined)
MAKEFLAGS:=-s
endif


CFLAGS+=-g -fdiagnostics-color=always -Wall

PROGRAMS:=replay addalbum player import replaygain_scanner scanner dscanner	best migrate next graph mode current enqueue enqueuePath testadjust testqueue done ratebytitle ratebyalbum nowplaying nowplaying-make pause playlist

PROGLOCS:=$(foreach prog,$(PROGRAMS),bin/$(prog))

REBUILD=o/.rebuild


all:: $(REBUILD) make/config.mk build
	$(call status, DONE)

build: $(PROGLOCS) lib/lxpause.so

include make/implicit.mk

make/config.mk: | o/
	$(call status, CONFIG)
	echo -n CFLAGS+="-g -fdiagnostics-color=always " > $@.temp
	libgcrypt-config --cflags | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	xml2-config --cflags | head -c -1 >> $@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 --cflags >>$@.temp
	echo -n LDFLAGS+="-lpq -lm " >>$@.temp
	libgcrypt-config --libs | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	xml2-config --libs | head -c -1 >> $@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 --libs >>$@.temp
	TEMP="$@.temp" DEST="$@"	REBUILD="$(REBUILD)" ./make/maybe-reconfig

bin/nowplaying bin/playlist: TARGETLIBS := -luv

-include make/config.mk

deps/all.d: | deps/
	$(call status, ALLDEPS)
	rm -f $@.temp
	echo -e "$(foreach prog,$(PROGRAMS),\n\nbin/$(prog): o/$(prog).o deps/$(prog).d \ndeps/$(prog).d: | deps/)" >> $@.temp
	echo >>$@.temp
	mv $@.temp $@

DEPS:=$(foreach prog,$(PROGRAMS),deps/$(prog).d)

$(DEPS): deps/all.d

-include deps/all.d
-include $(DEPS)

clean:
	$(call status, CLEAN)
	rm -Rf o/ bin/ deps/ make/config.mk

o/:
	$(call status, MKDIR,$@)
	mkdir $@

bin/import: o/libguess.a
bin/import: LDFLAGS:=$(LDFLAGS) o/libguess.a

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

io/nowplaying.fields.ch: nowplaying.fields.conf ./bin/nowplaying-make 
	$(call status, FIELDING, nowplaying)
	./bin/nowplaying-make <nowplaying.fields.conf >$@.temp
	mv $@.temp $@
.SECONDARY: $(REBUILD)
.PHONY: clean all configure build
