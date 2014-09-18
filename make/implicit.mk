o/%.o: %.c
	gcc $(CFLAGS) -c -o $@ $(filter %.c,$^)

%.so:
	gcc $(CFLAGS) $(LDFLAGS) -shared -fPIC -o $@ $(filter %.o %.so, $^)

deps/%.d: %.c
	echo -n o/ > $@.temp
	gcc -MM $<  >> $@.temp
	echo -n "$*: " >> $@.temp
	luajit make/collect-deps.lua $< >> $@.temp
	echo $@: make/implicit.mk make/collect-deps.lua >> $@.temp
	mv $@.temp $@ 

$(PROGRAMS): %: o/%.o
	gcc $(CFLAGS) $(LDFLAGS) -o $@ $(filter %.o %.so,$^)
