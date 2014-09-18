CFLAGS:=-g

PROGRAMS:=player import replaygain_scanner scanner dscanner \
	best migrate next graph mode current enqueue\
	testadjust testqueue done 

all:: make/config.mk build

build: $(PROGRAMS)

include make/implicit.mk

make/config.mk:
	echo -n CFLAGS:="-g " > $@ ;\
	libgcrypt-config --cflags | head -c -1 >>$@ ;\
	echo -n " "  >> $@ ;\
	pkg-config gstreamer-1.0 --cflags >>$@ ;\
	echo -n LDFLAGS:="-lpq -lm " >>$@ ;\
	libgcrypt-config --libs | head -c -1 >>$@ ;\
	echo -n " "  >> $@ ;\
	pkg-config gstreamer-1.0 --libs >>$@

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

.PHONY: clean all configure build
