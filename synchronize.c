#include "synchronize.h"

#include <pthread.h>
#include <assert.h>

pthread_mutex_t queueLock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t _checkQueue = PTHREAD_COND_INITIALIZER;
pthread_cond_t _songInQueue = PTHREAD_COND_INITIALIZER;

uint8_t queueSize = 0;

void setNumQueued(uint8_t num) {
  // don't need a lock at this point...
  queueSize = num;
}

void waitUntilSongInQueue(void) {
  pthread_mutex_lock(&queueLock);
  while(queueSize==0) {
    pthread_cond_broadcast(&_checkQueue);
    pthread_cond_wait(&_songInQueue,&queueLock);
  }
  pthread_mutex_unlock(&queueLock);
}

void waitUntilQueueNeeded(void) {
  pthread_mutex_lock(&queueLock);
  while (queueSize > 0) {
    pthread_cond_broadcast(&_songInQueue);
    pthread_cond_wait(&_checkQueue,&queueLock);
  }
  pthread_mutex_unlock(&queueLock);
}

void songOutOfQueue(void) {
  pthread_mutex_lock(&queueLock);
  if(queueSize>0)
    --queueSize;
  pthread_cond_broadcast(&_checkQueue);
  pthread_mutex_unlock(&queueLock);
}

void fillQueue(void (*addOne)(void)) {
  for(;;) {
    pthread_mutex_lock(&queueLock);
    if(queueSize >= 0x10) break;
    addOne();
    ++queueSize;
    pthread_cond_broadcast(&_songInQueue);
    pthread_mutex_unlock(&queueLock);
  }
}
