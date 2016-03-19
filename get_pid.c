#include "config.h"
#include "get_pid.h"
#include "preparation.h"
#include "pq.h"
#include <arpa/inet.h> // ntohl
#include <assert.h>
#include <string.h> // strlen
#include <stdint.h>
#include <stdlib.h> // atexit

const char* get_pidfile(void) {
  return configAt("player.pid");
}

int get_pid(const char* application_name, ssize_t len) {
  int inp = open(get_pidfile(),O_RDONLY);
  if(inp < 0) return inp;
  int ret = 0;
  if(1!=fscanf(inp,"%d",&ret))
	return -2;
  return ret;
}

static void get_pid_done(void) {
  unlink(get_pidfile());
}

bool declare_pid(void) {
  int out = open(get_pidfile(),O_WRONLY|O_CREAT);
  if(0 != lockf(out, F_TLOCK, 0)) {
	if(errno == EACCES || errno == EAGAIN) {
	  close(out);
	  return false;
	}
	  
	perror("Bad lock");
	exit(23);
  }

  atexit(get_pid_done);
  return true;
}
