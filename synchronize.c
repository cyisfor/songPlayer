#include "synchronize.h"

#include <pthread.h>
#include <assert.h>

pthread_mutex_t queueLock = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t _checkQueue = PTHREAD_COND_INITIALIZER;
pthread_cond_t _songInQueue = PTHREAD_COND_INITIALIZER;

unsigned int queueSize = 0;

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

void songInQueue(void) {
  pthread_mutex_lock(&queueLock);
  ++queueSize;
  pthread_cond_broadcast(&_songInQueue);
  pthread_mutex_unlock(&queueLock);
}

void songOutOfQueue(void) {
  pthread_mutex_lock(&queueLock);
  assert(queueSize>0);
  --queueSize;
  pthread_mutex_unlock(&queueLock);
}
