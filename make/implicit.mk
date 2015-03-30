o/%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $(filter %.c,$^)

%.so:
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o %.so, $^)

deps/%.d: %.c
	echo -n o/ > $@.temp
	$(CC) -MM $<  >> $@.temp
	echo -n "$*: " >> $@.temp
	luajit make/collect-deps.lua $< >> $@.temp
	echo $@: make/implicit.mk make/collect-deps.lua >> $@.temp
	mv $@.temp $@ 

$(PROGRAMS): %: o/%.o
	$(CC) $(CFLAGS) $(LDFLAGS) $(TARGETLIBS) -o $@ $(filter %.o %.so,$^)
