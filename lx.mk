lib/lxpause.so: lxpause.so.c o/get_pid.os o/pq.os o/config.os o/preparation.os
	gcc $(CFLAGS) `pkg-config --cflags lxpanel gtk+-2.0` -o $@ $^ $(LDFLAGS) `pkg-config --libs lxpanel gtk+-2.0` -lpq -lm

lib/lxpause.so: CFLAGS+=-fpic
lib/lxpause.so: LDFLAGS+=-shared

o/%.os: %.c
	$(CC) -fpic $(CFLAGS) -c -o $@ $<
