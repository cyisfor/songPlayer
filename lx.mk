CFLAGS=-fpic `pkg-config --cflags lxpanel gtk+-2.0`
LDFLAGS=`pkg-config --libs lxpanel gtk+-2.0` -lpq -lm
lib/lxpause.so: lxpause.so.c o/get_pid.os o/pq.os o/config.os o/preparation.os
	gcc -shared $(CFLAGS) -o $@ $^ $(LDFLAGS) 

o/%.os: %.c
	$(CC) $(CFLAGS) -c -o $@ $<
