MAKEFLAGS+=-s
white := $(shell echo -ne "\x1b[1m")
yellow := $(shell echo -ne "\x1b[1;33m")
reset := $(shell echo -ne "\x1b[0m")
status = $(info $(white)$(strip $(1))$(yellow) $(strip $(2))$(reset))

CFLAGS:=-g

PROGRAMS:=player import replaygain_scanner scanner dscanner \
	best migrate next graph mode current enqueue\
	testadjust testqueue done ratebytitle ratebyalbum linktolatest \
	pause

PROGLOCS:=$(foreach prog,$(PROGRAMS),bin/$(prog))

all:: make/.rebuild make/config.mk build
	$(call status, DONE)

make/.rebuild:
	touch $@

build: $(PROGLOCS)

include make/implicit.mk

make/config.mk: Makefile
	$(call status, CONFIG)
	echo -n CFLAGS:="-g " > $@.temp
	libgcrypt-config --cflags | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	xml2-config --cflags | head -c -1 >> $@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 --cflags >>$@.temp
	echo -n LDFLAGS:="-lpq -lm " >>$@.temp
	libgcrypt-config --libs | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	xml2-config --libs | head -c -1 >> $@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 --libs >>$@.temp
	TEMP="$@.temp" DEST="$@" REBUILD="make/.rebuild"	./make/maybe-reconfig

bin/linktolatest: TARGETLIBS := -luv

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

deps/:
	$(call status, MKDIR, $@)
	mkdir $@

bin/ratebytitle: o/ratebytitleglade.o

bin/pause: o/pause.glade.o
o/pause.glade.o: o/pause.glade.s

o/ratebytitleglade.s: ratebytitle.glade
	$(call status, MAKEARRAY, $*)
	luajit -lluarocks.loader make/makearray.lua gladeFile $< >$@.temp	
	mv $@.temp $@

o/pause.glade.s: pause.glade.xml
	$(call status, MAKEARRAY, $*)
	luajit -lluarocks.loader make/makearray.lua gladeFile $< >$@.temp	
	mv $@.temp $@

o/ratebytitleglade.o: o/ratebytitleglade.s

.PHONY: clean all configure build
