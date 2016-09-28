white := $(shell echo -ne "\x1b[1m")
yellow := $(shell echo -ne "\x1b[1;33m")
reset := $(shell echo -ne "\x1b[0m")
status = $(info $(white)$(strip $(1))$(yellow) $(strip $(2))$(reset))

ifeq ($(origin V), undefined)
MAKEFLAGS:=-s
endif


CFLAGS+=-g -fdiagnostics-color=always -Wall

PROGRAMS:=replay addalbum player import replaygain_scanner scanner dscanner	best migrate next graph mode current enqueue testadjust testqueue done ratebytitle ratebyalbum nowplaying nowplaying-make pause playlist

PROGLOCS:=$(foreach prog,$(PROGRAMS),bin/$(prog))

REBUILD=o/.rebuild

all:: $(REBUILD) make/config.mk build
	$(call status, DONE)

build: $(PROGLOCS) lib/lxpause.so

lxpause.so: lxpause.so.c o/get_pid.os o/pq.os o/config.os o/preparation.os
	gcc -shared -fPIC $(CFLAGS) -o $@ $^ $(LDFLAGS)
lxpause.so: CFLAGS = `pkg-config --cflags lxpanel gtk+-2.0`
lxpause.so: LDFLAGS = `pkg-config --libs lxpanel gtk+-2.0`

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

$(REBUILD): | o/
	echo touch $@

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

.PHONY: clean all configure build
