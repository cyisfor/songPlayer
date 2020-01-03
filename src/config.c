#include "config.h"

#include <stdio.h>
#include <assert.h>
#include <string.h>
#include <malloc.h>
#include <stdlib.h>
#include <sys/stat.h> // mkdir

char* configLocation = NULL;
ssize_t configBase = 0;
ssize_t configSpace = 0;

static void assureSize(ssize_t size) {
  assert(size<0x800);
  if(configSpace < size) {
    configLocation = realloc(configLocation,size+1);
    configSpace = size;
  }
}

void config_init(void) {
  const char* location = getenv("location");
  if(location==NULL) {
    const char* home = getenv("HOME");
    if(home==NULL) {
      fputs("No home or other location found?\n",stderr);
      exit(23);
    }
    ssize_t hlen = strlen(home);
    assureSize(hlen+1+sizeof(".config/player/")+0x20);
    memcpy(configLocation,home,hlen);
    if(home[hlen-1] != '/') {
      configLocation[hlen] = '/';
      ++hlen;
    }
    memcpy(configLocation+hlen,".config/",sizeof(".config/"));
    configLocation[hlen+sizeof(".config/")] = '\0';
    mkdir(configLocation,0700);
    memcpy(configLocation+hlen+sizeof(".config/")-1,"player/",sizeof("player/"));
    configLocation[hlen+sizeof(".config/player/")] = '\0';
    mkdir(configLocation,0700);
    configBase = hlen+sizeof(".config/player/");
  } else {
    ssize_t len = strlen(location);
    assureSize(len+0x20);
    memcpy(configLocation,location,len+1);
    configBase = len;
  }
}

const char* config_at(const char* name) {
  assert(configBase > 0);
  ssize_t len = strlen(name);
  assureSize(configBase+2+len);
  memcpy(configLocation+configBase-1,name,len);
  configLocation[configBase+len-1] = '\0';

  return configLocation;
}
