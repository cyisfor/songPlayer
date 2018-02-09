o/%.o: src/%.c
	$(call status,COMPILE, $*)
	python make/smart-link.py compile $@ $(CC) $(CFLAGS) -c -o $@ $(filter %.c,$^)

DEPS:=make/deps.mk
export DEPS
include $(DEPS)

$(DEPS):
	python make/smart-link.py deps

bin/%: o/%.o
	$(call status, PROGRAM, $*)
	python make/smart-link.py link $@ $(CC) $(CFLAGS) $(LDFLAGS) -o $@ @@DERP@@ $< $(LDLIBS) $(TARGETLIBS)

o/%.os: src/%.c
	$(call status,COMPILE_SHARED, $*)
	$(CC) -fpic $(CFLAGS) -c -o $@ $(filter %.c,$^)

o/%.glade.ch: %.glade.xml
	$(call status, EMBED_GLADE, $*)
	name=gladeFile ./data_to_header_string/pack <$< >$@.temp
	mv $@.temp $@

lib/%.so: | lib
	$(call status,LIBRARY, $*)
	$(CC) $(CFLAGS) -shared -fPIC $(LDFLAGS) -o $@ $(filter %.o %.so, $^) 
deps/%.d: src/%.c
	$(call status, DEPS, $*)
	echo -n o/ > $@.temp
	$(CC) -MG -MM $<  >> $@.temp
	echo -n "bin/$*: " >> $@.temp
	lua make/collect-deps.lua $< >> $@.temp
	echo $@: make/implicit.mk make/collect-deps.lua >> $@.temp
	mv $@.temp $@

$(BINPROGS): | bin

lib bin:
	mkdir $@

$(PROGLOCS): bin/%: o/%.o
	$(call status, PROGRAM, $*)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(filter %.o %.so,$^) $(TARGETLIBS)
