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
#include <fcntl.h> // open, fcntl F_SETLK
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
	int lock = open(application_name,O_WRONLY,0600);
	if(lock < 0) return -1;
	struct flock info = {
		.l_type = F_WRLCK,
		.l_whence = SEEK_SET
	};

	if(0 != fcntl(lock, F_GETLK, &info)) {
		perror("Bad lock");
		abort();
	}
	close(lock);
	return info.l_pid;
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
	int lock = open(application_name,O_WRONLY|O_CREAT,0600);
	assert(lock >= 0);
	struct flock info = {
		.l_type = F_WRLCK,
		.l_whence = SEEK_SET
	};

	if(0 != fcntl(lock, F_GETLK, &info)) {
		perror("Bad lock");
		exit(23);
	}
	// aren't race conditions wonderful?
	info.l_type = F_WRLCK;
	if(0 != fcntl(lock, F_SETLK, &info)) {
		if(errno == EACCES || errno == EAGAIN) {
			close(lock);
			printf("PID is %d\n",info.l_pid);
			return false;
		}
		perror("Bad lock");
		abort();
	}
	
	atexit(get_pid_done);
	char buf[0x100];
	ssize_t amt = snprintf(buf,0x100,"%d",getpid());
	write(lock,buf,amt);
	fsync(lock);
	return true;
}
