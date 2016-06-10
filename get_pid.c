#include "config.h"
#include "get_pid.h"
#include "preparation.h"
#include "pq.h"
#include <arpa/inet.h> // ntohl
#include <assert.h>
#include <string.h> // strlen
#include <stdint.h>
#include <stdlib.h> // atexit
#include <sys/stat.h> // mkdir
#include <fcntl.h> // open
#include <errno.h> // errno

#include <stdio.h> // snscanf

const char* g_application_name = "song-player";

const char* get_pidloc(void) {
  return configAt("pids");
}

int get_pid(const char* application_name, ssize_t len) {
  const char* loc = get_pidloc();
  mkdir(loc,0700);
  assert(0==chdir(loc));
  int inp = open(application_name,O_RDONLY);
  if(inp < 0) return inp;
  int ret = 0;
  char buf[0x100];
  int amt = read(inp,buf,0x100);
  buf[amt] = '\0';
  assert(amt>0);
  return atoi(buf);
}

static void get_pid_done(void) {
  if(0==chdir(get_pidloc()))
	unlink(g_application_name);
}

bool declare_pid(const char* application_name) {
  g_application_name = application_name;
  const char* loc = get_pidloc();
  mkdir(loc,0700);
  chdir(loc);
  int out = open(application_name,O_WRONLY|O_CREAT,0600);
  if(0 != lockf(out, F_TLOCK, 0)) {
	if(errno == EACCES || errno == EAGAIN) {
	  close(out);
	  return false;
	}
	  
	perror("Bad lock");
	exit(23);
  }  
  atexit(get_pid_done);
  char buf[0x100];
  ssize_t amt = snprintf(buf,0x100,"%d",getpid());
  write(out,buf,amt);
  fsync(out);
  return true;
}