CFLAGS:=-g

PROGRAMS:=player import replaygain_scanner scanner dscanner \
	best migrate next graph mode current enqueue\
	testadjust testqueue done ratebytitle

all:: make/config.mk build

build: $(PROGRAMS)

include make/implicit.mk

make/config.mk:
	echo -n CFLAGS:="-g " > $@.temp
	libgcrypt-config --cflags | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 --cflags >>$@.temp
	echo -n LDFLAGS:="-lpq -lm " >>$@.temp
	libgcrypt-config --libs | head -c -1 >>$@.temp
	echo -n " "  >> $@.temp
	pkg-config gtk+-3.0 gstreamer-1.0 --libs >>$@.temp
	mv $@.temp $@

-include make/config.mk

deps/all.d: | deps/
	rm -f $@.temp
	echo -e "$(foreach prog,$(PROGRAMS),\n\n$(prog): o/$(prog).o deps/$(prog).d \ndeps/$(prog).d: | deps/)" >> $@.temp
	echo >>$@.temp
	mv $@.temp $@


-include deps/all.d
-include $(foreach prog,$(PROGRAMS),deps/$(prog).d)

clean:
	rm -Rf o/ $(PROGRAMS) deps/ make/config.mk

o/:
	mkdir $@

deps/:
	mkdir $@

ratebytitle: o/ratebytitleglade.o

o/ratebytitleglade.s: ratebytitle.glade
	luajit -lluarocks.loader makearray.lua gladeFile $< >$@.temp	
	mv $@.temp $@

o/ratebytitleglade.o: o/ratebytitleglade.s

.PHONY: clean all configure build
