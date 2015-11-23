o/%.o: %.c
	$(call status,COMPILE, $*)
	$(CC) $(CFLAGS) -c -o $@ $(filter %.c,$^)

%.so:
	$(call status,LIBRARY, $*)
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o %.so, $^)

deps/%.d: %.c
	$(call status, DEPS, $*)
	echo -n o/ > $@.temp
	$(CC) -MM $<  >> $@.temp
	echo -n "bin/$*: " >> $@.temp
	luajit make/collect-deps.lua $< >> $@.temp
	echo $@: make/implicit.mk make/collect-deps.lua >> $@.temp
	mv $@.temp $@ 

$(PROGLOCS): | bin

bin:
	mkdir $@

$(PROGLOCS): bin/%: o/%.o
	$(call status, PROGRAM, $*)
	$(CC) $(CFLAGS) $(LDFLAGS) $(TARGETLIBS) -o $@ $(filter %.o %.so,$^)
